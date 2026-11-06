import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'state.dart';

/// A report waiting to be sent. Saved on the phone so nothing is lost when sending fails.
class Draft {
  Draft({required this.id, required this.category, required this.description, this.question, this.answer, required this.context, this.screenshot});
  final String id;
  final String category;
  final String description;
  final String? question;
  final String? answer;
  final Map<String, Object?> context;
  final String? screenshot;

  Map<String, Object?> toJson() => {
        'id': id, 'category': category, 'description': description, 'question': question,
        'answer': answer, 'context': context, 'screenshot': screenshot,
      };
  static Draft fromJson(Map<String, dynamic> j) => Draft(
        id: j['id'] as String, category: j['category'] as String, description: j['description'] as String,
        question: j['question'] as String?, answer: j['answer'] as String?,
        context: Map<String, Object?>.from(j['context'] as Map? ?? {}), screenshot: j['screenshot'] as String?,
      );
}

class Report {
  Report(this.id, this.title, this.status, this.lastReplyAt);
  final String id, title, status;
  final String? lastReplyAt;
}

class Message {
  Message(this.id, this.author, this.body);
  final String id, author, body;
}

class ReportThread {
  ReportThread({required this.id, required this.title, required this.description, this.question, this.answer, required this.status, required this.messages});
  final String id, title, description, status;
  final String? question, answer;
  final List<Message> messages;
}

class BopmigoFailure implements Exception {
  BopmigoFailure(this.message);
  final String message;
}

/// Talks to Bopmigo with its own connection, separate from the app's network code and sign-in,
/// so reporting still works while the app itself is failing.
class Client {
  Client._();
  static final shared = Client._();
  static const version = '0.1.0';

  final _http = http.Client();
  String? _token;
  bool _sending = false;

  static String newId() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int i, int j) => b.sublist(i, j).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
  }

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> loadConfig() async {
    try {
      final data = await _request('GET', 'config', auth: false);
      if (data is Map && data['hideAllText'] == true) BopmigoState.hideAllText = true;
    } catch (_) {}
  }

  /// A short follow-up question, or null when nothing important is missing.
  Future<String?> question(String description, String category, Map<String, Object?> context, String requestId) async {
    try {
      final data = await _request('POST', 'question', body: {'description': description, 'category': category, 'context': context, 'requestId': requestId});
      final q = data is Map ? (data['question'] as String? ?? '').trim() : '';
      return q.isEmpty ? null : q;
    } catch (_) {
      return null;
    }
  }

  /// Sends a report. If it can't be sent now, it's saved and sent later. Returns false when saved for later.
  Future<bool> send(Draft draft) async {
    try {
      await _post(draft);
      return true;
    } catch (_) {
      await _save(draft);
      return false;
    }
  }

  /// Sends reports saved from earlier attempts.
  Future<void> sendQueued() async {
    if (_sending) return;
    _sending = true;
    try {
      for (final d in await _queue()) {
        try {
          await _post(d);
          await _remove(d.id);
        } catch (_) {
          return;
        }
      }
    } finally {
      _sending = false;
    }
  }

  Future<List<Report>> myReports() async {
    try {
      final rows = await _request('GET', null);
      if (rows is! List) return [];
      return [
        for (final r in rows)
          if (r is Map && r['id'] is String) Report(r['id'] as String, r['title'] as String? ?? '', r['status'] as String? ?? 'open', r['last_reply_at'] as String?),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<ReportThread?> thread(String id) async {
    try {
      final r = await _request('GET', id);
      if (r is! Map) return null;
      final messages = [
        for (final m in (r['messages'] as List? ?? []))
          if (m is Map && m['id'] is String && m['body'] is String) Message(m['id'] as String, m['author'] as String? ?? 'team', m['body'] as String),
      ];
      return ReportThread(
        id: id, title: r['title'] as String? ?? '', description: r['description'] as String? ?? '',
        question: r['question'] as String?, answer: r['answer'] as String?, status: r['status'] as String? ?? 'open', messages: messages,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> reply(String id, String text) async {
    try {
      await _request('POST', id, body: {'message': text, 'requestId': newId()});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reports with a team reply the person hasn't seen yet.
  Future<List<Report>> unread() async {
    final prefs = await _prefs;
    if ((_token ?? prefs.getString('bopmigo.token')) == null) return [];
    final list = await myReports();
    return [for (final r in list) if (r.lastReplyAt != null && prefs.getString('bopmigo.seen.${r.id}') != r.lastReplyAt) r];
  }

  Future<void> markSeen(Report r) async {
    if (r.lastReplyAt != null) await (await _prefs).setString('bopmigo.seen.${r.id}', r.lastReplyAt!);
  }

  Future<void> markSeenId(String id) async {
    for (final r in await myReports()) {
      if (r.id == id) await markSeen(r);
    }
  }

  Future<void> _post(Draft d) async {
    final body = <String, Object?>{'requestId': d.id, 'category': d.category, 'description': d.description, 'context': d.context};
    if (d.question != null) body['question'] = d.question;
    if (d.answer != null) body['answer'] = d.answer;
    if (d.screenshot != null) body['screenshot'] = 'data:image/png;base64,${d.screenshot}';
    await _request('POST', null, body: body);
  }

  Future<Object?> _request(String method, String? action, {Map<String, Object?>? body, bool auth = true, bool retried = false}) async {
    final site = BopmigoState.appId;
    if (site == null) throw BopmigoFailure("Bopmigo isn't set up yet.");
    if (auth) {
      _token ??= (await _prefs).getString('bopmigo.token');
      if (_token == null) await _newToken(site);
    }
    final url = BopmigoState.host.resolve('/api/v1/reporter/$site${action == null ? '' : '/$action'}');
    final headers = {'Content-Type': 'application/json', if (auth && _token != null) 'Authorization': 'Bearer $_token'};
    final res = await (method == 'GET'
            ? _http.get(url, headers: headers)
            : _http.post(url, headers: headers, body: jsonEncode(body ?? {})))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 401 && auth && !retried) {
      _token = null;
      await (await _prefs).remove('bopmigo.token');
      return _request(method, action, body: body, auth: auth, retried: true);
    }
    final data = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw BopmigoFailure(data is Map && data['error'] is String ? data['error'] as String : "Couldn't send. Try again in a moment.");
    }
    return data;
  }

  Future<void> _newToken(String site) async {
    final res = await _http.post(BopmigoState.host.resolve('/api/v1/reporter/$site/session')).timeout(const Duration(seconds: 20));
    final data = jsonDecode(res.body);
    if (data is! Map || data['token'] is! String) throw BopmigoFailure("Couldn't reach Bopmigo.");
    _token = data['token'] as String;
    await (await _prefs).setString('bopmigo.token', _token!);
  }

  Future<List<Draft>> _queue() async {
    final raw = (await _prefs).getString('bopmigo.queue');
    if (raw == null) return [];
    try {
      return [for (final j in jsonDecode(raw) as List) Draft.fromJson(Map<String, dynamic>.from(j as Map))];
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<Draft> q) async {
    final keep = q.length > 20 ? q.sublist(q.length - 20) : q;
    await (await _prefs).setString('bopmigo.queue', jsonEncode([for (final d in keep) d.toJson()]));
  }

  Future<void> _save(Draft d) async => _write([...(await _queue()).where((x) => x.id != d.id), d]);
  Future<void> _remove(String id) async => _write((await _queue()).where((x) => x.id != id).toList());
}
