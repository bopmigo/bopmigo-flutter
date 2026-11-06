// A small trip-booking app with a couple of planted problems to try Bopmigo with.
// Put your app ID from bopmigo.com below, run it, then tap "Send feedback" or take a screenshot.
import 'package:bopmigo/bopmigo.dart';
import 'package:flutter/material.dart';

const appId = String.fromEnvironment('BOPMIGO_APP_ID', defaultValue: 'YOUR-APP-ID');
const host = String.fromEnvironment('BOPMIGO_HOST', defaultValue: 'https://bopmigo.com');

Future<void> main() async {
  await Bopmigo.configure(appId: appId, screenshotPrompt: ScreenshotPrompt.always, host: Uri.parse(host));
  Bopmigo.setContext('plan', 'trial');
  runApp(const SampleApp());
}

class SampleApp extends StatelessWidget {
  const SampleApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Peaks',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2E6B4F), useMaterial3: true),
        builder: Bopmigo.builder,
        navigatorObservers: [Bopmigo.navigatorObserver],
        initialRoute: 'Stays',
        routes: {'Stays': (_) => const StaysPage()},
      );
}

const stays = [
  ('Alpine cabin', 'Zermatt, Switzerland', 184),
  ('Lakeside lodge', 'Hallstatt, Austria', 142),
  ('Fjord house', 'Geiranger, Norway', 219),
];

class StaysPage extends StatelessWidget {
  const StaysPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Peaks'), actions: [
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'Account'), builder: (_) => const AccountPage()))),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (final s in stays)
            Card(
              child: ListTile(
                title: Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(s.$2),
                trailing: Text('\$${s.$3} / night'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'Stay details'), builder: (_) => StayPage(stay: s))),
              ),
            ),
        ]),
      );
}

class StayPage extends StatefulWidget {
  const StayPage({super.key, required this.stay});
  final (String, String, int) stay;
  @override
  State<StayPage> createState() => _StayPageState();
}

class _StayPageState extends State<StayPage> {
  int nights = 2;
  @override
  Widget build(BuildContext context) {
    // Planted problem: the total ignores the number of nights after the first change.
    final total = widget.stay.$3 * (nights > 2 ? 3 : nights);
    return Scaffold(
      appBar: AppBar(title: Text(widget.stay.$1)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.stay.$2, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          Row(children: [
            const Text('Nights'),
            const Spacer(),
            IconButton(onPressed: nights > 1 ? () => setState(() => nights--) : null, icon: const Icon(Icons.remove_circle_outline)),
            Text('$nights', style: const TextStyle(fontSize: 18)),
            IconButton(onPressed: () => setState(() => nights++), icon: const Icon(Icons.add_circle_outline)),
          ]),
          const Divider(),
          Row(children: [const Text('Total'), const Spacer(), Text('\$$total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))]),
          const Spacer(),
          FilledButton(onPressed: () {}, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Reserve')),
        ]),
      ),
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const ListTile(title: Text('Name'), subtitle: Text('Alex Rivera')),
          const ListTile(title: Text('Email'), subtitle: BopmigoPrivate(child: Text('alex.rivera@example.com'))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(obscureText: true, decoration: InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Send feedback'),
            trailing: const Icon(Icons.chevron_right),
            onTap: Bopmigo.show,
          ),
          ListTile(
            leading: const Icon(Icons.forum_outlined),
            title: const Text('Your feedback and replies'),
            trailing: const Icon(Icons.chevron_right),
            onTap: Bopmigo.showReplies,
          ),
        ]),
      );
}
