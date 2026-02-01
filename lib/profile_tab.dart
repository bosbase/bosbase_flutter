// Copyright 2020 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'settings_tab.dart';
import 'widgets.dart';
import 'bosbase_service.dart';

class ProfileTab extends StatefulWidget {
  static const title = 'Profile';
  static const androidIcon = Icon(Icons.person);
  static const iosIcon = Icon(CupertinoIcons.profile_circled);

  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String? _email;
  String? _avatarUrl;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _syncUser();
  }

  void _syncUser() {
    setState(() {
      _email = bosService.currentUserEmail;
      _avatarUrl = bosService.currentUserAvatarUrl(thumb: '300x300f');
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final updated = await bosService.updateCurrentUserAvatarBytes(
        filename: picked.name,
        bytes: bytes,
      );
      // Directly use latest returned record to refresh avatar and email, avoid depending on authStore's local state
      setState(() {
        _email = updated.getStringValue('email') ?? _email;
        _avatarUrl = bosService.avatarUrlFor(updated, thumb: '300x300f');
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _buildBody(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(8),
              child: Center(
                child: GestureDetector(
                  onTap: _uploading ? null : _pickAndUploadAvatar,
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: Colors.green.shade100,
                    backgroundImage:
                        _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null
                        ? const Text('😼', style: TextStyle(fontSize: 48))
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_email != null)
              Text('Email: ${_email!}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _uploading ? null : _pickAndUploadAvatar,
                icon: const Icon(Icons.photo_camera),
                label: _uploading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Change Avatar'),
              ),
            ),
            // Removed preference cards per request
            Expanded(child: Container()),
            const LogOutButton(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Non-shared code below because on iOS, the settings tab is nested inside of
  // the profile tab as a button in the nav bar.
  // ===========================================================================

  Widget _buildAndroid(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(ProfileTab.title)),
      body: _buildBody(context),
    );
  }

  Widget _buildIos(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: SettingsTab.iosIcon,
          onPressed: () {
            // This pushes the settings page as a full page modal dialog on top
            // of the tab bar and everything.
            Navigator.of(context, rootNavigator: true).push<void>(
              CupertinoPageRoute(
                title: SettingsTab.title,
                fullscreenDialog: true,
                builder: (context) => const SettingsTab(),
              ),
            );
          },
        ),
      ),
      child: _buildBody(context),
    );
  }

  @override
  Widget build(context) {
    return PlatformWidget(
      androidBuilder: _buildAndroid,
      iosBuilder: _buildIos,
    );
  }
}

class PreferenceCard extends StatelessWidget {
  const PreferenceCard({
    required this.header,
    required this.content,
    required this.preferenceChoices,
    super.key,
  });

  final String header;
  final String content;
  final List<String> preferenceChoices;

  @override
  Widget build(context) {
    return PressableCard(
      color: Colors.green,
      flattenAnimation: const AlwaysStoppedAnimation(0),
      child: Stack(
        children: [
          SizedBox(
            height: 120,
            width: 250,
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(content, style: const TextStyle(fontSize: 48)),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black12,
              height: 40,
              padding: const EdgeInsets.only(left: 12),
              alignment: Alignment.centerLeft,
              child: Text(
                header,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      onPressed: () {
        showChoices(context, preferenceChoices);
      },
    );
  }
}

class LogOutButton extends StatelessWidget {
  const LogOutButton({super.key});

  // ===========================================================================
  // Non-shared code below because this tab shows different interfaces. On
  // Android, it's showing an alert dialog with 2 buttons and on iOS,
  // it's showing an action sheet with 3 choices.
  //
  // This is a design choice and you may want to do something different in your
  // app.
  // ===========================================================================

  Widget _buildAndroid(BuildContext context) {
    return ElevatedButton(
      child: const Text('LOG OUT', style: TextStyle(color: Colors.red)),
      onPressed: () async {
        await bosService.logout();
        if (!context.mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      },
    );
  }

  Widget _buildIos(BuildContext context) {
    return CupertinoButton(
      color: CupertinoColors.destructiveRed,
      child: const Text('Log out'),
      onPressed: () async {
        await bosService.logout();
        if (!context.mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      },
    );
  }

  @override
  Widget build(context) {
    return PlatformWidget(
      androidBuilder: _buildAndroid,
      iosBuilder: _buildIos,
    );
  }
}
