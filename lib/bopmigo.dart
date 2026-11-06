/// In-app feedback for Flutter apps on iPhone and Android.
///
/// Set up once, then call `Bopmigo.show()` from a button, or let testers report after a screenshot.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'src/client.dart';
import 'src/state.dart';
import 'src/ui.dart';

export 'src/capture.dart' show BopmigoPrivate;

/// When taking a screenshot should offer "Report a problem?".
enum ScreenshotPrompt {
  /// Never; open feedback from your own button.
  never,

  /// Debug builds, TestFlight and installs from outside Google Play. People who install from the stores are never asked.
  testersOnly,

  /// Everyone who takes a screenshot (Android 14 and later on Android).
  always,
}

class Bopmigo {
  Bopmigo._();

  static ScreenshotPrompt _prompt = ScreenshotPrompt.testersOnly;

  /// Starts Bopmigo. Call once before `runApp`.
  ///
  ///     Bopmigo.configure(appId: 'YOUR-APP-ID');
  ///
  /// [appId] is shown in Bopmigo under your app's install settings.
  /// Leave [host] as is unless you were given a test address.
  static Future<void> configure({required String appId, ScreenshotPrompt screenshotPrompt = ScreenshotPrompt.testersOnly, Uri? host}) async {
    WidgetsFlutterBinding.ensureInitialized();
    BopmigoState.appId = appId;
    if (host != null) BopmigoState.host = host;
    _prompt = screenshotPrompt;
    BopmigoState.channel.setMethodCallHandler((call) async {
      if (call.method == 'screenshot') BopmigoHostState.current?.offerAfterScreenshot();
    });
    try {
      BopmigoState.native = Map<String, Object?>.from(await BopmigoState.channel.invokeMethod<Map>('info') ?? {});
    } catch (_) {}
    final tester = BopmigoState.native['tester'] == true || kDebugMode;
    final ask = switch (_prompt) { ScreenshotPrompt.never => false, ScreenshotPrompt.always => true, ScreenshotPrompt.testersOnly => tester };
    try {
      await BopmigoState.channel.invokeMethod('watchScreenshots', ask);
    } catch (_) {}
    unawaited(Client.shared.loadConfig().then((_) => Client.shared.sendQueued()));
  }

  /// Add to your `MaterialApp` (or `CupertinoApp`, `WidgetsApp`):
  ///
  ///     MaterialApp(builder: Bopmigo.builder, ...)
  ///
  /// If you already use `builder`, wrap its result: `builder: (context, child) => Bopmigo.builder(context, yours(child))`.
  static Widget builder(BuildContext context, Widget? child) => BopmigoHost(child: child ?? const SizedBox.shrink());

  /// Names screens in reports from your routes' names. Optional:
  ///
  ///     MaterialApp(navigatorObservers: [Bopmigo.navigatorObserver], ...)
  static final NavigatorObserver navigatorObserver = _ScreenObserver();

  /// Opens the feedback sheet over the current screen.
  static void show() => _host?.open();

  /// Opens the list of feedback this person sent, with the team's replies.
  static void showReplies() => _host?.open(history: true);

  /// Names the screen the person is on, so reports say where it happened.
  static void setScreen(String? name) => BopmigoState.screen = name;

  /// Who is reporting, if they are signed in to your app. Optional.
  static void setUser({String? id, String? email, String? name}) {
    BopmigoState.user = {'userId': ?id, 'userEmail': ?email, 'userName': ?name};
  }

  /// Extra details attached to every report, for example a plan or build flavor. Up to 20.
  static void setContext(String key, String? value) {
    final clean = key.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
    final k = 'custom_${clean.length > 32 ? clean.substring(0, 32) : clean}';
    value == null ? BopmigoState.custom.remove(k) : BopmigoState.custom[k] = value;
  }

  /// Hides every word in screenshots, not only passwords and private widgets.
  static void setHideAllText(bool on) => BopmigoState.hideAllText = on;

  static BopmigoHostState? get _host {
    final h = BopmigoHostState.current;
    assert(BopmigoState.appId != null, 'Call Bopmigo.configure(appId:) before Bopmigo.show().');
    assert(h != null, 'Add builder: Bopmigo.builder to your MaterialApp.');
    return h;
  }
}

class _ScreenObserver extends NavigatorObserver {
  void _set(Route<dynamic>? r) {
    final name = r?.settings.name;
    if (name != null && name.isNotEmpty) BopmigoState.screen = name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _set(newRoute);
}
