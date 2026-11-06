# Bopmigo for Flutter

Know what went wrong in your Flutter app, on iPhone and Android. Testers report it in a line or two, and your team gets the whole story, with a short follow-up if something important is missing.

Reports arrive in your [Bopmigo](https://bopmigo.com) inbox, or in your email if you prefer. When you reply, they see it in your app and can answer back.

## Install

1. Create a free account at [bopmigo.com](https://bopmigo.com) and connect an **app**. Copy your app ID.
2. Add the package:

```
flutter pub add bopmigo
```

3. Configure it before `runApp`, and add the builder to your app:

```dart
import 'package:bopmigo/bopmigo.dart';

Future<void> main() async {
  await Bopmigo.configure(appId: 'YOUR-APP-ID');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        builder: Bopmigo.builder,
        navigatorObservers: [Bopmigo.navigatorObserver], // optional: reports say which screen
        home: const HomePage(),
      );
}
```

4. Run the app and take a screenshot, or call `Bopmigo.show()`. Send a test.

Works with `MaterialApp`, `CupertinoApp` and `WidgetsApp`. If you already use `builder`, wrap yours: `builder: (context, child) => Bopmigo.builder(context, yours(context, child))`.

## Open feedback from your own button

```dart
ListTile(title: const Text('Send feedback'), onTap: Bopmigo.show)
```

`Bopmigo.showReplies()` opens the person's past feedback with your team's replies.

## Who sees "Report a problem?"

```dart
Bopmigo.configure(appId: 'YOUR-APP-ID', screenshotPrompt: ScreenshotPrompt.testersOnly) // default
Bopmigo.configure(appId: 'YOUR-APP-ID', screenshotPrompt: ScreenshotPrompt.always)
Bopmigo.configure(appId: 'YOUR-APP-ID', screenshotPrompt: ScreenshotPrompt.never)
```

- `testersOnly` (default): debug builds, TestFlight, and Android installs that didn't come from Google Play. People who install from the App Store or Google Play are never asked.
- `always`: everyone who takes a screenshot is asked.
- `never`: no offer after screenshots; open feedback from your own button.

Android tells apps about screenshots from Android 14. On older versions, use your own button.

## Options

```dart
BopmigoPrivate(child: Text(user.email))   // covered in screenshots
Bopmigo.setHideAllText(true)              // cover every word in screenshots
Bopmigo.setScreen('Checkout')             // or name your routes and add Bopmigo.navigatorObserver
Bopmigo.setUser(id: user.id, email: user.email, name: user.name)  // only if you want it in reports
Bopmigo.setContext('plan', 'pro')         // your own details
```

Password fields are always covered.

## What is sent

The note, the answer to the follow-up if given, a screenshot with private areas covered, the app version and build, OS version, device model, language, time zone and the screen name. Nothing about the person unless you call `setUser`. If sending fails, the report is kept on the device and sent when the app is next opened.

## Example

`example/` is a small booking app with a planted problem to try it with.

## Docs

[bopmigo.com/docs/add-in-app-feedback-to-flutter-app](https://bopmigo.com/docs/add-in-app-feedback-to-flutter-app)

## License

MIT
