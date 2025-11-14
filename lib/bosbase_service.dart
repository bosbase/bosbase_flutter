import 'package:bosbase/bosbase.dart';
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
    final body = {
      'name': name,
      if (artist != null && artist.isNotEmpty) 'artist': artist,
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

  Future<RecordAuth> authUser(String email, String password) async {
    final auth = await pb.collection('users').authWithPassword(email, password);
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
  }
}

// 共享实例，供全局使用
final BosbaseService bosService = BosbaseService(endpoint: AppConfig.endpoint);