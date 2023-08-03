import 'dart:developer' as developer;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:oko/utils.dart';
import 'package:oko/constants.dart' as constants;

class ServerSettings {
  final String serverAddress;
  final String name;
  final int id;
  final String mapPackPath;
  final int mapPackSize;
  final String tilePathTemplate;
  final int minZoom;
  final LatLng defaultCenter;

  ServerSettings(
      {required this.serverAddress,
      required this.name,
      required this.id,
      required this.mapPackPath,
      required this.mapPackSize,
      required this.tilePathTemplate,
      required this.minZoom,
      required this.defaultCenter});

  @override
  String toString() {
    return 'ServerSettings{serverAddress: $serverAddress, name: $name, id: $id, mapPackPath: $mapPackPath, mapPackSize: $mapPackSize, tilePathTemplate: $tilePathTemplate, minZoom: $minZoom, defaultCenter: $defaultCenter}';
  }
}

class MapState {
  final bool render;
  final bool usingOffline;
  final LatLng center;
  final int zoom;
  final LatLng? neBound;
  final LatLng? swBound;
  final int? zoomMax;

  MapState(this.render, this.usingOffline, this.center, this.zoom, this.neBound,
      this.swBound, this.zoomMax);

  MapState from(
      {bool? render,
      bool? usingOffline,
      LatLng? center,
      int? zoom,
      LatLng? neBound,
      LatLng? swBound,
      int? zoomMax}) {
    return MapState(
        render ?? this.render,
        usingOffline ?? this.usingOffline,
        center ?? this.center,
        zoom ?? this.zoom,
        neBound ?? this.neBound,
        swBound ?? this.swBound,
        zoomMax ?? this.zoomMax);
  }

  bool get hasPanLimits => neBound != null && swBound != null;

  @override
  String toString() {
    return 'MapState{render: $render, usingOffline: $usingOffline, center: $center, zoom: $zoom, neBound: $neBound, swBound: $swBound, zoomMax: $zoomMax}';
  }
}

class ServerData {
  final Map<int, String> users;
  final List<Feature> features;
  final Map<String, PhotoMetadata> photoMetadata;
  final List<Proposal> proposals;

  ServerData._(this.users, this.features, this.photoMetadata, this.proposals);

  factory ServerData(Map<String, dynamic> data) {
    Map<int, String> users = Map.fromEntries((data['users'] as List)
        .cast<Map<String, dynamic>>()
        .map((m) => MapEntry<int, String>(m['id'], m['name'])));
    List<Feature> features = (data['features'] as List)
        .cast<Map<String, dynamic>>()
        .map((Map<String, dynamic> feature) => Feature.fromJson(feature, true))
        .toList(growable: false);
    Map<String, PhotoMetadata> photoMetadata =
        (data['photo_metadata'] as Map?)?.map((key, value) {
              return MapEntry(
                  key as String,
                  PhotoMetadata._(
                      value['thumbnail_content_type'] as String,
                      value['content_type'] as String,
                      value['size'] as int,
                      value['id'] as int,
                      value['thumbnail_filename'] as String));
            }) ??
            {};
    List<Proposal> proposals = (data['proposals'] as List)
        .cast<Map<String, dynamic>>()
        .map((Map<String, dynamic> proposal) => Proposal(
            proposal['owner_id'] as int,
            proposal['description'] as String,
            proposal['how'] as String))
        .toList(growable: false);
    return ServerData._(users, features, photoMetadata, proposals);
  }
}

class PhotoMetadata {
  final String thumbnailContentType;
  final String contentType;
  final int size;
  final int id;
  final String thumbnailFilename;

  PhotoMetadata._(this.thumbnailContentType, this.contentType, this.size,
      this.id, this.thumbnailFilename);
}

class PointCategory implements Comparable {
  static const PointCategory general =
      PointCategory._(0, 'general', Icons.place, .5, .075);
  static const PointCategory camp =
      PointCategory._(1, 'camp', Icons.deck, .5, .075);
  static const PointCategory animal =
      PointCategory._(2, 'animal', Icons.pets, .5, .5);
  static const PointCategory holySite =
      PointCategory._(3, 'holy_site', Icons.brightness_medium, .5, .5);
  static const PointCategory treasure =
      PointCategory._(4, 'treasure', Icons.vpn_key, .5, .5);
  static const PointCategory unknown =
      PointCategory._(1000000000, 'unknown', Icons.live_help, .5, .5);

  static final List<PointCategory> defaultCategories = [
    general,
    camp,
    animal,
    holySite,
    treasure
  ];
  static final List<PointCategory> allCategories =
      defaultCategories + [unknown];

  static PointCategory fromNameString(String? s) {
    if (s == general.name) {
      return general;
    } else if (s == camp.name) {
      return camp;
    } else if (s == animal.name) {
      return animal;
    } else if (s == holySite.name) {
      return holySite;
    } else if (s == treasure.name) {
      return treasure;
    } else {
      return unknown;
    }
  }

  final int _key;
  final String name;
  final IconData iconData;
  final double xAlign;
  final double yAlign;

  const PointCategory._(
      this._key, this.name, this.iconData, this.xAlign, this.yAlign);

  @override
  String toString() {
    return 'PointCategory{$name}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PointCategory &&
          runtimeType == other.runtimeType &&
          _key == other._key;

  @override
  int get hashCode => _key.hashCode;

  @override
  int compareTo(other) {
    if (other is! PointCategory) {
      return -1;
    }
    return _key.compareTo(other._key);
  }

  AnchorPos anchorPos(double w, double h) =>
      AnchorPos.exactly(Anchor(w * xAlign, h * yAlign));

  Alignment rotationAlignment() => Alignment(-2 * xAlign + 1, -2 * yAlign + 1);
}

class PointAttribute implements Comparable {
  static const PointAttribute important = PointAttribute._(
      0, 'important', Icons.warning, -1, -1, Color(0xffff0000));
  static const PointAttribute cleaned = PointAttribute._(
      1, 'cleaned', Icons.cleaning_services, -1, 0, Color(0xff00ff0f));

  static final List<PointAttribute> attributes = [important, cleaned];

  static PointAttribute fromNameString(String? s) {
    if (s == important.name) {
      return important;
    } else if (s == cleaned.name) {
      return cleaned;
    } else {
      throw IllegalStateException('unsupported attribute name');
    }
  }

  final int _key;
  final String name;
  final IconData iconData;
  final double xAlign;
  final double yAlign;
  final Color color;

  const PointAttribute._(this._key, this.name, this.iconData, this.xAlign,
      this.yAlign, this.color);

  @override
  String toString() {
    return 'PointAttribute{$name}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PointAttribute &&
          runtimeType == other.runtimeType &&
          _key == other._key;

  @override
  int get hashCode => _key.hashCode;

  @override
  int compareTo(other) {
    if (other is! PointCategory) {
      return -1;
    }
    return _key.compareTo(other._key);
  }

  Alignment badgeAlignment() => Alignment(xAlign, yAlign);
}

enum EditState {
  anyState,
  pristineState,
  newState,
  editedState,
  deletedState,
  editedDeletedState
}

final UnmodifiableMapView<String, EditState> _editStateParsingMap =
    UnmodifiableMapView({for (var t in EditState.values) t.name: t});

EditState parseEditState(String str) {
  return _editStateParsingMap[str]!;
}

enum FeatureType { point, polyline, polygon }

final UnmodifiableMapView<String, FeatureType> _featureTypeParsingMap =
    UnmodifiableMapView({for (var t in FeatureType.values) t.name: t});

FeatureType parseFeatureType(String s) {
  return _featureTypeParsingMap[s]!;
}

abstract class Feature {
  int id;
  int ownerId;
  int origOwnerId;
  String name;
  String origName;
  DateTime? deadline;
  DateTime? origDeadline;
  String? description;
  String? origDescription;
  Color color;
  Color origColor;
  Set<int> photoIDs;
  Set<int> origPhotoIDs;

  bool deleted;

  Feature._(
      this.id,
      this.ownerId,
      this.origOwnerId,
      this.name,
      this.origName,
      this.deadline,
      this.origDeadline,
      this.description,
      this.origDescription,
      this.color,
      this.origColor,
      this.photoIDs,
      this.origPhotoIDs,
      this.deleted);

  factory Feature.fromJson(Map<String, dynamic> json, bool origFromCurrent) {
    int id = json['id'];
    int ownerId = json['owner_id'];
    int origOwnerId = json['orig_owner_id'] ?? ownerId;
    String name = json['name'];
    String origName = json['orig_name'] ?? name;
    Map<String, dynamic> geometry = json['geometry'];
    Map<String, dynamic> origGeometry = json['orig_geometry'] ?? geometry;
    String? deadlineValue = json['deadline'];
    DateTime? deadline;
    if (deadlineValue != null) {
      deadline = DateTime.parse(deadlineValue);
    }
    String? origDeadlineValue = json['orig_deadline'];
    DateTime? origDeadline;
    if (origDeadlineValue != null) {
      origDeadline = DateTime.parse(origDeadlineValue);
    } else if (origFromCurrent) {
      origDeadline = deadline;
    }
    List<dynamic> photoIDsList = json['photo_ids'] ?? [];
    Set<int> photoIDs = photoIDsList.map((e) => e as int).toSet();
    List<dynamic> origPhotoIDsList =
        json['orig_photo_ids'] ?? (origFromCurrent ? photoIDsList : []);
    Set<int> origPhotoIDs = origPhotoIDsList.map((e) => e as int).toSet();
    bool deleted = json['deleted'] ?? false;

    Map<String, dynamic> properties = json['properties'];
    String? description = properties['description'];
    int? colorValue = properties['color'];

    Map<String, dynamic> origProperties = json['orig_properties'] ?? {};
    String? origDescription =
        origProperties['description'] ?? (origFromCurrent ? description : null);
    int? origColorValue =
        origProperties['color'] ?? (origFromCurrent ? colorValue : null);

    if (Feature.isGeojsonPoint(geometry)) {
      Color color = colorValue == null ? Point.defaultColor : Color(colorValue);
      Color origColor =
          origColorValue == null ? Point.defaultColor : Color(origColorValue);
      String? category = properties['category'];
      PointCategory cat = PointCategory.fromNameString(category);
      String? origCategory =
          origProperties['category'] ?? (origFromCurrent ? category : null);
      PointCategory origCat = PointCategory.fromNameString(origCategory);
      List<dynamic> attrList = properties['attributes'] ?? [];
      Set<PointAttribute> attributes = attrList
          .map((e) => e as String)
          .map((String attrName) => PointAttribute.fromNameString(attrName))
          .toSet();
      List<dynamic> origAttrList =
          origProperties['attributes'] ?? (origFromCurrent ? attrList : []);
      Set<PointAttribute> origAttributes = origAttrList
          .map((e) => e as String)
          .map((String attrName) => PointAttribute.fromNameString(attrName))
          .toSet();
      return Point.fromGeojson(
          id,
          ownerId,
          origOwnerId,
          name,
          origName,
          deadline,
          origDeadline,
          description,
          origDescription,
          color,
          origColor,
          photoIDs,
          origPhotoIDs,
          cat,
          origCat,
          attributes,
          origAttributes,
          deleted,
          geometry,
          origGeometry);
    } else if (Feature.isGeojsonPoly(geometry)) {
      Color color = colorValue == null
          ? constants.palette[constants.defaultPolyStrokeColorIndex]
          : Color(colorValue);
      Color origColor = origColorValue == null
          ? constants.palette[constants.defaultPolyStrokeColorIndex]
          : Color(origColorValue);
      Color? colorFill = colorValue == null ? null : Color(colorValue);
      Color? origColorFill =
          origColorValue == null ? null : Color(origColorValue);
      return Poly.fromGeojson(
          id,
          ownerId,
          origOwnerId,
          name,
          origName,
          deadline,
          origDeadline,
          description,
          origDescription,
          color,
          origColor,
          colorFill,
          origColorFill,
          photoIDs,
          origPhotoIDs,
          deleted,
          geometry,
          origGeometry);
    }
    throw Exception('unsupported geometry type');
  }

  static bool isGeojsonPoint(Map<String, dynamic> geojson) {
    return geojson['type'] == 'Point';
  }

  static bool isGeojsonPoly(Map<String, dynamic> geojson) {
    return geojson['type'] == 'LineString' || geojson['type'] == 'Polygon';
  }

  bool isPoint();

  Point asPoint();

  bool isPoly();

  Poly asPoly();

  bool get isEdited =>
      ownerId != origOwnerId ||
      name != origName ||
      description != origDescription ||
      color.value != origColor.value ||
      (deadline == null && origDeadline != null) ||
      (deadline != null && origDeadline == null) ||
      (deadline != null &&
          origDeadline != null &&
          !deadline!.isAtSameMomentAs(origDeadline!)) ||
      !setEquals(photoIDs, origPhotoIDs);

  void revert() {
    ownerId = origOwnerId;
    name = origName;
    deadline = origDeadline;
    description = origDescription;
    color = origColor;
    photoIDs = origPhotoIDs;
  }

  bool get isLocal => id < 0;

  bool get isNotLocal => !isLocal;

  bool get isSystem => ownerId == 0;

  bool get isLocked => isNotLocal && isSystem;

  bool get isNotLocked => !isLocked;

  @mustCallSuper
  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'orig_owner_id': origOwnerId,
        'name': name,
        'orig_name': origName,
        if (deadline != null) 'deadline': deadline!.toUtc().toIso8601String(),
        if (origDeadline != null)
          'orig_deadline': origDeadline!.toUtc().toIso8601String(),
        'photo_ids': photoIDs.toList(growable: false),
        'orig_photo_ids': origPhotoIDs.toList(growable: false),
        'properties': {
          if (description != null) 'description': description,
          'color': color.value,
        },
        'orig_properties': {
          if (origDescription != null) 'description': origDescription,
          'color': origColor.value
        },
        'deleted': deleted
      };

  Feature copy();

  LatLng center();
}

class Point extends Feature {
  static final Color defaultColor = Colors.blue.shade500;

  LatLng coords;
  LatLng origCoords;
  PointCategory category;
  PointCategory origCategory;
  Set<PointAttribute> attributes;
  Set<PointAttribute> origAttributes;

  Point(
      int id,
      int ownerId,
      int origOwnerId,
      String name,
      String origName,
      DateTime? deadline,
      DateTime? origDeadline,
      String? description,
      String? origDescription,
      Color color,
      Color origColor,
      Set<int> photoIDs,
      Set<int> origPhotoIDs,
      this.coords,
      this.origCoords,
      this.category,
      this.origCategory,
      this.attributes,
      this.origAttributes,
      deleted)
      : super._(
            id,
            ownerId,
            origOwnerId,
            name,
            origName,
            deadline,
            origDeadline,
            description,
            origDescription,
            color,
            origColor,
            photoIDs,
            origPhotoIDs,
            deleted);

  Point.origSame(
      int id,
      int ownerId,
      String name,
      DateTime? deadline,
      String? description,
      Color color,
      Set<int> photoIDs,
      LatLng coords,
      PointCategory category,
      Set<PointAttribute> attributes,
      bool deleted)
      : this(
            id,
            ownerId,
            ownerId,
            name,
            name,
            deadline,
            deadline,
            description,
            description,
            color,
            color,
            photoIDs,
            Set.of(photoIDs),
            coords,
            coords,
            category,
            category,
            attributes,
            Set.of(attributes),
            deleted);

  factory Point.fromGeojson(
      int id,
      int ownerId,
      int origOwnerId,
      String name,
      String origName,
      DateTime? deadline,
      DateTime? origDeadline,
      String? description,
      String? origDescription,
      Color color,
      Color origColor,
      Set<int> photoIDs,
      Set<int> origPhotoIDs,
      PointCategory category,
      PointCategory origCategory,
      Set<PointAttribute> attributes,
      Set<PointAttribute> origAttributes,
      bool deleted,
      Map<String, dynamic> geom,
      Map<String, dynamic> origGeom) {
    assert(geom['type'] == 'Point');
    assert(origGeom['type'] == 'Point');

    return Point(
        id,
        ownerId,
        origOwnerId,
        name,
        origName,
        deadline,
        origDeadline,
        description,
        origDescription,
        color,
        origColor,
        photoIDs,
        origPhotoIDs,
        LatLng(geom['coordinates'][1], geom['coordinates'][0]),
        LatLng(origGeom['coordinates'][1], origGeom['coordinates'][0]),
        category,
        origCategory,
        attributes,
        origAttributes,
        deleted);
  }

  Point.from(Point other,
      {int? id,
      int? ownerId,
      int? origOwnerId,
      String? name,
      String? origName,
      DateTime? deadline,
      DateTime? origDeadline,
      String? description,
      String? origDescription,
      Color? color,
      Color? origColor,
      Set<int>? photoIDs,
      Set<int>? origPhotoIDs,
      LatLng? coords,
      LatLng? origCoords,
      PointCategory? category,
      PointCategory? origCategory,
      Set<PointAttribute>? attributes,
      Set<PointAttribute>? origAttributes,
      bool? deleted})
      : this(
            id ?? other.id,
            ownerId ?? other.ownerId,
            origOwnerId ?? other.origOwnerId,
            name ?? other.name,
            origName ?? other.origName,
            deadline ?? other.deadline,
            origDeadline ?? other.origDeadline,
            description ?? other.description,
            origDescription ?? other.origDescription,
            color ?? other.color,
            origColor ?? other.origColor,
            photoIDs ?? other.photoIDs,
            origPhotoIDs ?? other.origPhotoIDs,
            coords ?? other.coords,
            origCoords ?? other.origCoords,
            category ?? other.category,
            origCategory ?? other.origCategory,
            attributes ?? other.attributes,
            origAttributes ?? other.origAttributes,
            deleted ?? other.deleted);

  @override
  bool isPoint() {
    return true;
  }

  @override
  Point asPoint() => this;

  @override
  bool isPoly() {
    return false;
  }

  @override
  Poly asPoly() {
    throw IllegalStateException('not a Poly');
  }

  @override
  bool get isEdited =>
      super.isEdited ||
      coords != origCoords ||
      category != origCategory ||
      !setEquals(attributes, origAttributes);

  @override
  void revert() {
    super.revert();
    category = origCategory;
    coords = origCoords;
    attributes = origAttributes;
  }

  Map<String, dynamic> _geometry() => {
        'type': 'Point',
        'coordinates': [coords.longitude, coords.latitude]
      };

  Map<String, dynamic> _origGeometry() => {
        'type': 'Point',
        'coordinates': [origCoords.longitude, origCoords.latitude]
      };

  @override
  Map<String, dynamic> toJson() {
    var js = super.toJson();
    js['properties'].addAll({
      'category': category.name,
      'attributes': attributes.map((attr) => attr.name).toList(growable: false),
    });
    js['orig_properties'].addAll({
      'category': origCategory.name,
      'attributes':
          origAttributes.map((attr) => attr.name).toList(growable: false),
    });
    js.addAll({'geometry': _geometry(), 'orig_geometry': _origGeometry()});
    return js;
  }

  @override
  Point copy() {
    return Point(
        id,
        ownerId,
        origOwnerId,
        name,
        origName,
        deadline,
        origDeadline,
        description,
        origDescription,
        color,
        origColor,
        Set.of(photoIDs),
        Set.of(origPhotoIDs),
        LatLng(coords.latitude, coords.longitude),
        LatLng(origCoords.latitude, origCoords.longitude),
        category,
        origCategory,
        Set.of(attributes),
        Set.of(origAttributes),
        deleted);
  }

  @override
  LatLng center() => coords;
}

class Poly extends Feature {
  final List<LatLng> _coords;
  final List<LatLng> _origCoords;
  final bool polygon;
  final bool origPolygon;
  final Color? colorFill;
  final Color? origColorFill;
  LatLng _centroid;
  final LatLng origCentroid;

  List<LatLng> get coords => UnmodifiableListView(_coords);

  List<LatLng> get origCoords => UnmodifiableListView(_origCoords);

  LatLng get centroid => _centroid;

  Poly(
      int id,
      int ownerId,
      int origOwnerId,
      String name,
      String origName,
      DateTime? deadline,
      DateTime? origDeadline,
      String? description,
      String? origDescription,
      Color color,
      Color origColor,
      this.colorFill,
      this.origColorFill,
      Set<int> photoIDs,
      Set<int> origPhotoIDs,
      List<LatLng> coords,
      List<LatLng> origCoords,
      this.polygon,
      this.origPolygon,
      bool deleted)
      : _coords = coords,
        _origCoords = origCoords,
        _centroid = geodesy.findPolygonCentroid(coords),
        origCentroid = geodesy.findPolygonCentroid(origCoords),
        super._(
            id,
            ownerId,
            origOwnerId,
            name,
            origName,
            deadline,
            origDeadline,
            description,
            origDescription,
            color,
            origColor,
            photoIDs,
            origPhotoIDs,
            deleted);

  Poly.origSame(
      int id,
      int ownerId,
      String name,
      DateTime? deadline,
      String? description,
      Color color,
      Color? colorFill,
      Set<int> photoIDs,
      List<LatLng> coords,
      bool polygon,
      bool deleted)
      : this(
            id,
            ownerId,
            ownerId,
            name,
            name,
            deadline,
            deadline,
            description,
            description,
            color,
            color,
            colorFill,
            colorFill,
            photoIDs,
            Set.of(photoIDs),
            coords,
            List.of(coords),
            polygon,
            polygon,
            deleted);

  factory Poly.fromGeojson(
      int id,
      int ownerId,
      int origOwnerId,
      String name,
      String origName,
      DateTime? deadline,
      DateTime? origDeadline,
      String? description,
      String? origDescription,
      Color color,
      Color origColor,
      Color? colorFill,
      Color? origColorFill,
      Set<int> photoIDs,
      Set<int> origPhotoIDs,
      bool deleted,
      Map<String, dynamic> geom,
      Map<String, dynamic> origGeom) {
    var type = geom['type'];
    var origType = origGeom['type'];
    assert(type == 'LineString' || type == 'Polygon');
    assert(origType == 'LineString' || origType == 'Polygon');

    developer.log("coords: ${geom['coordinates']}");
    List<List<double>> coords = [];
    if (type == 'Polygon') {
      List<List<List<double>>> tmpCoords =
          (geom['coordinates'] as List<dynamic>)
              .cast<List<dynamic>>()
              .map((e) =>
                  e.cast<List<dynamic>>().map((e) => e.cast<double>()).toList())
              .toList();
      assert(tmpCoords.length == 1);
      assert(tmpCoords[0].first.equals(tmpCoords[0].last));
      coords = tmpCoords[0];
      coords.length = coords.length - 1;
    } else if (type == 'LineString') {
      coords = (geom['coordinates'] as List<dynamic>)
          .cast<List<dynamic>>()
          .map((e) => e.cast<double>())
          .toList();
    }

    List<List<double>> origCoords = [];
    if (origType == 'Polygon') {
      List<List<List<double>>> tmpCoords =
          (origGeom['coordinates'] as List<dynamic>)
              .cast<List<dynamic>>()
              .map((e) =>
                  e.cast<List<dynamic>>().map((e) => e.cast<double>()).toList())
              .toList();
      assert(tmpCoords.length == 1);
      assert(tmpCoords[0].first.equals(tmpCoords[0].last));
      origCoords = tmpCoords[0];
      origCoords.length = origCoords.length - 1;
    } else if (origType == 'LineString') {
      origCoords = (origGeom['coordinates'] as List<dynamic>)
          .cast<List<dynamic>>()
          .map((e) => e.cast<double>())
          .toList();
    }
    return Poly(
        id,
        ownerId,
        origOwnerId,
        name,
        origName,
        deadline,
        origDeadline,
        description,
        origDescription,
        color,
        origColor,
        colorFill,
        origColorFill,
        photoIDs,
        origPhotoIDs,
        coords
            .map((List<double> c) => LatLng(c[1], c[0]))
            .toList(growable: false),
        origCoords
            .map((List<double> c) => LatLng(c[1], c[0]))
            .toList(growable: false),
        type == 'Polygon',
        origType == 'Polygon',
        deleted);
  }

  Poly.from(Poly other,
      {int? id,
      int? ownerId,
      int? origOwnerId,
      String? name,
      String? origName,
      DateTime? deadline,
      DateTime? origDeadline,
      String? description,
      String? origDescription,
      Color? color,
      Color? origColor,
      Color? colorFill,
      Color? origColorFill,
      Set<int>? photoIDs,
      Set<int>? origPhotoIDs,
      List<LatLng>? coords,
      List<LatLng>? origCoords,
      bool? polygon,
      bool? origPolygon,
      bool? deleted})
      : this(
            id ?? other.id,
            ownerId ?? other.ownerId,
            origOwnerId ?? other.origOwnerId,
            name ?? other.name,
            origName ?? other.origName,
            deadline ?? other.deadline,
            origDeadline ?? other.origDeadline,
            description ?? other.description,
            origDescription ?? other.origDescription,
            color ?? other.color,
            origColor ?? other.origColor,
            colorFill ?? other.colorFill,
            origColorFill ?? other.origColorFill,
            photoIDs ?? other.photoIDs,
            origPhotoIDs ?? other.origPhotoIDs,
            coords ?? other._coords,
            origCoords ?? other._origCoords,
            polygon ?? other.polygon,
            origPolygon ?? other.origPolygon,
            deleted ?? other.deleted);

  @override
  bool isPoint() {
    return false;
  }

  @override
  Point asPoint() {
    throw IllegalStateException('not a Point');
  }

  @override
  bool isPoly() {
    return true;
  }

  @override
  Poly asPoly() => this;

  @override
  bool get isEdited =>
      super.isEdited ||
      !const IterableEquality().equals(_coords, _origCoords) ||
      colorFill != origColorFill ||
      polygon != origPolygon;

  @override
  void revert() {
    super.revert();
    _coords.replaceRange(0, _coords.length, _origCoords);
    _centroid = origCentroid;
  }

  Map<String, dynamic> _geometry() {
    if (polygon) {
      return {
        'type': 'Polygon',
        'coordinates': [
          (_coords + [_coords.first])
              .map((LatLng c) => [c.longitude, c.latitude])
              .toList(growable: false)
        ]
      };
    } else {
      return {
        'type': 'LineString',
        'coordinates': _coords
            .map((LatLng c) => [c.longitude, c.latitude])
            .toList(growable: false)
      };
    }
  }

  Map<String, dynamic> _origGeometry() {
    if (polygon) {
      return {
        'type': 'Polygon',
        'coordinates': [
          (_origCoords + [_origCoords.first])
              .map((LatLng c) => [c.longitude, c.latitude])
              .toList(growable: false)
        ]
      };
    } else {
      return {
        'type': 'LineString',
        'coordinates': _origCoords
            .map((LatLng c) => [c.longitude, c.latitude])
            .toList(growable: false)
      };
    }
  }

  @override
  Map<String, dynamic> toJson() {
    var js = super.toJson();
    js.addAll({'geometry': _geometry(), 'orig_geometry': _origGeometry()});
    return js;
  }

  @override
  Poly copy() {
    return Poly(
        id,
        ownerId,
        origOwnerId,
        name,
        origName,
        deadline,
        origDeadline,
        description,
        origDescription,
        color,
        origColor,
        colorFill,
        origColorFill,
        Set.of(photoIDs),
        Set.of(origPhotoIDs),
        List.of(_coords),
        List.of(_origCoords),
        polygon,
        origPolygon,
        deleted);
  }

  @override
  LatLng center() => centroid;
}

abstract class FeaturePhoto implements Comparable<FeaturePhoto> {
  final int id;
  final int featureID;
  final String thumbnailContentType;
  final String contentType;
  final int photoDataSize;

  FeaturePhoto(this.id, this.featureID, this.thumbnailContentType,
      this.contentType, this.photoDataSize);

  Future<Uint8List> get thumbnailData;

  Stream<List<int>> get thumbnailDataStream;

  Future<Uint8List> get photoData;

  Stream<List<int>> get photoDataStream;

  bool get isLocal => id < 0;

  @override
  int compareTo(FeaturePhoto other) {
    if (isLocal && other.isLocal) {
      return -id.compareTo(other.id);
    }
    if (isLocal && !other.isLocal) {
      return 1;
    }
    if (!isLocal && other.isLocal) {
      return -1;
    }
    return id.compareTo(other.id);
  }
}

class FileFeaturePhoto extends FeaturePhoto {
  final File _thumbnailFile;
  final File _photoFile;

  FileFeaturePhoto(this._thumbnailFile, this._photoFile,
      {required int id,
      required int featureID,
      required String thumbnailContentType,
      required String contentType,
      required int photoDataSize})
      : super(id, featureID, thumbnailContentType, contentType, photoDataSize);

  @override
  Future<Uint8List> get thumbnailData => _thumbnailFile.readAsBytes();

  @override
  Stream<List<int>> get thumbnailDataStream => _thumbnailFile.openRead();

  @override
  Future<Uint8List> get photoData => _photoFile.readAsBytes();

  @override
  Stream<List<int>> get photoDataStream => _photoFile.openRead();
}

class MemoryFeaturePhoto extends FeaturePhoto {
  final Uint8List _thumbnailData;
  final Uint8List _photoData;

  MemoryFeaturePhoto(this._photoData, this._thumbnailData,
      {required int id,
      required int featureID,
      required String thumbnailContentType,
      required String contentType,
      required Uint8List thumbnail})
      : super(id, featureID, thumbnailContentType, contentType,
            _photoData.length);

  @override
  Future<Uint8List> get thumbnailData => Future.value(_thumbnailData);

  @override
  Stream<List<int>> get thumbnailDataStream => Stream.value(_thumbnailData);

  @override
  Future<Uint8List> get photoData => Future.value(_photoData);

  @override
  Stream<List<int>> get photoDataStream => Stream.value(_photoData);
}

class ThumbnailMemoryPhotoFileFeaturePhoto extends FeaturePhoto {
  final Uint8List _thumbnailData;
  final File _photoFile;

  ThumbnailMemoryPhotoFileFeaturePhoto(this._thumbnailData, this._photoFile,
      {required int id,
      required int featureID,
      required String thumbnailContentType,
      required String contentType,
      required int photoDataSize})
      : super(id, featureID, thumbnailContentType, contentType, photoDataSize);

  Uint8List get thumbnailDataSync => _thumbnailData;

  @override
  Future<Uint8List> get thumbnailData => Future.value(_thumbnailData);

  @override
  Stream<List<int>> get thumbnailDataStream => Stream.value(_thumbnailData);

  @override
  Future<Uint8List> get photoData => _photoFile.readAsBytes();

  @override
  Stream<List<int>> get photoDataStream => _photoFile.openRead();
}

class Proposal {
  final int ownerId;
  final String description;
  final String how;

  Proposal(this.ownerId, this.description, this.how);

  factory Proposal.fromJson(Map<String, dynamic> json) {
    int ownerId = json['owner_id'] as int;
    String description = json['description'] as String;
    String how = json['how'] as String;
    return Proposal(ownerId, description, how);
  }

  @mustCallSuper
  Map<String, dynamic> toJson() =>
      {'owner_id': ownerId, 'description': description, 'how': how};
}

typedef Users = Map<int, String>;
typedef UsersView = UnmodifiableMapView<int, String>;
typedef FeaturesView = UnmodifiableListView<Feature>;
typedef FeaturesMapView = UnmodifiableMapView<int, Feature>;
