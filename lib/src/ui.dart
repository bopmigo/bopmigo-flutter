import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'capture.dart';
import 'client.dart';

const accent = Color(0xFFFF5A1F);
const _ink = Color(0xFF16130F);
const _teamLabel = Color(0xFFC2400D);
const _soft = Color(0xFFFFF5EE);

/// Wraps the app: marks what a screenshot covers and hosts the feedback sheet above everything.
/// Added for you by `Bopmigo.builder`.
class BopmigoHost extends StatefulWidget {
  const BopmigoHost({super.key, required this.child});
  final Widget child;
  @override
  State<BopmigoHost> createState() => BopmigoHostState();
}

enum _Layer { none, sheet, prompt }

class BopmigoHostState extends State<BopmigoHost> with WidgetsBindingObserver {
  static BopmigoHostState? current;
  _Layer _layer = _Layer.none;
  Widget? _page;
  _Prompt? _prompt;

  bool get busy => _layer != _Layer.none;

  @override
  void initState() {
    super.initState();
    current = this;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => offerReplies());
  }

  @override
  void dispose() {
    if (current == this) current = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back in the app: send anything saved while offline, and say if the team replied.
    if (state == AppLifecycleState.resumed) {
      Client.shared.sendQueued();
      offerReplies();
    }
  }

  Future<void> open({bool history = false, String? thread}) async {
    if (busy) return;
    // Taken before the sheet covers the screen.
    final shot = history || thread != null ? null : await Capture.screenshot();
    if (!mounted) return;
    setState(() {
      _layer = _Layer.sheet;
      _page = thread != null
          ? ThreadPage(id: thread, onDone: close)
          : history
              ? HistoryPage(onDone: close)
              : FeedbackPage(screenshot: shot, onClose: close);
    });
  }

  void close() => setState(() {
        _layer = _Layer.none;
        _page = null;
        _prompt = null;
      });

  void offerAfterScreenshot() {
    if (busy) return;
    setState(() {
      _layer = _Layer.prompt;
      _prompt = _Prompt('Report a problem?', 'Tell the team what went wrong.', 'Not now', 'Report', () {
        close();
        open();
      });
    });
  }

  Future<void> offerReplies() async {
    if (busy) return;
    final unread = await Client.shared.unread();
    if (unread.isEmpty || busy || !mounted) return;
    final first = unread.first;
    setState(() {
      _layer = _Layer.prompt;
      _prompt = _Prompt(
        'The team replied',
        unread.length == 1 ? 'About “${first.title}”.' : 'You have ${unread.length} new replies to your feedback.',
        'Later',
        'View',
        () {
          close();
          unread.length == 1 ? open(thread: first.id) : open(history: true);
        },
        onLater: () async {
          for (final r in unread) {
            await Client.shared.markSeen(r);
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        RepaintBoundary(key: Capture.boundaryKey, child: widget.child),
        if (_layer != _Layer.none)
          Positioned.fill(
            child: Theme(
              data: ThemeData(colorSchemeSeed: accent, brightness: brightness, useMaterial3: true),
              child: _layer == _Layer.sheet ? _Sheet(page: _page!, onDismiss: close) : _PromptView(prompt: _prompt!, onCancel: () { _prompt?.onLater?.call(); close(); }),
            ),
          ),
      ],
    );
  }
}

class _Prompt {
  _Prompt(this.title, this.message, this.cancel, this.action, this.onAction, {this.onLater});
  final String title, message, cancel, action;
  final VoidCallback onAction;
  final VoidCallback? onLater;
}

class _PromptView extends StatelessWidget {
  const _PromptView({required this.prompt, required this.onCancel});
  final _Prompt prompt;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(22)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(prompt.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(prompt.message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: onCancel, child: Text(prompt.cancel)),
              TextButton(onPressed: prompt.onAction, child: Text(prompt.action, style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// A sheet that slides up over the app, with its own navigation for the replies screens.
class _Sheet extends StatefulWidget {
  const _Sheet({required this.page, required this.onDismiss});
  final Widget page;
  final VoidCallback onDismiss;
  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 280))..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final curve = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    return Stack(children: [
      FadeTransition(opacity: curve, child: const ModalBarrier(color: Colors.black38, dismissible: false)),
      SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curve),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(top: mq.padding.top + 12),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: SizedBox(
                width: min(mq.size.width, 640),
                child: Navigator(onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => widget.page)),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

const _thanks = [
  'Thanks! The team will take a look.',
  'Thanks, sending this to the team.',
  'Got it, thanks! It’s with the team now.',
  'Thanks for letting us know. The team will take a look.',
];

enum _Step { write, asking, followUp, done }

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key, this.screenshot, required this.onClose});
  final String? screenshot;
  final VoidCallback onClose;
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  var _step = _Step.write;
  var _category = 'problem';
  final _text = TextEditingController();
  final _answer = TextEditingController();
  String? _question;
  bool _queued = false;
  final _requestId = Client.newId();
  final _thank = _thanks[Random().nextInt(_thanks.length)];

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  (String, String) get _kind => switch (_category) {
        'change' => ('What should change?', 'It would be easier if…'),
        'idea' => ('What’s your idea?', 'It would be great if…'),
        _ => ('What happened?', 'I tried to… but…'),
      };

  /// After writing: Bopmigo asks a short follow-up that fits what was written, or none, then sends.
  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    setState(() => _step = _Step.asking);
    // Never make someone wait long: no question after 6 seconds means send without one.
    final q = await Client.shared
        .question(_text.text.trim(), _category, Capture.context(), _requestId)
        .timeout(const Duration(seconds: 6), onTimeout: () => null);
    if (!mounted) return;
    if (q != null) {
      setState(() {
        _question = q;
        _step = _Step.followUp;
      });
    } else {
      _send();
    }
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() => _step = _Step.asking);
    final answer = _answer.text.trim();
    final draft = Draft(
      id: _requestId, category: _category, description: _text.text.trim(), question: _question,
      answer: answer.isEmpty ? null : answer, context: Capture.context(), screenshot: widget.screenshot,
    );
    final sent = await Client.shared.send(draft);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _queued = !sent;
      _step = _Step.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = _step == _Step.done;
    return Scaffold(
      appBar: AppBar(
        title: Text(done ? 'Sent' : 'What’s on your mind?', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 90,
        leading: TextButton(onPressed: widget.onClose, child: Text(done ? 'Done' : 'Cancel')),
      ),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        if (_step != _Step.write) Bubble(you: true, text: _text.text.trim()),
        if (_step == _Step.write) ..._compose(),
        if (_question != null && _step != _Step.write) Bubble(you: false, text: _question!, label: 'Bopmigo asked'),
        if (_step == _Step.followUp) ..._followUp(),
        if (_step == _Step.asking) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
        if (done) ...[
          if (_answer.text.trim().isNotEmpty) Bubble(you: true, text: _answer.text.trim()),
          Bubble(you: false, text: _queued ? 'Saved. It’ll send as soon as you’re back online.' : _thank, label: 'Bopmigo'),
        ],
      ]),
    );
  }

  List<Widget> _compose() => [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'problem', label: Text('Bug')),
            ButtonSegment(value: 'change', label: Text('Feature')),
            ButtonSegment(value: 'idea', label: Text('Idea')),
          ],
          selected: {_category},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _category = s.first),
        ),
        const SizedBox(height: 16),
        Text(_kind.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _field(_text, _kind.$2, autofocus: true, minLines: 4),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _text.text.trim().length < 5 ? null : _next,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          child: const Text('Send'),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HistoryPage(onDone: widget.onClose, embedded: true))),
          child: const Text('Your feedback and replies'),
        ),
      ];

  List<Widget> _followUp() => [
        _field(_answer, 'Your answer (optional)', autofocus: true, minLines: 2),
        const SizedBox(height: 10),
        Row(children: [
          TextButton(onPressed: () { _answer.clear(); _send(); }, child: const Text('Skip')),
          const Spacer(),
          FilledButton(onPressed: _send, child: const Text('Send')),
        ]),
      ];
}

Widget _field(TextEditingController c, String hint, {bool autofocus = false, int minLines = 2}) => TextField(
      controller: c,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: 10,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );

/// One message: theirs on the right, Bopmigo's and the team's on the left.
class Bubble extends StatelessWidget {
  const Bubble({super.key, required this.you, required this.text, this.label});
  final bool you;
  final String text;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: 12, left: you ? 44 : 0, right: you ? 0 : 44),
      child: Align(
        alignment: you ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: you ? _ink : (dark ? const Color(0xFF3A2A22) : _soft), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label ?? 'You', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: you ? Colors.white70 : _teamLabel)),
            const SizedBox(height: 3),
            Text(text, style: TextStyle(color: you ? Colors.white : null)),
          ]),
        ),
      ),
    );
  }
}

String _statusName(String s) => s == 'in_progress' ? 'In progress' : s == 'resolved' ? 'Resolved' : 'Open';

/// Everything this person sent from this device, with a dot on reports that have a new reply.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.onDone, this.embedded = false});
  final VoidCallback onDone;
  final bool embedded;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Report>? _reports;
  Set<String> _unread = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await Client.shared.myReports();
    final unread = (await Client.shared.unread()).map((r) => r.id).toSet();
    if (mounted) setState(() { _reports = list; _unread = unread; });
  }

  @override
  Widget build(BuildContext context) {
    final r = _reports;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your feedback', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [if (!widget.embedded) TextButton(onPressed: widget.onDone, child: const Text('Done'))],
      ),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : r.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Feedback you send shows up here, with any replies from the team.', textAlign: TextAlign.center)))
              : ListView.separated(
                  itemCount: r.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final x = r[i];
                    final isNew = _unread.contains(x.id);
                    return ListTile(
                      leading: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isNew ? accent : Colors.transparent)),
                      minLeadingWidth: 8,
                      title: Text(x.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(isNew ? 'New reply' : _statusName(x.status), style: TextStyle(color: isNew ? accent : null)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ThreadPage(id: x.id, onDone: widget.onDone, pushed: true)));
                        _load();
                      },
                    );
                  },
                ),
    );
  }
}

/// One report and the conversation with the team. Opening it marks the replies as seen.
class ThreadPage extends StatefulWidget {
  const ThreadPage({super.key, required this.id, required this.onDone, this.pushed = false});
  final String id;
  final VoidCallback onDone;
  final bool pushed;
  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  ReportThread? _thread;
  bool _failed = false, _sending = false;
  String? _notice;
  final _reply = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reply.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    final t = await Client.shared.thread(widget.id);
    if (!mounted) return;
    if (t == null) {
      setState(() => _failed = true);
      return;
    }
    setState(() => _thread = t);
    await Client.shared.markSeenId(widget.id);
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    setState(() => _sending = true);
    final ok = await Client.shared.reply(widget.id, text);
    if (!mounted) return;
    if (ok) {
      _reply.clear();
      _notice = null;
      await _load();
    } else {
      _notice = 'Couldn’t send. Check your connection and try again.';
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = _thread;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        automaticallyImplyLeading: widget.pushed,
        actions: [TextButton(onPressed: widget.onDone, child: const Text('Done'))],
      ),
      body: t == null
          ? Center(child: _failed ? const Padding(padding: EdgeInsets.all(24), child: Text('Couldn’t load this conversation. Check your connection and try again.')) : const CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(18), children: [
              Row(children: [
                Expanded(child: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                Chip(label: Text(_statusName(t.status), style: const TextStyle(fontSize: 12)), visualDensity: VisualDensity.compact),
              ]),
              const SizedBox(height: 10),
              Bubble(you: true, text: t.description),
              if (t.question != null) Bubble(you: false, text: t.question!, label: 'Bopmigo asked'),
              if ((t.answer ?? '').isNotEmpty) Bubble(you: true, text: t.answer!),
              for (final m in t.messages) Bubble(you: m.author != 'team', text: m.body, label: m.author == 'team' ? 'Team' : null),
              if (_notice != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_notice!, style: Theme.of(context).textTheme.bodySmall)),
              _field(_reply, 'Reply to the team'),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: _reply.text.trim().isEmpty || _sending ? null : _send, child: Text(_sending ? 'Sending…' : 'Send reply')),
              ),
            ]),
    );
  }
}
