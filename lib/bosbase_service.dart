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
  // Superuser (仅用于初始化)
  // =====================
  Future<void> authSuperuser(String email, String password) async {
    await pb.admins.authWithPassword(email, password);
  }

  // 初始化集合与访问规则（需 superuser）
  Future<void> initializeSchemaWithSuperuser(String email, String password) async {
    await authSuperuser(email, password);
    // 仅初始化业务表，不处理系统 users 表
    // 如果 songs 已存在，仅在需要时更新字段与规则；不存在则创建
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
            'name': 'owner',
            'type': 'relation',
            'options': {'collectionId': 'users'},
            'required': true,
            'maxSelect': 1,
          },
        ],
        'listRule': 'owner = @request.auth.id',
        'viewRule': 'owner = @request.auth.id',
        'createRule': '@request.auth.id != ""',
        'updateRule': 'owner = @request.auth.id',
        'deleteRule': 'owner = @request.auth.id',
      });
      return;
    }

    // 已存在：仅校正 owner 字段的 options 以及规则
    final fields = (songs!.fields as List)
        .map((f) => Map<String, dynamic>.from((f as dynamic).toJson()))
        .toList();
    final ownerIndex = fields.indexWhere((f) => f['name'] == 'owner');
    if (ownerIndex == -1) {
      fields.add({
        'name': 'owner',
        'type': 'relation',
        'options': {'collectionId': 'users'},
        'required': true,
        'maxSelect': 1,
      });
    } else {
      final f = Map<String, dynamic>.from(fields[ownerIndex]);
      final opts = Map<String, dynamic>.from((f['options'] ?? {}) as Map);
      opts['collectionId'] = 'users';
      f.remove('collectionId'); // 纠正旧结构
      f['options'] = opts;
      f['type'] = 'relation';
      f['required'] = true;
      f['maxSelect'] = 1;
      fields[ownerIndex] = f;
    }

    await pb.collections.update('songs', body: {
      'fields': fields,
      'listRule': 'owner = @request.auth.id',
      'viewRule': 'owner = @request.auth.id',
      'createRule': '@request.auth.id != ""',
      'updateRule': 'owner = @request.auth.id',
      'deleteRule': 'owner = @request.auth.id',
    });
  }

  Future<List<RecordModel>> listSongs() async {
    // Expand owner to access creator's email in UI
    return await pb.collection('songs').getFullList(
      sort: '-created',
      expand: 'owner',
    );
  }

  Future<RecordModel> addSong(String name, {String? artist}) async {
    // 当未指定 artist 时，默认使用当前登录用户的邮箱
    final defaultArtist = pb.authStore.record?.getStringValue('email');
    final effectiveArtist = (artist != null && artist.isNotEmpty)
        ? artist
        : (defaultArtist?.isNotEmpty == true ? defaultArtist : null);

    final body = {
      'name': name,
      if (effectiveArtist != null) 'artist': effectiveArtist,
      if (pb.authStore.record?.id != null) 'owner': pb.authStore.record!.id,
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
  // 普通用户认证与注册
  // =====================
  bool get isAuthenticated => pb.authStore.isValid;
  RecordModel? get currentUser => pb.authStore.record;
  String? get currentUserEmail => pb.authStore.record?.getStringValue('email');

  Future<RecordAuth> authUser(String email, String password) async {
    final auth = await pb.collection('users').authWithPassword(email, password);
    // 登录成功后持久化凭据（用于下次自动登录）
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
  // 用户头像上传/更新
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
      // 注意：AuthStore.record 仅提供 getter，没有公开的 setter；
      // 这里直接返回服务端返回的最新用户记录，交由调用方刷新界面。
      return updated;
    } on ClientException catch (e) {
      // 若因缺少 avatar 字段导致 400，尝试自动创建该字段后重试
      if (e.statusCode == 400) {
        try {
          await ensureUserAvatarField();
          final updated = await pb.collection('users').update(
            user.id,
            files: [
              http.MultipartFile.fromBytes('avatar', bytes, filename: filename),
            ],
          );
          // 同上：返回最新记录供调用方使用
          return updated;
        } catch (_) {
          rethrow;
        }
      }
      rethrow;
    }
  }

  /// 获取当前用户头像的访问 URL（如果存在）
  String? currentUserAvatarUrl({String? thumb}) {
    final user = pb.authStore.record;
    if (user == null) return null;
    final filename = user.getStringValue('avatar');
    if (filename == null || filename.isEmpty) return null;
    return pb.files.getURL(user, filename, thumb: thumb).toString();
  }

  /// 根据任意用户记录获取头像 URL（用于更新后立即刷新 UI）
  String? avatarUrlFor(RecordModel record, {String? thumb}) {
    final filename = record.getStringValue('avatar');
    if (filename == null || filename.isEmpty) return null;
    return pb.files.getURL(record, filename, thumb: thumb).toString();
  }

  /// 确保 users 集合存在单文件头像字段 avatar
  Future<void> ensureUserAvatarField() async {
    await authSuperuser(AppConfig.adminEmail, AppConfig.adminPassword);
    CollectionModel users;
    try {
      users = await pb.collections.getOne('users');
    } finally {
      // 不持久保持管理员登录
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
  // 本地持久化与自动登录
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

  /// 尝试使用本地存储的登录信息自动登录。
  /// 返回 true 表示已登录；返回 false 表示未登录或失败。
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
      // 自动登录失败，清除脏数据以防止下次继续失败
      await _clearStoredCredentials();
      return false;
    }
  }
}

// 共享实例，供全局使用
final BosbaseService bosService = BosbaseService(endpoint: AppConfig.endpoint);