import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:collection/collection.dart';
import 'package:oko/utils.dart';

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
  static const PointAttribute important =
      PointAttribute._(0, 'important', Icons.warning, -1, -1, Colors.red);

  static final List<PointAttribute> attributes = [important];

  static PointAttribute fromNameString(String? s) {
    if (s == important.name) {
      return important;
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

enum EditState { anyState, pristineState, newState, editedState }

EditState parseEditState(String str) {
  return {
    EditState.anyState.name: EditState.anyState,
    EditState.pristineState.name: EditState.pristineState,
    EditState.newState.name: EditState.newState,
    EditState.editedState.name: EditState.editedState
  }[str]!;
}

abstract class Feature {
  int id;
  int ownerId;
  int origOwnerId;
  String name;
  String origName;
  String? description;
  String? origDescription;

  bool deleted;

  Feature._(this.id, this.ownerId, this.origOwnerId, this.name, this.origName,
      this.description, this.origDescription, this.deleted);

  factory Feature.fromJson(Map<String, dynamic> json) {
    int id = json['id'];
    int ownerId = json['owner_id'];
    String name = json['name'];
    Map<String, dynamic> properties = json['properties'];
    Map<String, dynamic> geometry = json['geometry'];

    String? description = properties['description'];

    if (Feature.isGeojsonPoint(geometry)) {
      String? category = properties['category'];
      PointCategory cat = PointCategory.fromNameString(category);
      List<dynamic> attrList = properties['attributes'] ?? [];
      Set<PointAttribute> attributes = attrList
          .map((e) => e as String)
          .map((String attrName) => PointAttribute.fromNameString(attrName))
          .toSet();
      return Point.fromGeojson(
          id,
          ownerId,
          ownerId,
          name,
          name,
          description,
          description,
          cat,
          cat,
          attributes,
          Set.of(attributes),
          false,
          geometry,
          geometry);
    } else if (Feature.isGeojsonLineString(geometry)) {
      return LineString.fromGeojson(id, ownerId, ownerId, name, name,
          description, description, false, geometry, geometry);
    }
    throw Exception('unsupported geometry type');
  }

  static bool isGeojsonPoint(Map<String, dynamic> geojson) {
    return geojson['type'] == 'Point';
  }

  static bool isGeojsonLineString(Map<String, dynamic> geojson) {
    return geojson['type'] == 'LineString';
  }

  bool isPoint();
  Point asPoint();
  bool isLineString();
  LineString asLineString();

  bool get isEdited =>
      ownerId != origOwnerId ||
      name != origName ||
      description != origDescription;

  void revert() {
    ownerId = origOwnerId;
    name = origName;
    description = origDescription;
  }

  bool get isLocal => id < 0;

  Map<String, dynamic> toJson();
  Map<String, Object> toDbEntry();
}

class Point extends Feature {
  LatLng coords;
  LatLng origCoords;
  PointCategory category;
  PointCategory origCategory;
  Set<PointAttribute> attributes;
  Set<PointAttribute> origAttributes;

  Point(
      id,
      ownerId,
      origOwnerId,
      name,
      origName,
      description,
      origDescription,
      this.coords,
      this.origCoords,
      this.category,
      this.origCategory,
      this.attributes,
      this.origAttributes,
      deleted)
      : super._(id, ownerId, origOwnerId, name, origName, description,
            origDescription, deleted);
  Point.origSame(
      int id,
      int ownerId,
      String name,
      String? description,
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
            description,
            description,
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
      String? description,
      String? origDescription,
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
        description,
        origDescription,
        LatLng(geom['coordinates'][1], geom['coordinates'][0]),
        LatLng(origGeom['coordinates'][1], origGeom['coordinates'][0]),
        category,
        origCategory,
        attributes,
        origAttributes,
        deleted);
  }

  @override
  bool isPoint() {
    return true;
  }

  @override
  Point asPoint() => this;

  @override
  bool isLineString() {
    return false;
  }

  @override
  LineString asLineString() {
    throw IllegalStateException('not a LineString');
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
  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'properties': {
          'description': description,
          'category': category.name,
          'attributes':
              attributes.map((attr) => attr.name).toList(growable: false)
        },
        'geometry': _geometry()
      };

  @override
  Map<String, Object> toDbEntry() {
    return {
      'id': id,
      'owner_id': ownerId,
      'orig_owner_id': origOwnerId,
      'name': name,
      'orig_name': origName,
      if (description != null) 'description': description!,
      if (origDescription != null) 'orig_description': origDescription!,
      'point_category': category.name,
      'orig_point_category': origCategory.name,
      'attributes': jsonEncode(
          attributes.map((attr) => attr.name).toList(growable: false)),
      'orig_attributes': jsonEncode(
          origAttributes.map((attr) => attr.name).toList(growable: false)),
      'geom': jsonEncode(_geometry()),
      'orig_geom': jsonEncode(_origGeometry()),
      'deleted': deleted ? 1 : 0
    };
  }

  Point copy() {
    return Point(
        id,
        ownerId,
        origOwnerId,
        name,
        origName,
        description,
        origDescription,
        LatLng(coords.latitude, coords.longitude),
        LatLng(origCoords.latitude, origCoords.longitude),
        category,
        origCategory,
        Set.of(attributes),
        Set.of(origAttributes),
        deleted);
  }
}

class LineString extends Feature {
  List<LatLng> coords;
  List<LatLng> origCoords;

  LineString._(id, ownerId, origOwnerId, name, origName, description,
      origDescription, this.coords, this.origCoords, deleted)
      : super._(id, ownerId, origOwnerId, name, origName, description,
            origDescription, deleted);

  factory LineString.fromGeojson(
      int id,
      int ownerId,
      int origOwnerId,
      String name,
      String origName,
      String? description,
      String? origDescription,
      bool deleted,
      Map<String, dynamic> geom,
      Map<String, dynamic> origGeom) {
    assert(geom['type'] == 'LineString');
    assert(origGeom['type'] == 'LineString');

    List<List<double>> coords = geom['coordinates'];
    List<List<double>> origCoords = origGeom['coordinates'];
    return LineString._(
        id,
        ownerId,
        origOwnerId,
        name,
        origName,
        description,
        origDescription,
        coords
            .map((List<double> c) => LatLng(c[1], c[0]))
            .toList(growable: false),
        origCoords
            .map((List<double> c) => LatLng(c[1], c[0]))
            .toList(growable: false),
        deleted);
  }

  @override
  bool isPoint() {
    return false;
  }

  @override
  Point asPoint() {
    throw IllegalStateException('not a Point');
  }

  @override
  bool isLineString() {
    return true;
  }

  @override
  LineString asLineString() => this;

  @override
  bool get isEdited =>
      super.isEdited || const IterableEquality().equals(coords, origCoords);

  @override
  void revert() {
    super.revert();
    coords = List.of(origCoords);
  }

  Map<String, dynamic> _geometry() => {
        'type': 'LineString',
        'coordinates': coords
            .map((LatLng c) => [c.longitude, c.latitude])
            .toList(growable: false)
      };

  Map<String, dynamic> _origGeometry() => {
        'type': 'LineString',
        'coordinates': origCoords
            .map((LatLng c) => [c.longitude, c.latitude])
            .toList(growable: false)
      };

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'properties': {'description': description},
        'geometry': _geometry()
      };

  @override
  Map<String, Object> toDbEntry() {
    return {
      'id': id,
      'owner_id': ownerId,
      'orig_owner_id': origOwnerId,
      'name': name,
      'orig_name': origName,
      if (description != null) 'description': description!,
      if (origDescription != null) 'orig_description': origDescription!,
      'geom': jsonEncode(_geometry()),
      'orig_geom': jsonEncode(_origGeometry()),
      'deleted': deleted ? 1 : 0
    };
  }
}

typedef Users = Map<int, String>;
typedef UsersView = UnmodifiableMapView<int, String>;
typedef FeaturesView = UnmodifiableListView<Feature>;
typedef FeaturesMapView = UnmodifiableMapView<int, Feature>;
