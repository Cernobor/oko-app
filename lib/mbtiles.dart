import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
import 'package:vector_map_tiles/src/provider_exception.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

class MbtilesTileProvider extends VectorTileProvider {
  final Database _db;
  final int _maximumZoom;
  static final GZipCodec _codec = GZipCodec();

  MbtilesTileProvider._(this._db, this._maximumZoom);

  static Future<MbtilesTileProvider> create(
      int maximumZoom, String mbtilesPath) async {
    Database db = await openDatabase(mbtilesPath, readOnly: true);
    return MbtilesTileProvider._(db, maximumZoom);
  }

  Future<void> destroy() {
    return _db.close();
  }

  @override
  int get maximumZoom => _maximumZoom;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    // flip y to match the spec
    var y = (1 << tile.z) - 1 - tile.y;
    var rows = await _db.query('tiles',
        columns: ['tile_data'],
        where: 'zoom_level = ? and tile_column = ? and tile_row = ?',
        whereArgs: [tile.z, tile.x, y]);
    if (rows.isEmpty) {
      throw ProviderException(
          message: 'Tile $tile not found.',
          statusCode: 404,
          retryable: Retryable.none);
    }
    if (rows.length > 1) {
      throw ProviderException(
          message: 'Multiple tiles for $tile found.',
          statusCode: 400,
          retryable: Retryable.none);
    }

    var t = rows[0]['tile_data'] as Uint8List;

    // ungzip
    var t2 = _codec.decode(t);
    t = (t2 is Uint8List) ? t2 : Uint8List.fromList(t2);
    return t;
  }
}
