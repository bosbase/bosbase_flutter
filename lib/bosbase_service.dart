import 'package:bosbase/bosbase.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class BosbaseService {
  final String endpoint;
  late final Bosbase pb;

  BosbaseService({required this.endpoint}) {
    final baseUrl = endpoint.endsWith('/')
        ? endpoint.substring(0, endpoint.length - 1)
        : endpoint;
    pb = Bosbase(baseUrl);
  }

  // =====================
  // Superuser (only for initialization)
  // =====================
  Future<void> authSuperuser(String email, String password) async {
    await pb.admins.authWithPassword(email, password);
  }

  // Initialize collection and access rules (requires superuser)
  Future<void> initializeSchemaWithSuperuser(String email, String password) async {
    await authSuperuser(email, password);
    // Only initialize business tables, do not handle system users table
    // If songs already exists, only update fields and rules when needed; if not, create it
    bool exists = true;
    CollectionModel? songs;
    try {
      songs = await pb.collections.getOne('songs');
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        exists = false;
      } else {
        rethrow;
      }
    }

    if (!exists) {
      await pb.collections.createBase('songs', overrides: {
        'fields': [
          {
            'name': 'name',
            'type': 'text',
            'required': true,
          },
          {
            'name': 'artist',
            'type': 'text',
            'required': false,
          },
          {
            'name': 'createBy',
            'type': 'relation',
            'options': {'collectionId': 'users'},
            'required': true,
            'maxSelect': 1,
          },
        ],
        'listRule': 'createBy = @request.auth.id',
        'viewRule': 'createBy = @request.auth.id',
        'createRule': '@request.auth.id != ""',
        'updateRule': 'createBy = @request.auth.id',
        'deleteRule': 'createBy = @request.auth.id',
      });
      return;
    }

    // Already exists: only correct the owner field's options and rules
    final fields = (songs!.fields as List)
        .map((f) => Map<String, dynamic>.from((f as dynamic).toJson()))
        .toList();
    final ownerIndex = fields.indexWhere((f) => f['name'] == 'createBy');
    if (ownerIndex == -1) {
      fields.add({
        'name': 'createBy',
        'type': 'relation',
        'options': {'collectionId': 'users'},
        'required': true,
        'maxSelect': 1,
      });
    } else {
      final f = Map<String, dynamic>.from(fields[ownerIndex]);
      final opts = Map<String, dynamic>.from((f['options'] ?? {}) as Map);
      opts['collectionId'] = 'users';
      f.remove('collectionId'); // Correct old structure
      f['options'] = opts;
      f['type'] = 'relation';
      f['required'] = true;
      f['maxSelect'] = 1;
      fields[ownerIndex] = f;
    }

    await pb.collections.update('songs', body: {
      'fields': fields,
      'listRule': 'createBy = @request.auth.id',
      'viewRule': 'createBy = @request.auth.id',
      'createRule': '@request.auth.id != ""',
      'updateRule': 'createBy = @request.auth.id',
      'deleteRule': 'createBy = @request.auth.id',
    });
  }

  Future<List<RecordModel>> listSongs() async {
    // Only list in reverse order by creation time, no expansion needed (use createdBy system field to determine owner)
    return await pb.collection('songs').getFullList(
      sort: '-created',
    );
  }

  Future<RecordModel> addSong(String name, {String? artist}) async {
    // When artist is not specified, use current logged-in user's email by default
    final defaultArtist = pb.authStore.record?.getStringValue('email');
    final effectiveArtist = (artist != null && artist.isNotEmpty)
        ? artist
        : (defaultArtist?.isNotEmpty == true ? defaultArtist : null);

    final body = {
      'name': name,
      if (effectiveArtist != null) 'artist': effectiveArtist,
      // createdBy is automatically recorded by backend, no need for client to set
    };
    final record = await pb.collection('songs').create(body: body);
    return record;
  }

  Future<void> deleteSong(String id) async {
    await pb.collection('songs').delete(id);
  }

  Future<RecordModel> updateSong(
    String id, {
    String? name,
    String? artist,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (artist != null) body['artist'] = artist;
    final updated = await pb.collection('songs').update(id, body: body);
    return updated;
  }

  // =====================
  // General user authentication and registration
  // =====================
  bool get isAuthenticated => pb.authStore.isValid;
  RecordModel? get currentUser => pb.authStore.record;
  String? get currentUserEmail => pb.authStore.record?.getStringValue('email');

  Future<RecordAuth> authUser(String email, String password) async {
    final auth = await pb.collection('users').authWithPassword(email, password);
    // Persist credentials after successful login (for next automatic login)
    await _persistCredentials(email, password);
    return auth;
  }

  Future<RecordModel> registerUser({
    required String email,
    required String password,
    String? name,
  }) async {
    final rec = await pb.collection('users').create(body: {
      'email': email,
      'password': password,
      'passwordConfirm': password,
      if (name != null && name.isNotEmpty) 'name': name,
    });
    return rec;
  }

  Future<void> logout() async {
    pb.authStore.clear();
    await _clearStoredCredentials();
  }

  // =====================
  // User avatar upload/update
  // =====================
  Future<RecordModel> updateCurrentUserAvatarBytes({
    required String filename,
    required List<int> bytes,
  }) async {
    final user = pb.authStore.record;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    try {
      final updated = await pb.collection('users').update(
        user.id,
        files: [
          http.MultipartFile.fromBytes('avatar', bytes, filename: filename),
        ],
      );
      // Note: AuthStore.record only provides getter, no public setter;
      // Here directly return the latest user record from server, let caller refresh UI.
      return updated;
    } on ClientException catch (e) {
      // If 400 caused by missing avatar field, try to auto-create field and retry
      if (e.statusCode == 400) {
        try {
          await ensureUserAvatarField();
          final updated = await pb.collection('users').update(
            user.id,
            files: [
              http.MultipartFile.fromBytes('avatar', bytes, filename: filename),
            ],
          );
          // Same as above: return latest record for caller to use
          return updated;
        } catch (_) {
          rethrow;
        }
      }
      rethrow;
    }
  }

  /// Get access URL of current user's avatar (if exists)
  String? currentUserAvatarUrl({String? thumb}) {
    final user = pb.authStore.record;
    if (user == null) return null;
    final filename = user.getStringValue('avatar');
    if (filename == null || filename.isEmpty) return null;
    return pb.files.getURL(user, filename, thumb: thumb).toString();
  }

  /// Get avatar URL from any user record (used to immediately refresh UI after update)
  String? avatarUrlFor(RecordModel record, {String? thumb}) {
    final filename = record.getStringValue('avatar');
    if (filename == null || filename.isEmpty) return null;
    return pb.files.getURL(record, filename, thumb: thumb).toString();
  }

  /// Ensure users collection has single-file avatar field
  Future<void> ensureUserAvatarField() async {
    await authSuperuser(AppConfig.adminEmail, AppConfig.adminPassword);
    CollectionModel users;
    try {
      users = await pb.collections.getOne('users');
    } finally {
      // Do not persistently keep admin login
    }
    final fields = (users.fields as List)
        .map((f) => Map<String, dynamic>.from((f as dynamic).toJson()))
        .toList();
    final idx = fields.indexWhere((f) => f['name'] == 'avatar');
    if (idx == -1) {
      fields.add({
        'name': 'avatar',
        'type': 'file',
        'maxSelect': 1,
        'mimeTypes': ['image/jpeg', 'image/png', 'image/webp'],
        'thumbs': ['100x100', '300x300'],
        'protected': false,
      });
      await pb.collections.update('users', body: {
        'fields': fields,
      });
    }
  }

  // =====================
  // Local persistence and automatic login
  // =====================
  Future<void> _persistCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_email', email);
    await prefs.setString('auth_password', password);
  }

  Future<void> _clearStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_email');
    await prefs.remove('auth_password');
  }

  /// Try to auto-login using locally stored login info.
  /// Return true if logged in; return false if not logged in or failed.
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('auth_email');
    final password = prefs.getString('auth_password');
    if ((email == null || email.isEmpty) || (password == null || password.isEmpty)) {
      return false;
    }
    try {
      await pb.collection('users').authWithPassword(email, password);
      return pb.authStore.isValid;
    } catch (_) {
      // Auto login failed, clear dirty data to prevent next failure
      await _clearStoredCredentials();
      return false;
    }
  }
}

// Shared instance for global use
final BosbaseService bosService = BosbaseService(endpoint: AppConfig.endpoint);