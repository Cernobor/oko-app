import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:latlong2/latlong.dart';
import 'package:oko/data.dart';
import 'package:oko/i18n.dart';

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

String ensureNoTrailingSlash(String baseAddr) => baseAddr.endsWith('/')
    ? baseAddr.substring(0, baseAddr.length - 1)
    : baseAddr;

String ensureTrailingSlash(String baseAddr) =>
    baseAddr.endsWith('/') ? baseAddr : (baseAddr + '/');

Uri _handshakeUri(String baseAddr) =>
    Uri.parse(ensureTrailingSlash(baseAddr)).resolve('handshake');

Uri _pingUri(String baseAddr) =>
    Uri.parse(ensureTrailingSlash(baseAddr)).resolve('ping');

Uri _dataUri(String baseAddr) =>
    Uri.parse(ensureTrailingSlash(baseAddr)).resolve('data');

Uri _mapPackUri(String baseAddr) =>
    Uri.parse(ensureTrailingSlash(baseAddr)).resolve('mappack');

Future<void> _downloadFile(Uri uri, File dest,
    {void Function(http.Request req)? prepareRequest,
    void Function(int read, int? total)? onProgress}) async {
  http.Request req = http.Request('GET', uri);
  if (prepareRequest != null) {
    prepareRequest(req);
  }
  var res = await req.send();
  if (res.statusCode >= 500) {
    throw InternalServerError(await res.stream.bytesToString());
  }
  if (res.statusCode != HttpStatus.ok) {
    throw UnexpectedStatusCode(
        res.statusCode, await res.stream.bytesToString());
  }

  var ioSink = dest.openWrite();
  int received = 0;
  if (onProgress != null) {
    await res.stream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (data, sink) {
      received += data.length;
      developer.log(
          'Chunk: ${data.length}; Received: $received/${res.contentLength}');
      onProgress(received, res.contentLength);
      sink.add(data);
    })).pipe(ioSink);
  } else {
    await res.stream.pipe(ioSink);
  }
  return;
}

Future<ServerSettings> handshake(
    String serverAddress, String name, bool exists) async {
  Uri uri = _handshakeUri(serverAddress);
  developer.log('Handshaking: $uri');
  var res = await http.post(uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'exists': exists}));
  var body = res.body;
  switch (res.statusCode) {
    case HttpStatus.ok:
      break;
    case HttpStatus.badRequest:
      throw BadRequest(body);
    case HttpStatus.conflict:
      throw UserAlreadyExists(name);
    case HttpStatus.notFound:
      throw UserDoesNotExist(name);
    case HttpStatus.forbidden:
      throw UsernameForbidden(name);
    default:
      throw InternalServerError(body);
  }
  Map<String, dynamic> data = jsonDecode(body);
  return ServerSettings(
    serverAddress: serverAddress,
    name: data['name'],
    id: data['id'],
    mapPackPath: data['map_info']['map_pack_path'],
    mapPackSize: data['map_info']['map_pack_size'],
    tilePathTemplate: data['map_info']['tile_path_template'],
    minZoom: data['map_info']['min_zoom'],
    defaultCenter: LatLng(
        (data['map_info']['default_center']['lat'] as num).toDouble(),
        (data['map_info']['default_center']['lng'] as num).toDouble()),
  );
}

Future<bool> ping(String serverAddress) async {
  var uri = _pingUri(serverAddress);
  try {
    var res = await http.get(uri);
    return res.statusCode == HttpStatus.noContent;
  } catch (_) {
    return false;
  }
}

class StreamData {
  int? contentLength;
  http.ByteStream dataStream;

  StreamData(this.contentLength, this.dataStream);
}

Future<void> downloadMap(String serverAddress, File dest,
    void Function(int read, int? total) onProgress) async {
  Uri uri = _mapPackUri(serverAddress);
  return _downloadFile(uri, dest, onProgress: onProgress);
}

Future<ServerData> downloadData(String serverAddress) async {
  Uri uri = _dataUri(serverAddress);
  var res = await http.get(uri, headers: {'Accept': 'application/json'});
  var body = res.body;
  if (res.statusCode != HttpStatus.ok) {
    throw UnexpectedStatusCode(res.statusCode, body);
  }
  Map<String, dynamic> data = jsonDecode(body);
  return ServerData(data);
}

Future<void> downloadDataWithPhotos(String serverAddress, File dest,
    void Function(int read, int? total) onProgress) async {
  Uri uri = _dataUri(serverAddress);
  return _downloadFile(uri, dest, prepareRequest: (req) {
    req.headers['Accept'] = 'application/zip';
  }, onProgress: onProgress);
}

Future<void> uploadData(
    {required String serverAddress,
    required List<Feature> created,
    required List<Feature> edited,
    required List<Feature> deleted,
    Map<int, List<FeaturePhoto>> createdPhotos = const {},
    Map<int, List<FeaturePhoto>> addedPhotos = const {},
    List<int> deletedPhotoIDs = const []}) async {
  var uri = _dataUri(serverAddress);
  Map<String, FeaturePhoto> photos = {};
  Map<String, List<String>> createdNames = {};
  for (var entry in createdPhotos.entries) {
    for (var photo in entry.value) {
      String name = 'img${photo.id}';
      photos[name] = photo;
      createdNames[entry.key.toString()] ??= [];
      createdNames[entry.key.toString()]!.add(name);
    }
  }
  Map<String, List<String>> addedNames = {};
  for (var entry in addedPhotos.entries) {
    for (var photo in entry.value) {
      String name = 'img${photo.id}';
      photos[name] = photo;
      addedNames[entry.key.toString()] ??= [];
      addedNames[entry.key.toString()]!.add(name);
    }
  }
  Map<String, dynamic> data = {
    'create': created.map((Feature f) => f.toJson()).toList(growable: false),
    'created_photos': createdNames,
    'add_photos': addedNames,
    'update': edited.map((Feature f) => f.toJson()).toList(growable: false),
    'delete': deleted.map((Feature f) => f.id).toList(growable: false),
    'delete_photos': deletedPhotoIDs
  };

  var req = http.MultipartRequest('POST', uri);
  req.fields['data'] = jsonEncode(data);
  for (var entry in photos.entries) {
    req.files.add(http.MultipartFile(
        'thumb_${entry.key}',
        Stream.value(await entry.value.thumbnailData),
        (await entry.value.thumbnailData).length,
        filename: 'thumb_${entry.key}',
        contentType: MediaType.parse(entry.value.thumbnailContentType)));
    req.files.add(http.MultipartFile(
        entry.key, entry.value.photoDataStream, entry.value.photoDataSize,
        filename: entry.key,
        contentType: MediaType.parse(entry.value.contentType)));
  }
  var res = await req.send();

  switch (res.statusCode) {
    case HttpStatus.badRequest:
      throw BadRequest(await res.stream.bytesToString());
    case HttpStatus.noContent:
      return;
    default:
      throw InternalServerError(await res.stream.bytesToString());
  }
}
