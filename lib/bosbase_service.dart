import 'package:bosbase/bosbase.dart';

class BosbaseService {
  final String endpoint;
  late final Bosbase pb;

  BosbaseService({required this.endpoint}) {
    final baseUrl = endpoint.endsWith('/')
        ? endpoint.substring(0, endpoint.length - 1)
        : endpoint;
    pb = Bosbase(baseUrl);
  }

  Future<void> authSuperuser(String email, String password) async {
    await pb.admins.authWithPassword(email, password);
  }

  Future<void> ensureSongsCollection() async {
    try {
      await pb.collections.getOne('songs');
    } catch (_) {
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
        ]
      });
    }
  }

  Future<List<RecordModel>> listSongs() async {
    return await pb.collection('songs').getFullList(sort: '-created');
  }

  Future<RecordModel> addSong(String name, {String? artist}) async {
    final record = await pb.collection('songs').create(body: {
      'name': name,
      if (artist != null && artist.isNotEmpty) 'artist': artist,
    });
    return record;
  }

  Future<void> deleteSong(String id) async {
    await pb.collection('songs').delete(id);
  }
}