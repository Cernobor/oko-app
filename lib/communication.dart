import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:oko/data.dart';
import 'package:oko/urls/urls.dart';

UriCreator uriCreator = UriCreator();

class CommException implements Exception {
  final Uri uri;
  final String error;
  final String? errorDetail;

  CommException(this.uri, this.error, [this.errorDetail]);

  @override
  String toString() {
    if (errorDetail != null) {
      return 'CommException{uri: $uri, name: $error, fullError: $errorDetail}';
    }
    return 'CommException{uri: $uri, name: $error}';
  }
}

Future<ServerSettings> handshake(
    String serverAddress, String name, bool exists) async {
  Uri uri = uriCreator.handshakeUri(serverAddress);
  http.Response res;
  try {
    res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'exists': exists}));
  } on Exception catch (e) {
    throw CommException(uri, e.toString());
  }
  switch (res.statusCode) {
    case HttpStatus.ok:
      break;
    case HttpStatus.badRequest:
      throw CommException(uri, 'bad request', res.body);
    case HttpStatus.conflict:
      throw CommException(uri, 'user already exists');
    case HttpStatus.notFound:
      throw CommException(uri, 'user does not exist');
    case HttpStatus.forbidden:
      throw CommException(uri, 'forbidden username');
    default:
      throw CommException(uri, 'internal error', res.body);
  }
  Map<String, dynamic> data = jsonDecode(res.body);
  return ServerSettings(
    serverAddress: serverAddress,
    name: data['name'],
    id: data['id'],
    mapPackPath: data['map_info']['map_pack_path'],
    mapPackSize: data['map_info']['map_pack_size'],
    tilePathTemplate: data['map_info']['tile_path_template'],
    minZoom: data['map_info']['min_zoom'],
    defaultCenter: LatLng(data['map_info']['default_center']['lat'],
        data['map_info']['default_center']['lng']),
  );
}

Future<bool> ping(String serverAddress) async {
  var uri = uriCreator.pingUri(serverAddress);
  http.Response res;
  try {
    res = await http.get(uri);
  } catch (_) {
    return false;
  }
  if (res.statusCode == HttpStatus.noContent) {
    return true;
  }
  return false;
}

class MapData {
  int? contentLength;
  http.ByteStream dataStream;

  MapData(this.contentLength, this.dataStream);
}

Future<MapData> downloadMap(String serverAddress, String tilePackPath) async {
  Uri uri = Uri.http(serverAddress, tilePackPath);
  http.Request req = http.Request('GET', uri);
  http.StreamedResponse res;
  try {
    res = await req.send();
  } on Exception catch (e) {
    throw CommException(uri, e.toString());
  }
  if (res.statusCode != HttpStatus.ok) {
    throw CommException(uri, 'Request refused. Code: ${res.statusCode}');
  }
  return MapData(res.contentLength, res.stream);
}

class Data {
  Map<int, String> users;
  List<Feature> features;

  Data(this.users, this.features);
}

Future<Data> downloadData(String serverAddress) async {
  Uri uri = uriCreator.data(serverAddress);
  http.Response res;
  try {
    res = await http.get(uri);
  } on Exception catch (e) {
    throw CommException(uri, e.toString());
  }
  if (res.statusCode != HttpStatus.ok) {
    throw CommException(uri, 'non-ok status ${res.statusCode}', res.body);
  }
  Map<String, dynamic> data = jsonDecode(res.body);
  Map<int, String> users = HashMap.fromEntries((data['users'] as List)
      .cast<Map<String, dynamic>>()
      .map((m) => MapEntry<int, String>(m['id'], m['name'])));
  List<Feature> features = (data['features'] as List)
      .cast<Map<String, dynamic>>()
      .map((Map<String, dynamic> feature) => Feature.fromJson(feature))
      .toList(growable: false);
  return Data(users, features);
}

Future<void> uploadData(String serverAddress, List<Feature> created,
    List<Feature> edited, List<Feature> deleted) async {
  var uri = uriCreator.data(serverAddress);
  Map<String, dynamic> data = {
    'create': created.map((Feature f) => f.toJson()).toList(growable: false),
    'update': edited.map((Feature f) => f.toJson()).toList(growable: false),
    'delete': deleted.map((Feature f) => f.id).toList(growable: false)
  };
  http.Response res;
  try {
    res = await http.post(uri,
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(data));
  } on Exception catch (e) {
    throw CommException(uri, e.toString());
  }
  switch (res.statusCode) {
    case HttpStatus.badRequest:
      throw CommException(uri, 'bad request', res.body);
    case HttpStatus.noContent:
      return;
    default:
      throw CommException(uri, 'internal error', res.body);
  }
}
/*
Future<List<Geometry>> downloadExtraGeometry(String serverAddress) async {
  var uri = uriCreator.extraGeometry(serverAddress);
  var data = await _handle(uri) as List;
  List<Map<String, dynamic>> castData = data.cast<Map<String, dynamic>>();
  return castData.map((d) => Geometry.fromGeoJson(d)).toList(growable: false);
}
*/
