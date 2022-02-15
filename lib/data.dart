import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  static const PointAttribute important = PointAttribute._(
      0, 'important', Icons.warning, -1, -1, Color(0xffff0000));

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
  DateTime? deadline;
  DateTime? origDeadline;
  String? description;
  String? origDescription;
  Color color;
  Color origColor;

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
          cat,
          origCat,
          attributes,
          origAttributes,
          deleted,
          geometry,
          origGeometry);
    } else if (Feature.isGeojsonLineString(geometry)) {
      Color color =
          colorValue == null ? LineString.defaultColor : Color(colorValue);
      Color origColor = origColorValue == null
          ? LineString.defaultColor
          : Color(origColorValue);
      return LineString.fromGeojson(
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
          deleted,
          geometry,
          origGeometry);
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
      description != origDescription ||
      color.value != origColor.value ||
      (deadline == null && origDeadline != null) ||
      (deadline != null && origDeadline == null) ||
      (deadline != null &&
          origDeadline != null &&
          !deadline!.isAtSameMomentAs(origDeadline!));

  void revert() {
    ownerId = origOwnerId;
    name = origName;
    deadline = origDeadline;
    description = origDescription;
  }

  bool get isLocal => id < 0;

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
            deleted);
  Point.origSame(
      int id,
      int ownerId,
      String name,
      DateTime? deadline,
      String? description,
      Color color,
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
  static const Color defaultColor = Colors.black;

  List<LatLng> coords;
  List<LatLng> origCoords;

  LineString._(
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
      this.coords,
      this.origCoords,
      bool deleted)
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
            deleted);

  factory LineString.fromGeojson(
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
        deadline,
        origDeadline,
        description,
        origDescription,
        color,
        origColor,
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
  Map<String, dynamic> toJson() {
    var js = super.toJson();
    js.addAll({'geometry': _geometry(), 'orig_geometry': _origGeometry()});
    return js;
  }
}

typedef Users = Map<int, String>;
typedef UsersView = UnmodifiableMapView<int, String>;
typedef FeaturesView = UnmodifiableListView<Feature>;
typedef FeaturesMapView = UnmodifiableMapView<int, Feature>;
