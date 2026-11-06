// A small booking app with a few planted problems, so each kind of report can be tried:
// - Stays: the total doesn't update when you change check-out (a clear bug).
// - Search: Reserve does nothing, and one search shows no results (vague bugs).
// - Profile: private details that must be hidden in the screenshot.
// - Settings: no dark mode yet (feature requests), and a long scrolling list.
// Photos on Unsplash (Unsplash License): Evan Leith (cabin), Clay Banks (interiors), Sibel Kusdemir (host).
import 'package:bopmigo/bopmigo.dart';
import 'package:flutter/material.dart';

// Your app ID from Bopmigo. `always` so you can try the screenshot offer in the Simulator or emulator.
const appId = String.fromEnvironment('BOPMIGO_APP_ID', defaultValue: 'YOUR-APP-ID');
const host = String.fromEnvironment('BOPMIGO_HOST', defaultValue: 'https://bopmigo.com');

Future<void> main() async {
  await Bopmigo.configure(appId: appId, screenshotPrompt: ScreenshotPrompt.always, host: Uri.parse(host));
  Bopmigo.setUser(id: 'guest-42', email: 'maria@example.com', name: 'Maria Lopez');
  runApp(const SampleApp());
}

const pine = Color(0xFF1C3A2B);

class SampleApp extends StatelessWidget {
  const SampleApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Stays',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: pine, surface: Colors.white),
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
        ),
        builder: Bopmigo.builder,
        home: const Tabs(),
      );
}

class Tabs extends StatefulWidget {
  const Tabs({super.key});
  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  int tab = 0;
  static const names = ['Checkout', 'Search', 'Profile', 'Settings'];

  @override
  void initState() {
    super.initState();
    Bopmigo.setScreen(names[0]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: tab, children: const [StaysPage(), SearchPage(), ProfilePage(), SettingsPage()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE6EEE9),
          onDestinationSelected: (i) => setState(() {
            tab = i;
            Bopmigo.setScreen(names[i]);
          }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.house_outlined), selectedIcon: Icon(Icons.house), label: 'Stays'),
            NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      );
}

Widget photo(String id, {int width = 1200, double? w, double? h}) => Image.network(
      'https://images.unsplash.com/$id?w=$width&q=80&auto=format&fit=crop',
      width: w,
      height: h,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(color: const Color(0xFFE6E6E6), width: w, height: h),
      loadingBuilder: (_, child, p) => p == null ? child : Container(color: const Color(0xFFE6E6E6), width: w, height: h),
    );

/// Bug 1: check-out was moved to Nov 18, but the nights and total still say 3 nights.
class StaysPage extends StatefulWidget {
  const StaysPage({super.key});
  @override
  State<StaysPage> createState() => _StaysPageState();
}

class _StaysPageState extends State<StaysPage> {
  static const photos = ['photo-1542213598-8fbf6282334b', 'photo-1777895868494-4e01af8487b6', 'photo-1774927475366-7c4d31588d98'];
  int page = 0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    return Column(children: [
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          SizedBox(
            height: 340 + top * 0.3,
            child: Stack(fit: StackFit.expand, children: [
              PageView(onPageChanged: (i) => setState(() => page = i), children: [for (final p in photos) photo(p)]),
              Positioned(
                top: top + 8, left: 16, right: 16,
                child: Row(children: [_circle(Icons.chevron_left), const Spacer(), _circle(Icons.ios_share), const SizedBox(width: 8), _circle(Icons.favorite_border)]),
              ),
              Positioned(
                right: 16, bottom: 36,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(99)),
                  child: Text('${page + 1} / ${photos.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
          Transform.translate(
            offset: const Offset(0, -24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(children: [
                const SizedBox(height: 24),
                Text('Forest Cabin in Hemsedal', textAlign: TextAlign.center, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Entire cabin · 4 guests · 2 bedrooms · 1 bath', style: t.bodyMedium?.copyWith(color: Colors.black54)),
                const SizedBox(height: 6),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.star, size: 15),
                  SizedBox(width: 4),
                  Text('4.96', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('  ·  ', style: TextStyle(color: Colors.black54)),
                  Text('212 reviews', style: TextStyle(decoration: TextDecoration.underline)),
                ]),
                const SizedBox(height: 20),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(children: [
                    ClipOval(child: photo('photo-1757348665310-0b68ed0ebc30', width: 160, w: 44, h: 44)),
                    const SizedBox(width: 14),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Hosted by Ingrid', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('Superhost · 6 years hosting', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ]),
                  ]),
                ),
                const Divider(height: 1),
                const SizedBox(height: 20),
                Align(alignment: Alignment.centerLeft, child: Text('What this place offers', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                const SizedBox(height: 14),
                Row(children: [_amenity(Icons.local_fire_department_outlined, 'Sauna'), _amenity(Icons.fireplace_outlined, 'Fireplace'), _amenity(Icons.wifi, 'Wi-Fi'), _amenity(Icons.directions_car_outlined, 'Parking')]),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),
                Align(alignment: Alignment.centerLeft, child: Text('Your trip', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDDDDD)), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    _date('Check-in', 'Thu, Nov 14'),
                    Container(width: 1, height: 36, color: const Color(0xFFDDDDDD)),
                    _date('Check-out', 'Mon, Nov 18'),
                  ]),
                ),
                const SizedBox(height: 14),
                _row('€204 × 3 nights', '€612'), // planted bug: not updated for 4 nights
                _row('Cleaning fee', '€0'),
                const Divider(),
                _row('Total', '€612', bold: true),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ]),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE5E5E5)))),
        child: Row(children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('€612', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text('Nov 14 – 18 · 3 nights', style: TextStyle(fontSize: 13, color: Colors.black54, decoration: TextDecoration.underline)),
          ]),
          const Spacer(),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(backgroundColor: pine, minimumSize: const Size(150, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: const Text('Reserve', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ]),
      ),
    ]);
  }

  Widget _circle(IconData icon) => Container(
        width: 38, height: 38,
        decoration: const BoxDecoration(color: Color(0xE6FFFFFF), shape: BoxShape.circle),
        child: Icon(icon, size: 19, color: Colors.black87),
      );
  Widget _amenity(IconData icon, String label) => Expanded(child: Column(children: [Icon(icon, size: 22), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 12))]));
  Widget _date(String label, String value) => Expanded(
        child: Column(children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : null, color: bold ? null : Colors.black54, fontSize: bold ? 17 : 15)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w700 : null, color: bold ? null : Colors.black54, fontSize: bold ? 17 : 15)),
        ]),
      );
}

/// Bug 2: Reserve does nothing; searching "Lisbon" shows nothing at all.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const all = ['Forest House, Oslo', 'Harbour Loft, Porto', 'Dune Cabin, Sylt', 'Old Town Flat, Prague'];
  String query = '';
  List<String> get results => query.isEmpty ? all : (query.toLowerCase() == 'lisbon' ? [] : all.where((s) => s.toLowerCase().contains(query.toLowerCase())).toList());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Search', style: TextStyle(fontWeight: FontWeight.w700)), centerTitle: false, backgroundColor: Colors.white),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Try Lisbon',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF1F1F1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          // planted bug: blank, no "no results" message
          Expanded(
            child: ListView.separated(
              itemCount: results.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
              itemBuilder: (_, i) => ListTile(
                title: Text(results[i]),
                trailing: OutlinedButton(onPressed: () {/* planted bug: does nothing */}, child: const Text('Reserve')),
              ),
            ),
          ),
        ]),
      );
}

/// Account screen with a "Send feedback" row (the button route, no screenshot needed).
/// The email, card and address are marked private, so they come out covered in screenshots.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: AppBar(title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w700)), centerTitle: false, backgroundColor: const Color(0xFFF2F2F7)),
        body: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          _section(null, [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                ClipOval(child: photo('photo-1494790108377-be9c29b29330', width: 200, w: 60, h: 60)),
                const SizedBox(width: 14),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Maria Lopez', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  SizedBox(height: 3),
                  BopmigoPrivate(child: Text('maria.lopez@icloud.com', style: TextStyle(color: Colors.black54))),
                ]),
              ]),
            ),
          ]),
          _section('Account', [
            _row(Icons.person_outline, 'Personal information'),
            _row(Icons.credit_card, 'Payments', trailing: const BopmigoPrivate(child: Text('Visa •••• 8317', style: TextStyle(color: Colors.black54)))),
            _row(Icons.house_outlined, 'Home address', trailing: const BopmigoPrivate(child: Text('Calle Mayor 12, Madrid', style: TextStyle(color: Colors.black54)))),
            _row(Icons.notifications_none, 'Notifications'),
          ]),
          _section('Support', [
            _row(Icons.chat_bubble_outline, 'Send feedback', onTap: Bopmigo.show),
            _row(Icons.forum_outlined, 'Your feedback and replies', onTap: Bopmigo.showReplies),
            _row(Icons.help_outline, 'Help Center'),
            _row(Icons.description_outlined, 'Terms and privacy'),
          ]),
          _section(null, [const ListTile(title: Text('Log out', style: TextStyle(color: Colors.red)))]),
          const SizedBox(height: 24),
        ]),
      );
}

Widget _section(String? title, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null) Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 6), child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.black54))) else const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[rows[i], if (i < rows.length - 1) const Divider(height: 1, indent: 52)],
        ]),
      ),
    ]);

Widget _row(IconData icon, String title, {Widget? trailing, VoidCallback? onTap}) => ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.black26),
      onTap: onTap ?? () {},
    );

/// Feature requests (no dark mode, no currency choice) and a long list to scroll.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool hideText = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)), centerTitle: false, backgroundColor: const Color(0xFFF2F2F7)),
        body: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          _section('Display', const [
            ListTile(title: Text('Theme'), trailing: Text('Light only', style: TextStyle(color: Colors.black54))),
            ListTile(title: Text('Currency'), trailing: Text('EUR', style: TextStyle(color: Colors.black54))),
          ]),
          _section('Testing', [
            SwitchListTile(
              title: const Text('Hide all text in screenshots'),
              value: hideText,
              onChanged: (on) => setState(() {
                hideText = on;
                Bopmigo.setHideAllText(on);
              }),
            ),
          ]),
          _section('Notifications', [for (var i = 1; i <= 25; i++) SwitchListTile(title: Text('Alert $i'), value: i % 3 == 0, onChanged: null)]),
          _section(null, [ListTile(title: const Text('Send feedback'), onTap: Bopmigo.show)]),
          const SizedBox(height: 24),
        ]),
      );
}
