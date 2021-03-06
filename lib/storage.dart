import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';
import 'package:oko/data.dart';
import 'package:oko/utils.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class Storage {
  static const String _storageDbFile = 'storage.db';
  static const String _featurePhotosDirname = 'feature-photos';
  static const String _mapPackFile = 'map.mbtiles';
  static Storage? _instance;

  //region init
  static Future<String> _storageFilePath() async {
    String databasesPath = await getDatabasesPath();
    return join(databasesPath, _storageDbFile);
  }

  static Future<Storage> getInstance({bool reset = false}) async {
    String path = await _storageFilePath();

    if (reset) {
      if (_instance != null) {
        await _instance!._db.close();
        var dbFile = File(path);
        await dbFile.delete();
        await _instance!._localDir.delete(recursive: true);
        _instance = null;
      }
    }

    if (_instance == null) {
      await Directory(dirname(path)).create(recursive: true);
      Database db = await openDatabase(path,
          version: 1, onConfigure: _onConfigure, onCreate: _onCreate);
      Directory localDir = await getApplicationDocumentsDirectory();
      await localDir.create(recursive: true);
      Storage s = Storage._(db, localDir);

      // load all data
      await s._loadServerSettings();
      await s._loadUsers();
      await s._loadMapState();
      await s._loadPointListSettings();
      await s._loadFeatures();

      _instance = s;
    }
    return _instance!;
  }

  static void _onCreate(Database db, int version) async {
    await db.execute('CREATE TABLE server_settings ('
        'server_address text not null,'
        'name text not null,'
        'id integer not null,'
        'map_pack_path text not null,'
        'map_pack_size integer not null,'
        'tile_path_template text not null,'
        'min_zoom integer not null,'
        'default_center_lat real not null,'
        'default_center_lng real not null)');
    await db.execute('CREATE TABLE map_state ('
        'render integer not null,'
        'using_offline integer not null,'
        'lat real not null,'
        'lng real not null,'
        'zoom integer not null,'
        'lat_ne_bound real,'
        'lng_ne_bound real,'
        'lat_sw_bound real,'
        'lng_sw_bound real,'
        'zoom_min integer,'
        'zoom_max integer)');
    await db.execute('CREATE TABLE point_list_settings ('
        'sort_key text not null,'
        'sort_direction integer not null,'
        'attribute_filter_exact integer not null,'
        'edit_state_filter text not null)');
    await db.insert('point_list_settings', {
      'sort_key': 'name',
      'sort_direction': 1,
      'attribute_filter_exact': 0,
      'edit_state_filter': EditState.anyState.name
    });
    await db.execute('CREATE TABLE point_list_checked_categories ('
        'category text not null)');
    var batch = db.batch();
    for (var cat in PointCategory.allCategories) {
      batch.insert('point_list_checked_categories', {'category': cat.name});
    }
    await batch.commit(noResult: true);
    await db.execute('CREATE TABLE point_list_checked_attributes ('
        'attribute text not null)');
    await db.execute('CREATE TABLE point_list_checked_users ('
        'id integer not null)');
    await db.execute('CREATE TABLE users ('
        'id integer primary key,'
        'name text not null)');
    await db.execute('CREATE TABLE next_local_id ('
        'id integer not null)');
    await db.insert('next_local_id', {'id': -1});
    await db.execute('CREATE TABLE features ('
        'id integer primary key,'
        'data text not null)');
    await db.execute('CREATE TABLE next_local_photo_id ('
        'id integer not null)');
    await db.insert('next_local_photo_id', {'id': -1});
    await db.execute('CREATE TABLE feature_photos ('
        'id integer primary key,'
        'feature_id integer,'
        'thumbnail_content_type text not null,'
        'content_type text not null,'
        'thumbnail blob not null,'
        'photo_file_path blob not null,'
        'photo_size integer not null)');
  }

  static void _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }
  //endregion

  final Database _db;
  final Directory _localDir;

  Storage._(this._db, this._localDir);

  Directory createTempDir() {
    return _localDir.createTempSync();
  }

  //region server settings
  ServerSettings? _serverSettings;
  ServerSettings? get serverSettings => _serverSettings;

  Future<void> setServerSettings(ServerSettings ss) async {
    await _db.transaction((Transaction tx) async {
      await tx.execute('delete from server_settings');
      await tx.insert('server_settings', {
        'server_address': ss.serverAddress,
        'name': ss.name,
        'id': ss.id,
        'map_pack_path': ss.mapPackPath,
        'map_pack_size': ss.mapPackSize,
        'tile_path_template': ss.tilePathTemplate,
        'min_zoom': ss.minZoom,
        'default_center_lat': ss.defaultCenter.latitude,
        'default_center_lng': ss.defaultCenter.longitude
      });
      await _loadServerSettings(tx);
    });
  }

  Future<void> _loadServerSettings([Transaction? tx]) async {
    Future<void> f(Transaction tx) async {
      var rows = await tx.query('server_settings',
          columns: [
            'server_address',
            'name',
            'id',
            'map_pack_path',
            'map_pack_size',
            'tile_path_template',
            'min_zoom',
            'default_center_lat',
            'default_center_lng'
          ],
          limit: 1);
      if (rows.isEmpty) {
        return;
      }
      var row = rows[0];
      _serverSettings = ServerSettings(
          serverAddress: row['server_address']! as String,
          name: row['name']! as String,
          id: row['id']! as int,
          mapPackPath: row['map_pack_path']! as String,
          mapPackSize: row['map_pack_size']! as int,
          tilePathTemplate: row['tile_path_template']! as String,
          minZoom: row['min_zoom']! as int,
          defaultCenter: LatLng(row['default_center_lat']! as double,
              row['default_center_lng']! as double));
    }

    if (tx == null) {
      await _db.transaction(f);
    } else {
      await f(tx);
    }
  }
  //endregion

  //region map state
  MapState? _mapState;
  MapState? get mapState => _mapState;
  File get offlineMap {
    return File(join(_localDir.path, _mapPackFile));
  }

  Future<void> setMapState(MapState ms) async {
    await _db.transaction((Transaction tx) async {
      await tx.execute('delete from map_state');
      await tx.insert('map_state', {
        'render': ms.render ? 1 : 0,
        'using_offline': ms.usingOffline ? 1 : 0,
        'lat': ms.center.latitude,
        'lng': ms.center.longitude,
        'zoom': ms.zoom,
        'lat_ne_bound': ms.neBound?.latitude,
        'lng_ne_bound': ms.neBound?.longitude,
        'lat_sw_bound': ms.swBound?.latitude,
        'lng_sw_bound': ms.swBound?.longitude,
        'zoom_max': ms.zoomMax
      });
      await _loadMapState(tx);
    });
  }

  Future<void> _loadMapState([Transaction? tx]) async {
    Future<void> f(Transaction tx) async {
      var rows = await tx.query('map_state',
          columns: [
            'render',
            'using_offline',
            'lat',
            'lng',
            'zoom',
            'lat_ne_bound',
            'lng_ne_bound',
            'lat_sw_bound',
            'lng_sw_bound',
            'zoom_min',
            'zoom_max'
          ],
          limit: 1);
      if (rows.isEmpty) {
        return;
      }
      var row = rows[0];
      _mapState = MapState(
        row['render'] != 0,
        row['using_offline'] != 0,
        LatLng(row['lat']! as double, row['lng']! as double),
        row['zoom']! as int,
        row['lat_ne_bound'] != null && row['lng_ne_bound'] != null
            ? LatLng(
                row['lat_ne_bound']! as double, row['lng_ne_bound']! as double)
            : null,
        row['lat_sw_bound'] != null && row['lng_sw_bound'] != null
            ? LatLng(
                row['lat_sw_bound']! as double, row['lng_sw_bound']! as double)
            : null,
        row['zoom_max'] == null ? null : row['zoom_max']! as int,
      );
    }

    if (tx == null) {
      await _db.transaction(f);
    } else {
      await f(tx);
    }
  }
  //endregion

  //region point list sorts and filters
  late Sort _pointListSortKey;
  late int _pointListSortDir;
  late bool _pointListAttributeFilterExact;
  late EditState _pointListEditStateFilter;
  final Set<int> _pointListCheckedUsers = {};
  final Set<PointCategory> _pointListCheckedCategories = {};
  final Set<PointAttribute> _pointListCheckedAttributes = {};
  Sort get pointListSortKey => _pointListSortKey;
  int get pointListSortDir => _pointListSortDir;
  bool get pointListAttributeFilterExact => _pointListAttributeFilterExact;
  EditState get pointListEditStateFilter => _pointListEditStateFilter;
  UnmodifiableSetView<int> get pointListCheckedUsers =>
      UnmodifiableSetView(_pointListCheckedUsers);
  UnmodifiableSetView<PointCategory> get pointListCheckedCategories =>
      UnmodifiableSetView(_pointListCheckedCategories);
  UnmodifiableSetView<PointAttribute> get pointListCheckedAttributes =>
      UnmodifiableSetView(_pointListCheckedAttributes);

  Future<void> setPointListSortKey(Sort sort) async {
    _pointListSortKey = sort;
    await _db.update('point_list_settings', {'sort_key': sort.name()});
  }

  Future<void> setPointListSortDir(int dir) async {
    _pointListSortDir = dir;
    await _db.update('point_list_settings', {'sort_direction': dir});
  }

  Future<void> setPointListAttributeFilterExact(bool exact) async {
    _pointListAttributeFilterExact = exact;
    await _db.update(
        'point_list_settings', {'attribute_filter_exact': exact ? 1 : 0});
  }

  Future<void> setPointListEditStateFilter(EditState editState) async {
    _pointListEditStateFilter = editState;
    await _db
        .update('point_list_settings', {'edit_state_filter': editState.name});
  }

  Future<void> setPointListCheckedUsers(Iterable<int> userIds) async {
    await _db.transaction((Transaction tx) async {
      await tx.execute('delete from point_list_checked_users');
      var batch = tx.batch();
      for (var id in userIds) {
        batch.insert('point_list_checked_users', {'id': id});
      }
      await batch.commit(noResult: true);
      await _loadPointListSettings(tx);
    });
  }

  Future<void> setPointListCheckedCategories(
      Iterable<PointCategory> categories) async {
    await _db.transaction((Transaction tx) async {
      await tx.execute('delete from point_list_checked_categories');
      var batch = tx.batch();
      for (var cat in categories) {
        batch.insert('point_list_checked_categories', {'category': cat.name});
      }
      await batch.commit(noResult: true);
      await _loadPointListSettings(tx);
    });
  }

  Future<void> setPointListCheckedAttributes(
      Iterable<PointAttribute> attributes) async {
    await _db.transaction((Transaction tx) async {
      await tx.execute('delete from point_list_checked_attributes');
      var batch = tx.batch();
      for (var attr in attributes) {
        batch.insert('point_list_checked_attributes', {'attribute': attr.name});
      }
      await batch.commit(noResult: true);
      await _loadPointListSettings(tx);
    });
  }

  Future<void> _loadPointListSettings([Transaction? txn]) async {
    Future<void> f(Transaction tx) async {
      var rows = await tx.query('point_list_settings',
          columns: [
            'sort_key',
            'sort_direction',
            'attribute_filter_exact',
            'edit_state_filter'
          ],
          limit: 1);
      for (var row in rows) {
        _pointListSortKey = SortExt.parse(row['sort_key'] as String);
        _pointListSortDir = row['sort_direction'] as int;
        _pointListAttributeFilterExact = row['attribute_filter_exact'] != 0;
        _pointListEditStateFilter =
            parseEditState(row['edit_state_filter'] as String);
      }

      rows = await tx
          .query('point_list_checked_categories', columns: ['category']);
      _pointListCheckedCategories.clear();
      for (var row in rows) {
        _pointListCheckedCategories
            .add(PointCategory.fromNameString(row['category'] as String));
      }

      rows = await tx
          .query('point_list_checked_attributes', columns: ['attribute']);
      _pointListCheckedAttributes.clear();
      for (var row in rows) {
        _pointListCheckedAttributes
            .add(PointAttribute.fromNameString(row['attribute'] as String));
      }

      rows = await tx.query('point_list_checked_users', columns: ['id']);
      _pointListCheckedUsers.clear();
      for (var row in rows) {
        _pointListCheckedUsers.add(row['id'] as int);
      }
    }

    if (txn == null) {
      await _db.transaction(f);
    } else {
      await f(txn);
    }
  }
  //endregion

  //region users
  final Users _users = HashMap();
  UsersView get users => UnmodifiableMapView(_users);

  Future<void> setUsers(Users users) async {
    await _db.transaction((Transaction tx) async {
      await tx.execute('delete from users');
      Batch batch = tx.batch();
      users.forEach((id, name) {
        batch.insert('users', {'id': id, 'name': name});
      });
      await batch.commit(noResult: true);
      await _loadUsers(tx);
    });
  }

  Future<void> _loadUsers([Transaction? tx]) async {
    var rows = await (tx ?? _db).query('users', columns: ['id', 'name']);
    _users.clear();
    for (var row in rows) {
      _users[row['id']! as int] = row['name']! as String;
    }
  }
  //endregion

  //region next local id
  Future<int> nextLocalId() async {
    return await _db.transaction((Transaction tx) async {
      await tx.execute('update next_local_id set id = id - 1');
      var row = await tx.query('next_local_id', columns: ['id'], limit: 1);
      return row[0]['id'] as int;
    });
  }
  //endregion

  //region features
  final List<Feature> _features = List.empty(growable: true);
  final Map<int, Feature> _featuresMap = HashMap();
  FeaturesView get features => UnmodifiableListView(_features);
  FeaturesMapView get featuresMap => UnmodifiableMapView(_featuresMap);

  Future<void> setFeatures(List<Feature> features) async {
    await _db.transaction((Transaction tx) async {
      await tx.execute('delete from features');
      Batch batch = tx.batch();
      for (var feature in features) {
        batch.insert(
            'features', {'id': feature.id, 'data': jsonEncode(feature)});
      }
      await batch.commit(noResult: true);
      await _loadFeatures(tx);
    });
  }

  Future<void> upsertFeature(Feature feature) async {
    await _db.transaction((Transaction tx) async {
      await tx.insert(
          'features', {'id': feature.id, 'data': jsonEncode(feature)},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await _loadFeatures(tx);
    });
  }

  Future<void> removeFeature(int id) async {
    await _db.transaction((Transaction tx) async {
      await tx.delete('features', where: 'id = ?', whereArgs: [id]);
      await _loadFeatures(tx);
    });
  }

  Future<void> _loadFeatures([Transaction? tx]) async {
    var rows = await (tx ?? _db).query('features', columns: ['id', 'data']);
    _features.clear();
    _featuresMap.clear();
    for (var row in rows) {
      int id = row['id'] as int;
      String data = row['data'] as String;
      Map<String, dynamic> json = jsonDecode(data);
      Feature f = Feature.fromJson(json, false);
      if (id != f.id) {
        throw IllegalStateException(
            'feature id $id does not match its data id ${f.id}');
      }
      _features.add(f);
      _featuresMap[f.id] = f;
    }
  }
  //endregion

  //region feature photos
  Future<void> setPhotos(
      Iterable<FeaturePhoto> photos, Iterable<int> keep) async {
    await _db.transaction((Transaction tx) async {
      await tx
          .execute('create table _tmp_keep_photos (id integer primary key)');
      var batch = tx.batch();
      for (var id in keep) {
        batch.insert('_tmp_keep_photos', {'id': id});
      }
      await batch.commit(noResult: true);

      var rows = await tx.rawQuery('select fp.photo_file_path as pfp '
          'from feature_photos fp '
          'left join _tmp_keep_photos tkp '
          'on fp.id = tkp.id '
          'where tkp.id is null');
      for (var row in rows) {
        String filename = _fullPhotoFileName(row['pfp'] as String);
        File(filename).deleteSync();
      }

      await tx.rawDelete(
          'delete from feature_photos where id in (select fp.id as fpid from feature_photos fp left join _tmp_keep_photos tkp on fp.id = tkp.id where tkp.id is null)');
      await tx.execute('drop table _tmp_keep_photos');

      batch = tx.batch();
      for (var photo in photos) {
        String photoFileName =
            await _writePhoto(photo.id, await photo.photoData);
        batch.insert('feature_photos', {
          'id': photo.id,
          'feature_id': photo.featureID,
          'thumbnail_content_type': photo.thumbnailContentType,
          'content_type': photo.contentType,
          'thumbnail': await photo.thumbnailData,
          'photo_file_path': photoFileName,
          'photo_size': photo.photoDataSize
        });
      }
      await batch.commit();
    });
  }

  String _fullPhotoFileName(String photoBasename) =>
      join(_localDir.path, _featurePhotosDirname, photoBasename);

  ThumbnailMemoryPhotoFileFeaturePhoto _rowToPhoto(Map<String, Object?> row) {
    return ThumbnailMemoryPhotoFileFeaturePhoto(row['thumbnail'] as Uint8List,
        File(_fullPhotoFileName(row['photo_file_path'] as String)),
        id: row['id'] as int,
        featureID: row['feature_id'] as int,
        thumbnailContentType: row['thumbnail_content_type'] as String,
        contentType: row['content_type'] as String,
        photoDataSize: row['photo_size'] as int);
  }

  Future<List<ThumbnailMemoryPhotoFileFeaturePhoto>> getPhotos(
      int featureID) async {
    var rows = await _db.query('feature_photos',
        columns: [
          'id',
          'feature_id',
          'thumbnail_content_type',
          'content_type',
          'thumbnail',
          'photo_file_path',
          'photo_size'
        ],
        where: 'feature_id = ?',
        whereArgs: [featureID]);
    return rows.map((e) => _rowToPhoto(e)).toList(growable: false);
  }

  Future<List<FeaturePhoto>> getPhotosByID(Iterable<int> photoIDs) async {
    Set<int> ids = photoIDs.toSet();
    return await _db.transaction((Transaction tx) async {
      List<Map<String, Object?>> rows = [];
      for (var id in ids) {
        var rs = await tx.query('feature_photos',
            columns: [
              'id',
              'feature_id',
              'thumbnail_content_type',
              'content_type',
              'thumbnail',
              'photo_file_path',
              'photo_size'
            ],
            where: 'id = ?',
            whereArgs: [id]);
        rows.addAll(rs);
      }
      return rows.map((e) => _rowToPhoto(e)).toList(growable: false);
    });
  }

  Future<int> addPhoto(int featureID, String thumbnailContentType,
      String contentType, Uint8List thumbnail, Uint8List photo) async {
    int photoID = await _db.transaction((Transaction tx) async {
      await tx.execute('update next_local_photo_id set id = id - 1');
      var row =
          await tx.query('next_local_photo_id', columns: ['id'], limit: 1);
      int id = row[0]['id'] as int;
      String photoFileName = await _writePhoto(id, photo);
      await tx.insert('feature_photos', {
        'id': id,
        'feature_id': featureID,
        'thumbnail_content_type': thumbnailContentType,
        'content_type': contentType,
        'thumbnail': thumbnail,
        'photo_file_path': photoFileName,
        'photo_size': photo.length
      });
      return id;
    });
    return photoID;
  }

  Future<void> deletePhoto(int photoID) async {
    await _db.delete('feature_photos', where: 'id = ?', whereArgs: [photoID]);
    File photoFile = await _getPhotoFile(photoID);
    await photoFile.delete();
  }

  Future<void> deletePhotos(Set<int> photoIDs) async {
    await _db.transaction((Transaction tx) async {
      var batch = tx.batch();
      for (var id in photoIDs) {
        batch.delete('feature_photos', where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
      for (var id in photoIDs) {
        File photoFile = await _getPhotoFile(id);
        await photoFile.delete();
      }
    });
  }

  Future<File> _getPhotoFile(int photoID) async {
    String photoFileName = join(_featurePhotosDirname, 'P$photoID');
    Directory photoDir =
        Directory(dirname(join(_localDir.path, photoFileName)));
    await photoDir.create(recursive: true);
    return File(join(_localDir.path, photoFileName));
  }

  Future<String> _writePhoto(int featureID, Uint8List bytes) async {
    File photoFile = await _getPhotoFile(featureID);
    await photoFile.writeAsBytes(bytes, flush: true);
    return photoFile.path;
  }
  //endregion
}
