import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'client.dart';
import 'state.dart';

/// Covers its child in Bopmigo screenshots.
///
///     BopmigoPrivate(child: Text(user.email))
class BopmigoPrivate extends StatefulWidget {
  const BopmigoPrivate({super.key, required this.child});
  final Widget child;
  @override
  State<BopmigoPrivate> createState() => _BopmigoPrivateState();
}

class _BopmigoPrivateState extends State<BopmigoPrivate> {
  @override
  void initState() {
    super.initState();
    Capture.marked.add(this);
  }

  @override
  void dispose() {
    Capture.marked.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Takes the screenshot with private areas covered before it leaves the phone.
class Capture {
  static final Set<State> marked = {};
  static final boundaryKey = GlobalKey();

  /// A PNG of the app with passwords and private widgets covered, base64, or null.
  static Future<String?> screenshot() async {
    final ctx = boundaryKey.currentContext;
    final boundary = ctx?.findRenderObject();
    if (ctx == null || boundary is! RenderRepaintBoundary || !boundary.hasSize) return null;
    final covers = <Rect>[];
    Rect? rectOf(BuildContext c) {
      final box = c.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return null;
      final topLeft = box.localToGlobal(Offset.zero, ancestor: boundary);
      return topLeft & box.size;
    }

    for (final s in marked) {
      if (s.mounted) {
        final r = rectOf(s.context);
        if (r != null) covers.add(r);
      }
    }
    // Password fields are always covered.
    void walk(Element e) {
      final w = e.widget;
      if (w is EditableText && w.obscureText) {
        final r = rectOf(e);
        if (r != null) covers.add(r);
        return;
      }
      e.visitChildElements(walk);
    }

    (ctx as Element).visitChildElements(walk);

    final view = View.maybeOf(ctx);
    final dpr = view?.devicePixelRatio ?? 2.0;
    for (final ratio in [min(dpr, 3.0), 2.0, 1.5, 1.0]) {
      final png = await _render(boundary, covers, ratio);
      if (png != null && png.length < 1800000) return base64Encode(png);
    }
    return null;
  }

  static Future<List<int>?> _render(RenderRepaintBoundary boundary, List<Rect> covers, double ratio) async {
    try {
      final shot = await boundary.toImage(pixelRatio: ratio);
      final w = shot.width.toDouble(), h = shot.height.toDouble();
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      if (BopmigoState.hideAllText) {
        // Blocks out every word but keeps the layout readable: draw small, then scale up without smoothing.
        final small = (14 * ratio);
        final sw = max(1, (w / small).round()), sh = max(1, (h / small).round());
        final r2 = ui.PictureRecorder();
        Canvas(r2).drawImageRect(shot, Offset.zero & Size(w, h), Offset.zero & Size(sw.toDouble(), sh.toDouble()), Paint()..filterQuality = FilterQuality.medium);
        final tiny = await r2.endRecording().toImage(sw, sh);
        canvas.drawImageRect(tiny, Offset.zero & Size(sw.toDouble(), sh.toDouble()), Offset.zero & Size(w, h), Paint()..filterQuality = FilterQuality.none);
      } else {
        canvas.drawImage(shot, Offset.zero, Paint());
      }
      final black = Paint()..color = const Color(0xFF000000);
      for (final r in covers) {
        final s = Rect.fromLTRB(r.left * ratio, r.top * ratio, r.right * ratio, r.bottom * ratio).inflate(2 * ratio);
        canvas.drawRRect(RRect.fromRectAndRadius(s, Radius.circular(4 * ratio)), black);
      }
      final out = await rec.endRecording().toImage(shot.width, shot.height);
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// App and device details sent with each report. No identifiers beyond what the app sets.
  static Map<String, Object?> context() {
    final n = BopmigoState.native;
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    final size = view == null ? null : view.physicalSize / view.devicePixelRatio;
    final os = n['os'] as String? ?? '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    final c = <String, Object?>{
      'release': '${n['version'] ?? '?'} (${n['build'] ?? '?'})',
      'sdk': '${n['name'] ?? 'App'} on ${os.split(' ').first}, Bopmigo Flutter ${Client.version}',
      'device': n['device'] ?? Platform.operatingSystem,
      'os': os,
      if (size != null) 'viewport': '${size.width.round()} × ${size.height.round()}',
      if (view != null) 'pixelRatio': view.devicePixelRatio,
      'language': n['language'] ?? Platform.localeName.replaceAll('_', '-'),
      'timezone': n['timezone'] ?? DateTime.now().timeZoneName,
      'appId': n['appId'] ?? '',
    };
    if (BopmigoState.screen != null) c['screen'] = BopmigoState.screen;
    c.addAll(BopmigoState.user);
    c.addAll(Map.fromEntries(BopmigoState.custom.entries.take(20)));
    return c;
  }
}
