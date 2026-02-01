// Copyright 2020 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'news_tab.dart';
import 'profile_tab.dart';
import 'settings_tab.dart';
import 'songs_tab.dart';
import 'widgets.dart';
import 'bosbase_service.dart';
import 'auth/login_page.dart';
import 'auth/register_page.dart';
import 'config.dart';

void main() => runApp(const MyAdaptingApp());

class MyAdaptingApp extends StatelessWidget {
  const MyAdaptingApp({super.key});

  @override
  Widget build(context) {
    // Either Material or Cupertino widgets work in either Material or Cupertino
    // Apps.
    return MaterialApp(
      title: 'Adaptive Music App',
      theme: ThemeData(
        // Use the green theme for Material widgets.
        primarySwatch: Colors.green,
      ),
      darkTheme: ThemeData.dark(),
      // Remove builder wrapper to avoid potential global overlay affecting input events
      home: const LoginPage(),
      routes: {
        '/home': (_) => const PlatformAdaptingHomePage(),
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
      },
    );
  }
}

// Shows a different type of scaffold depending on the platform.
//
// This file has the most amount of non-sharable code since it behaves the most
// differently between the platforms.
//
// These differences are also subjective and have more than one 'right' answer
// depending on the app and content.
class PlatformAdaptingHomePage extends StatefulWidget {
  const PlatformAdaptingHomePage({super.key});

  @override
  State<PlatformAdaptingHomePage> createState() =>
      _PlatformAdaptingHomePageState();
}

class _PlatformAdaptingHomePageState
    extends State<PlatformAdaptingHomePage> {
  // This app keeps a global key for the songs tab because it owns a bunch of
  // data. Since changing platform re-parents those tabs into different
  // scaffolds, keeping a global key to it lets this app keep that tab's data as
  // the platform toggles.
  //
  // This isn't needed for apps that doesn't toggle platforms while running.
  final songsTabKey = GlobalKey();

  // In Material, this app uses the hamburger menu paradigm and flatly lists
  // all 4 possible tabs. This drawer is injected into the songs tab which is
  // actually building the scaffold around the drawer.
  Widget _buildAndroidHomePage(BuildContext context) {
    // Changed to use bottom navigation structure to ensure bottom navbar always displays
    return _AndroidTabScaffold(songsTabKey: songsTabKey);
  }

  // On iOS, the app uses a bottom tab paradigm. Here, each tab view sits inside
  // a tab in the tab scaffold. The tab scaffold also positions the tab bar
  // in a row at the bottom.
  //
  // An important thing to note is that while a Material Drawer can display a
  // large number of items, a tab bar cannot. To illustrate one way of adjusting
  // for this, the app folds its fourth tab (the settings page) into the
  // third tab. This is a common pattern on iOS.
  Widget _buildIosHomePage(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            label: SongsTab.title,
            icon: SongsTab.iosIcon,
          ),
          BottomNavigationBarItem(
            label: NewsTab.title,
            icon: NewsTab.iosIcon,
          ),
          BottomNavigationBarItem(
            label: ProfileTab.title,
            icon: ProfileTab.iosIcon,
          ),
        ],
      ),
      tabBuilder: (context, index) {
        assert(index <= 2 && index >= 0, 'Unexpected tab index: $index');
        return switch (index) {
          0 => CupertinoTabView(
            defaultTitle: SongsTab.title,
            builder: (context) => SongsTab(key: songsTabKey),
          ),
          1 => CupertinoTabView(
            defaultTitle: NewsTab.title,
            builder: (context) => const NewsTab(),
          ),
          2 => CupertinoTabView(
            defaultTitle: ProfileTab.title,
            builder: (context) => const ProfileTab(),
          ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  @override
  Widget build(context) {
    return PlatformWidget(
      androidBuilder: _buildAndroidHomePage,
      iosBuilder: _buildIosHomePage,
    );
  }
}

class _AndroidDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.green),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Icon(
                Icons.account_circle,
                color: Colors.green.shade800,
                size: 96,
              ),
            ),
          ),
          ListTile(
            leading: SongsTab.androidIcon,
            title: const Text(SongsTab.title),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: NewsTab.androidIcon,
            title: const Text(NewsTab.title),
            onTap: () {
              Navigator.pop(context);
              Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (context) => const NewsTab()),
              );
            },
          ),
          ListTile(
            leading: ProfileTab.androidIcon,
            title: const Text(ProfileTab.title),
            onTap: () {
              Navigator.pop(context);
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileTab(),
                ),
              );
            },
          ),
          // Long drawer contents are often segmented.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(),
          ),
          ListTile(
            leading: SettingsTab.androidIcon,
            title: const Text(SettingsTab.title),
            onTap: () {
              Navigator.pop(context);
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsTab(),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              // Clear authentication and stored credentials, then navigate to login
              await bosService.logout();
              Navigator.pop(context); // close drawer
              // Remove all routes and go to login screen
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}

// Android uses BottomNavigationBar to ensure bottom navbar displays after login.
class _AndroidTabScaffold extends StatefulWidget {
  const _AndroidTabScaffold({required this.songsTabKey});

  final GlobalKey songsTabKey;

  @override
  State<_AndroidTabScaffold> createState() => _AndroidTabScaffoldState();
}

class _AndroidTabScaffoldState extends State<_AndroidTabScaffold> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      SongsTab(key: widget.songsTabKey, androidDrawer: _AndroidDrawer()),
      const NewsTab(),
      const ProfileTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            label: SongsTab.title,
            icon: SongsTab.androidIcon,
          ),
          BottomNavigationBarItem(
            label: NewsTab.title,
            icon: NewsTab.androidIcon,
          ),
          BottomNavigationBarItem(
            label: ProfileTab.title,
            icon: ProfileTab.androidIcon,
          ),
        ],
      ),
    );
  }
}
