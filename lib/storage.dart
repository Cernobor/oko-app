import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:latlong2/latlong.dart';
import 'package:oko/data.dart';
import 'package:oko/utils.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// ignore: unused_element
Future<String> get _localPath async {
  final dir = await getApplicationDocumentsDirectory();
  return dir.path;
}

class Storage {
  static const String _storageDbFile = 'storage.db';
  static Storage? _instance;

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
        _instance = null;
      }
    }

    if (_instance == null) {
      await Directory(dirname(path)).create(recursive: true);
      Database db = await openDatabase(path,
          version: 1, onConfigure: _onConfigure, onCreate: _onCreate);
      Storage s = Storage._(db);

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
        'attribute_filter_exact integer not null)');
    await db.insert('point_list_settings',
        {'sort_key': 'name', 'sort_direction': 1, 'attribute_filter_exact': 0});
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
        'owner_id integer,'
        'orig_owner_id integer,'
        'name text not null,'
        'orig_name text not null,'
        'description text,'
        'orig_description text,'
        'point_category text,'
        'orig_point_category text,'
        'attributes text,'
        'orig_attributes text,'
        'geom text not null,'
        'orig_geom text not null,'
        'deleted integer not null)');
  }

  static void _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  final Database _db;

  Storage._(this._db);

  // server settings
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

  // map state
  MapState? _mapState;
  MapState? get mapState => _mapState;

  Future<void> setMapState(MapState ms) async {
    if (_mapState != null &&
        _mapState!.render == ms.render &&
        _mapState!.center == ms.center &&
        _mapState!.zoom == ms.zoom) {
      return;
    }
    _mapState = ms;
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
    });
  }

  Future<void> _loadMapState() async {
    var rows = await _db.query('map_state',
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

  // point list sorts and filters
  late Sort _pointListSortKey;
  late int _pointListSortDir;
  late bool _pointListAttributeFilterExact;
  final Set<int> _pointListCheckedUsers = {};
  final Set<PointCategory> _pointListCheckedCategories = {};
  final Set<PointAttribute> _pointListCheckedAttributes = {};
  Sort get pointListSortKey => _pointListSortKey;
  int get pointListSortDir => _pointListSortDir;
  bool get pointListAttributeFilterExact => _pointListAttributeFilterExact;
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
    await _db.update('point_list_settings', {'attribute_filter_exact': exact ? 1 : 0});
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
      var rows =
          await tx.query('point_list_settings', columns: ['sort_key', 'sort_direction', 'attribute_filter_exact'], limit: 1);
      for (var row in rows) {
        _pointListSortKey = SortExt.parse(row['sort_key'] as String);
        _pointListSortDir = row['sort_direction'] as int;
        _pointListAttributeFilterExact = row['attribute_filter_exact'] != 0;
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

  // users
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

  // next local id
  Future<int> nextLocalId() async {
    return await _db.transaction((Transaction tx) async {
      await tx.execute('update next_local_id set id = id - 1');
      var row = await tx.query('next_local_id', columns: ['id'], limit: 1);
      return row[0]['id'] as int;
    });
  }

  // features
  final List<Feature> _features = List.empty(growable: true);
  final Map<int, Feature> _featuresMap = HashMap();
  FeaturesView get features => UnmodifiableListView(_features);
  FeaturesMapView get featuresMap => UnmodifiableMapView(_featuresMap);

  Future<void> setFeatures(List<Feature> features) async {
    await _db.transaction((Transaction tx) async {
      await tx.execute('delete from features');
      Batch batch = tx.batch();
      for (var feature in features) {
        batch.insert('features', feature.toDbEntry());
      }
      await batch.commit(noResult: true);
      await _loadFeatures(tx);
    });
  }

  Future<void> upsertFeature(Feature feature) async {
    await _db.transaction((Transaction tx) async {
      await tx.insert('features', feature.toDbEntry(),
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
    var rows = await (tx ?? _db).query('features', columns: [
      'id',
      'owner_id',
      'orig_owner_id',
      'name',
      'orig_name',
      'description',
      'orig_description',
      'point_category',
      'orig_point_category',
      'attributes',
      'orig_attributes',
      'geom',
      'orig_geom',
      'deleted'
    ]);
    _features.clear();
    _featuresMap.clear();
    for (var row in rows) {
      int id = row['id'] as int;
      int ownerId = row['owner_id'] as int;
      int origOwnerId = row['orig_owner_id'] as int;
      String name = row['name'] as String;
      String origName = row['orig_name'] as String;
      String? description = row['description'] as String?;
      String? origDescription = row['orig_description'] as String?;
      String? pointCategory = row['point_category'] as String?;
      String? origPointCategory = row['orig_point_category'] as String?;
      String attributes = (row['attributes'] ?? '[]') as String;
      String origAttributes = (row['orig_attributes'] ?? '[]') as String;
      String geom = row['geom'] as String;
      String origGeom = row['orig_geom'] as String;
      int deleted = row['deleted'] as int;

      List<dynamic> parsedAttributes = jsonDecode(attributes);
      List<dynamic> parsedOrigAttributes = jsonDecode(origAttributes);
      Map<String, dynamic> parsedGeom = jsonDecode(geom);
      Map<String, dynamic> parsedOrigGeom = jsonDecode(origGeom);
      Feature f;
      if (Feature.isGeojsonPoint(parsedGeom)) {
        PointCategory cat = PointCategory.fromNameString(pointCategory);
        PointCategory origCat = PointCategory.fromNameString(origPointCategory);
        Set<PointAttribute> attrs = parsedAttributes
            .map((attr) => PointAttribute.fromNameString(attr))
            .toSet();
        Set<PointAttribute> origAttrs = parsedOrigAttributes
            .map((attr) => PointAttribute.fromNameString(attr))
            .toSet();
        f = Point.fromGeojson(
            id,
            ownerId,
            origOwnerId,
            name,
            origName,
            description,
            origDescription,
            cat,
            origCat,
            attrs,
            origAttrs,
            deleted != 0,
            parsedGeom,
            parsedOrigGeom);
      } else if (Feature.isGeojsonLineString(parsedGeom)) {
        f = LineString.fromGeojson(
            id,
            ownerId,
            origOwnerId,
            name,
            origName,
            description,
            origDescription,
            deleted != 0,
            parsedGeom,
            parsedOrigGeom);
      } else {
        developer.log('Unsupported geometry type (id=$id).');
        continue;
      }
      _features.add(f);
      _featuresMap[f.id] = f;
    }
  }
}
