// Copyright 2020 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bosbase/bosbase.dart';

import 'song_detail_tab.dart';
import 'utils.dart';
import 'widgets.dart';
import 'bosbase_service.dart';
import 'config.dart';

class SongsTab extends StatefulWidget {
  static const title = 'Songs';
  static const androidIcon = Icon(Icons.music_note);
  static const iosIcon = Icon(CupertinoIcons.music_note);

  const SongsTab({super.key, this.androidDrawer});

  final Widget? androidDrawer;

  @override
  State<SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<SongsTab> {
  static const _fallbackLength = 50;

  final _androidRefreshKey = GlobalKey<RefreshIndicatorState>();

  late List<MaterialColor> colors;
  late List<String> songNames; // Fallback data

  BosbaseService? _bos;
  bool _useSdk = false;
  List<RecordModel> _sdkSongs = const [];

  @override
  void initState() {
    _setFallbackData();
    _initBosbase();
    super.initState();
  }

  void _setFallbackData() {
    colors = getRandomColors(_fallbackLength);
    songNames = getRandomNames(_fallbackLength);
  }

  Future<bool> _initBosbase() async {
    // 使用共享服务实例；仅在用户已登录时加载 songs
    final service = bosService;
    if (service.isAuthenticated) {
      try {
        final items = await service.listSongs();
        setState(() {
          _bos = service;
          _sdkSongs = items;
          _useSdk = true;
          colors = getRandomColors(items.length);
        });
        return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  Future<void> _refreshData() async {
    if (_useSdk && _bos != null) {
      try {
        final items = await _bos!.listSongs();
        setState(() {
          _sdkSongs = items;
          colors = getRandomColors(items.length);
        });
      } catch (e) {
        // If SDK fetch fails, fall back to local logic
        setState(() {
          _useSdk = false;
          _setFallbackData();
        });
      }
    } else {
      await Future.delayed(
        const Duration(seconds: 2),
        () => setState(() => _setFallbackData()),
      );
    }
  }

  int get _itemCount => _useSdk ? _sdkSongs.length : _fallbackLength;

  Widget _listBuilder(BuildContext context, int index) {
    if (index >= _itemCount) return Container();

    // Show a slightly different color palette. Show poppy-ier colors on iOS
    // due to lighter contrasting bars and tone it down on Android.
    final color = defaultTargetPlatform == TargetPlatform.iOS
        ? colors[index]
        : colors[index].shade400;

    final title = _useSdk
        ? (_sdkSongs[index].getStringValue('name') ?? '')
        : songNames[index];

    void _openDetail() {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => SongDetailTab(
            id: index,
            song: title,
            color: color,
          ),
        ),
      );
    }

    Future<void> _confirmDelete() async {
      if (_useSdk && _bos != null) {
        final id = _sdkSongs[index].id;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Song'),
            content: Text('Are you sure to delete "$title"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            await _bos!.deleteSong(id);
            setState(() {
              _sdkSongs.removeAt(index);
              colors = getRandomColors(_sdkSongs.length);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Deleted successfully')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Delete failed: $e')),
            );
          }
        }
      } else {
        // Fallback delete: remove from local list only
        setState(() {
          songNames.removeAt(index);
          colors = getRandomColors(_itemCount - 1);
        });
      }
    }

    return SafeArea(
      top: false,
      bottom: false,
      child: GestureDetector(
        onLongPress: _confirmDelete,
        child: Hero(
          tag: index,
          child: HeroAnimatingSongCard(
            song: title,
            color: color,
            heroAnimation: const AlwaysStoppedAnimation(0),
            onPressed: _openDetail,
          ),
        ),
      ),
    );
  }

  void _togglePlatform() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    } else {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    }

    // This rebuilds the application. This should obviously never be
    // done in a real app but it's done here since this app
    // unrealistically toggles the current platform for demonstration
    // purposes.
    WidgetsBinding.instance.reassembleApplication();
  }

  // ===========================================================================
  // Non-shared code below because:
  // - Android and iOS have different scaffolds
  // - There are different items in the app bar / nav bar
  // - Android has a hamburger drawer, iOS has bottom tabs
  // - The iOS nav bar is scrollable, Android is not
  // - Pull-to-refresh works differently, and Android has a button to trigger it too
  //
  // And these are all design time choices that doesn't have a single 'right'
  // answer.
  // ===========================================================================
  Widget _buildAndroid(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(SongsTab.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async =>
                await _androidRefreshKey.currentState!.show(),
          ),
          IconButton(
            icon: const Icon(Icons.shuffle),
            onPressed: _togglePlatform,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addRandomSong(context),
          ),
        ],
      ),
      drawer: widget.androidDrawer,
      body: RefreshIndicator(
        key: _androidRefreshKey,
        onRefresh: _refreshData,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: _itemCount,
          itemBuilder: _listBuilder,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addRandomSong(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildIos(BuildContext context) {
    return CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _togglePlatform,
            child: const Icon(CupertinoIcons.shuffle),
          ),
          largeTitle: const Text(SongsTab.title),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _addRandomSong(context),
            child: const Icon(CupertinoIcons.add),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: _refreshData),
        SliverSafeArea(
          top: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                _listBuilder,
                childCount: _itemCount,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addRandomSong(BuildContext context) async {
    // Ensure SDK is initialized and available
    if (!_useSdk || _bos == null) {
      final ok = await _initBosbase();
      if (!ok || _bos == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录后再添加歌曲。')),
        );
        Navigator.pushNamed(context, '/login');
        return;
      }
    }

    final generatedName = getRandomNames(1).first;
    try {
      final rec = await _bos!.addSong(generatedName);
      setState(() {
        _sdkSongs.insert(0, rec);
        colors = getRandomColors(_sdkSongs.length);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add failed: $e')),
      );
    }
  }

  @override
  Widget build(context) {
    return PlatformWidget(
      androidBuilder: _buildAndroid,
      iosBuilder: _buildIos,
    );
  }
}
