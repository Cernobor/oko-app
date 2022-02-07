import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:oko/data.dart';
import 'package:oko/i18n.dart';
import 'package:oko/urls/urls.dart';

UriCreator uriCreator = UriCreator();

abstract class CommException implements Exception {
  String getMessage(BuildContext context);
}

abstract class DetailedCommException implements Exception {
  final String detail;

  DetailedCommException(this.detail);

  String getMessage(BuildContext context);
}

class UserAlreadyExists extends CommException {
  final String user;
  UserAlreadyExists(this.user);

  @override
  String getMessage(BuildContext context) {
    return I18N.of(context).userAlreadyExists(user);
  }
}

class UserDoesNotExist extends CommException {
  final String user;
  UserDoesNotExist(this.user);

  @override
  String getMessage(BuildContext context) {
    return I18N.of(context).userDoesNotExist(user);
  }
}

class BadRequest extends DetailedCommException {
  BadRequest(String detail) : super(detail);

  @override
  String getMessage(BuildContext context) {
    return I18N.of(context).badRequest;
  }
}

class RequestRefused extends CommException {
  final int code;

  RequestRefused(this.code);

  @override
  String getMessage(BuildContext context) {
    return I18N.of(context).requestRefused;
  }
}

class UsernameForbidden extends CommException {
  final String username;
  UsernameForbidden(this.username);

  @override
  String getMessage(BuildContext context) {
    return I18N.of(context).usernameForbidden(username);
  }
}

class InternalServerError extends DetailedCommException {
  InternalServerError(String detail) : super(detail);

  @override
  String getMessage(BuildContext context) {
    return I18N.of(context).internalServerError;
  }
}

class UnexpectedStatusCode extends DetailedCommException {
  final int code;

  UnexpectedStatusCode(this.code, String detail) : super(detail);

  @override
  String getMessage(BuildContext context) {
    return I18N.of(context).unexpectedStatusCode(code);
  }
}

Future<ServerSettings> handshake(
    String serverAddress, String name, bool exists) async {
  Uri uri = uriCreator.handshakeUri(serverAddress);
  http.Response res;
  res = await http.post(uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'exists': exists}));
  switch (res.statusCode) {
    case HttpStatus.ok:
      break;
    case HttpStatus.badRequest:
      throw BadRequest(res.body);
    case HttpStatus.conflict:
      throw UserAlreadyExists(name);
    case HttpStatus.notFound:
      throw UserDoesNotExist(name);
    case HttpStatus.forbidden:
      throw UsernameForbidden(name);
    default:
      throw InternalServerError(res.body);
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
  res = await req.send();
  if (res.statusCode != HttpStatus.ok) {
    throw RequestRefused(res.statusCode);
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
  res = await http.get(uri);
  if (res.statusCode != HttpStatus.ok) {
    throw UnexpectedStatusCode(res.statusCode, res.body);
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
  res = await http.post(uri,
      headers: {'Content-Type': 'application/json'}, body: jsonEncode(data));
  switch (res.statusCode) {
    case HttpStatus.badRequest:
      throw BadRequest(res.body);
    case HttpStatus.noContent:
      return;
    default:
      throw InternalServerError(res.body);
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
