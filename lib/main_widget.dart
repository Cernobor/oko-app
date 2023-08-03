import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map_tappable_polyline/flutter_map_tappable_polyline.dart';
import 'package:flutter_map_line_editor/flutter_map_line_editor.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:geodesy/geodesy.dart';
import 'package:get_it/get_it.dart';
import 'package:location/location.dart';
import 'package:oko/communication.dart' as comm;
import 'package:oko/data.dart' as data;
import 'package:oko/data.dart';
import 'package:oko/dialogs/poly_nav_point_chooser.dart';
import 'package:oko/feature_filters.dart';
import 'package:oko/i18n.dart';
import 'package:oko/main.dart';
import 'package:oko/map.dart';
import 'package:oko/storage.dart';
import 'package:oko/subpages/edit_point.dart';
import 'package:oko/subpages/gallery.dart';
import 'package:oko/subpages/pairing.dart';
import 'package:oko/subpages/edit_poly.dart';
import 'package:oko/subpages/feature_list.dart';
import 'package:oko/subpages/proposal.dart';
import 'package:oko/utils.dart' as utils;
import 'package:oko/constants.dart' as constants;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' show join;
import 'package:rxdart/rxdart.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' hide Theme;

import 'mbtiles.dart';

GetIt getIt = GetIt.instance;

class MainWidget extends StatefulWidget {
  const MainWidget({Key? key}) : super(key: key);

  @override
  MainWidgetState createState() => MainWidgetState();
}

class MainWidgetState extends State<MainWidget> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  // constants
  static const double fallbackMinZoom = 1;
  static const double fallbackMaxZoom = 18;
  static const Color extraGeometryColor = Colors.deepPurple;

  // location and map
  final Location location = Location();
  final MapController mapController = MapController();
  late final StreamSubscription<MapEvent> mapSubscription;
  late final StreamController<MapEvent> mapStateStorageController =
      StreamController<MapEvent>(sync: true);
  MbtilesTileProvider? offlineMapProvider;

  // handling flags and values
  bool mapReady = false;
  double? progressValue;
  bool pinging = false;
  bool pingInProgress = false;
  comm.PingResponse? pingResponse;
  StreamSubscription<LocationData>? locationSubscription;
  StreamSubscription<CompassEvent>? compassSubscription;
  bool viewLockedToLocation = false;
  LatLng? currentLocation;
  double? currentHeading;
  Feature? infoTarget;
  utils.Target navigationTarget = utils.Target.none;
  bool filterExpanded = false;
  TextEditingController? searchController;

  bool polyEditing = false;
  utils.EditedPoly editedPoly = utils.EditedPoly.fresh();
  int? editedPolySourceFeature;
  late PolyEditor polyEditor;

  // settings
  Storage? storage;

  Future<dynamic>? initResult;

  @override
  void initState() {
    polyEditor = PolyEditor(
        points: editedPoly.coords,
        pointIcon: const Icon(constants.polyNode, size: 32, color: Colors.red),
        intermediateIcon:
            const Icon(constants.polyMidpoint, size: 32, color: Colors.red),
        callbackRefresh: () {
          setState(() {});
        },
        addClosePathMarker: editedPoly.closed);
    super.initState();
    initResult = init();
  }

  Future<bool> init() async {
    getIt.registerSingletonAsync<PackageInfo>(PackageInfo.fromPlatform);
    getIt.registerSingletonWithDependencies<comm.AppClient>(
        () => comm.AppClient(
            '${getIt.get<PackageInfo>().appName}/${getIt.get<PackageInfo>().version}'),
        dependsOn: [PackageInfo]);

    try {
      storage = await Storage.getInstance();
    } catch (e, stacktrace) {
      developer.log(e.toString());
      developer.log(stacktrace.toString());
      utils.notifySnackbar(
          context,
          'Error while getting storage: ${e.toString()}',
          utils.NotificationLevel.error);
    }
    if (storage?.serverSettings?.serverAddress != null) {
      if (storage?.serverSettings?.id != null) {
        getIt.get<comm.AppClient>().setUserID(storage!.serverSettings!.id);
      }
      startPinging();
    }
    if (storage?.mapState?.usingOffline ?? false) {
      offlineMapProvider =
          await MbtilesTileProvider.create(14, storage!.offlineMap.path);
    }
    mapSubscription = mapController.mapEventStream
        .where((evt) =>
            evt is MapEventWithMove ||
            evt is MapEventRotate ||
            evt is MapEventMoveEnd ||
            evt is MapEventRotateEnd)
        .listen(onMapEvent);
    mapStateStorageController.stream
        .debounceTime(const Duration(milliseconds: 200))
        .listen(onMapEventStorage);
    await getIt.allReady();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: initResult,
        initialData: false,
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          if (snapshot.data == true) {
            return createUi(context);
          }
          return Container(
            decoration: const BoxDecoration(color: cbGreen),
            child: const Center(
              child: Image(
                image: AssetImage('assets/splash.png'),
                width: 320.0,
                height: 147.0,
              ),
            ),
          );
        });
  }

  Widget createUi(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      primary: true,
      appBar: createAppBar(context),
      drawer: createDrawer(context),
      body: createBody(context),
      //floatingActionButton: createZoomControls(context),
      //floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      bottomNavigationBar: createBottomBar(context),
    );
  }

  AppBar createAppBar(BuildContext context) {
    return AppBar(
      title: Text(I18N
          .of(context)
          .appTitleWithVersion(getIt.get<PackageInfo>().version)),
      centerTitle: true,
      primary: true,
      bottom: PreferredSize(
        preferredSize: const Size(double.infinity, 6.0),
        child: progressValue == null
            ? Container(height: 6.0)
            : LinearProgressIndicator(
                value: progressValue == -1 ? null : progressValue,
              ),
      ),
    );
  }

  Widget createDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: <Widget>[
          // pairing
          ListTile(
            title: Text(I18N.of(context).drawerPaired),
            isThreeLine: storage?.serverSettings != null,
            subtitle: storage?.serverSettings?.serverAddress == null
                ? null
                : Text(
                    '${storage!.serverSettings!.serverAddress}\n${storage!.serverSettings!.name} <ID: ${storage!.serverSettings!.id}>'),
            trailing: storage?.serverSettings == null
                ? const Icon(
                    Icons.clear,
                    color: Colors.red,
                  )
                : const Icon(
                    Icons.done,
                    color: Colors.green,
                  ),
            onTap: onPair,
          ),
          // pinging
          ListTile(
            title: pingInProgress
                ? Text(I18N.of(context).drawerServerChecking)
                : (pingResponse == null
                    ? Text(I18N.of(context).drawerServerUnavailable)
                    : Text(I18N.of(context).drawerServerAvailable)),
            subtitle: pingResponse == null || pingResponse!.appVersion == null
                ? null
                : Text(I18N.of(context).drawerNewVersion),
            enabled: storage?.serverSettings != null,
            trailing: storage?.serverSettings != null && pingInProgress
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                        value: null, strokeWidth: 2.5),
                  )
                : (storage?.serverSettings != null && pingResponse != null
                    ? const Icon(
                        Icons.done,
                        color: Colors.green,
                      )
                    : const Icon(
                        Icons.clear,
                        color: Colors.red,
                      )),
            onTap: () {
              pingResponse = null;
              onPing();
            },
          ),
          // map switch
          SwitchListTile(
              title: Text(I18N.of(context).renderBaseMap),
              value: storage?.mapState?.render ?? false,
              onChanged: storage?.serverSettings == null ? null : onRenderMap,
              secondary: const Icon(Icons.map)),
          // offline map switch
          SwitchListTile(
              title: Text(I18N.of(context).useOfflineMap),
              subtitle: storage?.serverSettings?.mapPackSize == null
                  ? null
                  : Text(I18N
                      .of(context)
                      .mapSizeWarning(storage!.serverSettings!.mapPackSize)),
              value: storage?.mapState?.usingOffline ?? false,
              onChanged: storage?.serverSettings == null ? null : onUseOffline,
              secondary: const Icon(Icons.download_for_offline)),
          // syncing
          ListTile(
            title: Text(I18N.of(context).sync),
            leading: const Icon(Icons.sync),
            enabled: storage?.serverSettings != null && !polyEditing,
            onTap: onSync,
            onLongPress: () {
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      children: <Widget>[
                        ListTile(
                          title: Text(I18N.of(context).download),
                          leading: const Icon(Icons.cloud_download),
                          enabled: storage?.serverSettings != null,
                          onTap: () {
                            Navigator.of(context).pop();
                            onDownload(context);
                          },
                        ),
                        ListTile(
                          title: Text(I18N.of(context).upload),
                          leading: const Icon(Icons.cloud_upload),
                          enabled: storage?.serverSettings != null,
                          onTap: () {
                            Navigator.of(context).pop();
                            onUpload();
                          },
                        ),
                      ],
                    );
                  });
            },
          ),
          // log on location
          ListTile(
            title: Text(I18N.of(context).logPoiCurrentLocation),
            leading: const Icon(Icons.add_location_alt_outlined),
            trailing: const Icon(Icons.my_location),
            onTap: () => onLogPoint(utils.PointLogType.currentLocation),
            enabled: storage?.serverSettings != null &&
                currentLocation != null &&
                !polyEditing,
          ),
          // log on crosshair
          ListTile(
            title: Text(I18N.of(context).logPoiCrosshair),
            leading: const Icon(Icons.add_location_alt_outlined),
            trailing: const Icon(Icons.add),
            onTap: () => onLogPoint(utils.PointLogType.crosshair),
            enabled: storage?.serverSettings != null && !polyEditing,
          ),
          // create poly
          ListTile(
            title: Text(I18N.of(context).createPoly),
            leading: const Icon(Icons.polyline),
            onTap: () {
              onStartPolyEdit();
              Navigator.pop(context);
            },
            enabled: storage?.serverSettings != null && !polyEditing,
          ),
          // point list
          ListTile(
            title: Text(I18N.of(context).poiListTitle),
            leading: const Icon(Icons.place),
            trailing: const Icon(Icons.arrow_forward),
            onTap: onPointListTap,
            enabled: storage?.serverSettings != null && !polyEditing,
          ),
          // user list
          ListTile(
            title: Text(I18N.of(context).userListTitle),
            subtitle: Text(I18N.of(context).infoOnly),
            leading: const Icon(Icons.people),
            onTap: onUserListTap,
            enabled: storage?.serverSettings != null,
          ),
          // propose improvements
          ListTile(
            title: Text(I18N.of(context).proposeImprovement),
            leading: const Icon(Icons.settings_suggest),
            onTap: onProposeImprovement,
            enabled: storage?.serverSettings != null && !polyEditing,
          ),
          // app reset
          ListTile(
            title: Text(I18N.of(context).reset),
            subtitle: Text(I18N.of(context).resetInfo),
            leading: const Icon(Icons.warning),
            onLongPress: onReset,
            enabled: !polyEditing,
          )
        ],
      ),
    );
  }

  Widget createBody(BuildContext context) {
    const xline = Divider(
      color: Color(0xffdd0000),
      thickness: 2,
    );
    Widget? bottomCard;
    if (searchController != null) {
      bottomCard = Container(
          alignment: Alignment.bottomCenter,
          constraints: const BoxConstraints.expand(),
          child: createFilterSearch(context));
    } else if (infoTarget != null && !polyEditing) {
      bottomCard = Container(
        alignment: Alignment.bottomCenter,
        constraints: const BoxConstraints.expand(),
        child: createInfoContentFull(context),
      );
    } else if (navigationTarget.isNotNone &&
        currentLocation != null &&
        !polyEditing) {
      bottomCard = Container(
        alignment: Alignment.bottomCenter,
        constraints: const BoxConstraints.expand(),
        child: createInfoContentDistance(context),
      );
    }
    return Stack(
      children: <Widget>[
        createMap(context),
        if (bottomCard != null) bottomCard,
        Container(
            alignment: Alignment.center,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              child: xline,
            )),
        Container(
            alignment: Alignment.center,
            child: RotatedBox(
              quarterTurns: 1,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.5,
                child: xline,
              ),
            )),
        createMapControls(context),
        createMapFilterControl(context),
        if (polyEditing) createPolyEditingChip(),
        if (polyEditing) createPolyEditingControls(context)
      ],
    );
  }

  Widget createMap(BuildContext context) {
    List<Widget> children = [];
    if (storage?.serverSettings != null) {
      if (storage?.mapState?.render ?? false) {
        children.add(createMapLayer(context));
      } else {
        children.add(const SolidColorLayer(color: mapBackgroundColor));
      }
    }

    // Polylines
    List<Polyline> polylines = [];
    // limits
    if (storage?.mapState?.hasPanLimits ?? false) {
      polylines.add(Polyline(points: <LatLng>[
        LatLng(storage!.mapState!.swBound!.latitude,
            storage!.mapState!.swBound!.longitude),
        LatLng(storage!.mapState!.swBound!.latitude,
            storage!.mapState!.neBound!.longitude),
        LatLng(storage!.mapState!.neBound!.latitude,
            storage!.mapState!.neBound!.longitude),
        LatLng(storage!.mapState!.neBound!.latitude,
            storage!.mapState!.swBound!.longitude)
      ]));
    }
    // line to target
    if (navigationTarget.isNotNone && currentLocation != null) {
      polylines.add(Polyline(points: <LatLng>[
        currentLocation!,
        navigationTarget.coords,
      ], strokeWidth: 5, color: Colors.blue));
    }
    // edited polyline
    if (polyEditing && !editedPoly.closed) {
      polylines.add(Polyline(
          points: editedPoly.coords, strokeWidth: 2, color: editedPoly.color));
    }
    children.add(PolylineLayer(polylines: polylines));

    // Polygons
    List<Polygon> polygons = [];
    // edited polygon
    if (polyEditing && editedPoly.closed) {
      polygons.add(Polygon(
          points: editedPoly.coords,
          color: editedPoly.colorFill
                  ?.withOpacity(constants.polySelectedFillColorOpacity) ??
              Colors.transparent,
          borderColor: editedPoly.color,
          isFilled: true,
          borderStrokeWidth: 2));
    }
    // polygons
    polygons.addAll(createPolygons());
    children.add(PolygonLayer(polygons: polygons));

    // Tappable polylines
    List<TaggedPolyline> tappablePolylines = createPolylines();
    children.add(TappablePolylineLayer(
        polylines: tappablePolylines,
        onTap: (List<TaggedPolyline> polylines, TapUpDetails tapPosition) {
          if (storage == null) {
            return;
          }
          TaggedPolyline tp = polylines.first;
          int id = int.parse(tp.tag!);
          onPolylineTap(storage!.featuresMap[id]!.asPoly());
        }));

    // Markers
    List<Marker> markers = [];
    // current location
    if (currentLocation != null) {
      markers.add(Marker(
          height: 40,
          width: 40,
          anchorPos: AnchorPos.align(AnchorAlign.center),
          point: currentLocation!,
          builder: (context) {
            if (currentHeading != null && locationSubscription != null) {
              return Transform.rotate(
                angle: currentHeading!,
                child: const Icon(
                  Icons.navigation,
                  color: Color(0xffff0000),
                  size: 40,
                ),
              );
            }
            return Transform.rotate(
                angle: -mapController.rotation * math.pi / 180.0,
                child: Icon(
                  Icons.my_location,
                  color: locationSubscription == null
                      ? const Color(0xff000000)
                      : const Color(0xffff0000),
                  size: 40,
                ));
          }));
    }
    // points
    markers.addAll(createMarkers());
    children.add(MarkerLayer(markers: markers));

    // Poly editor
    if (polyEditing) {
      children.add(DragMarkers(markers: polyEditor.edit()));
    }

    return FlutterMap(
      options: MapOptions(
          center: storage?.mapState?.center ??
              storage?.serverSettings?.defaultCenter,
          zoom: storage?.mapState?.zoom.toDouble() ??
              (storage?.serverSettings?.minZoom.toDouble()) ??
              fallbackMinZoom,
          maxZoom: storage?.mapState?.zoomMax?.toDouble() ?? fallbackMaxZoom,
          minZoom:
              storage?.serverSettings?.minZoom.toDouble() ?? fallbackMinZoom,
          nePanBoundary: storage?.mapState?.neBound,
          swPanBoundary: storage?.mapState?.swBound,
          onTap: onMapTap,
          enableMultiFingerGestureRace: true,
          pinchZoomThreshold: 0.2,
          rotationThreshold: 2,
          onMapReady: () {
            Future.microtask(() {
              setState(() {
                mapReady = true;
              });
            });
          }),
      mapController: mapController,
      children: children,
    );
  }

  Widget createMapLayer(BuildContext context) {
    VectorTileLayer vtl;
    if (offlineMapProvider == null) {
      vtl = VectorTileLayer(
          tileProviders: TileProviders({
            'openmaptiles': MemoryCacheVectorTileProvider(
                delegate: NetworkVectorTileProvider(
                    urlTemplate:
                        '${comm.ensureNoTrailingSlash(storage!.serverSettings!.serverAddress)}${storage!.serverSettings!.tilePathTemplate}',
                    maximumZoom: 14),
                maxSizeBytes: 1024 * 1024 * 5)
          }),
          theme: ThemeReader().read(mapThemeData('online')),
          backgroundTheme: ThemeReader().readAsBackground(
              mapThemeData('online'),
              layerPredicate: defaultBackgroundLayerPredicate));
    } else {
      vtl = VectorTileLayer(
          tileProviders: TileProviders({
            'openmaptiles': MemoryCacheVectorTileProvider(
                delegate: offlineMapProvider!, maxSizeBytes: 1024 * 1024 * 5)
          }),
          theme: ThemeReader().read(mapThemeData('offline')),
          backgroundTheme: ThemeReader().readAsBackground(
              mapThemeData('offline'),
              layerPredicate: defaultBackgroundLayerPredicate));
    }

    return vtl;
  }

  List<Marker> createMarkers() {
    if (storage == null) {
      return [];
    }
    FeatureFilter filter = storage!.getFeatureFilter(FeatureFilterInst.map);
    Iterable<data.Point> points = storage!.features.whereType<data.Point>();
    return filter.filter(points).map((data.Feature feature) {
      data.Point point = feature.asPoint();
      bool sameAsTarget = infoTarget == point;
      double size = 35.0;
      double badgeSize = 12.0;
      if (sameAsTarget) {
        size *= 1.5;
        badgeSize *= 1.5;
      }
      double width = size;
      double height = size;
      return Marker(
        point: point.coords,
        anchorPos: point.category.anchorPos(width, height),
        width: width,
        height: height,
        builder: (context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onPointTap(point),
            onLongPress: () => onPointLongPress(point),
            child: Transform.rotate(
                angle: -mapController.rotation * math.pi / 180.0,
                alignment: point.category.rotationAlignment(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      point.category.iconData,
                      size: size,
                      color: point.color,
                    ),
                    if (point.isLocal)
                      Align(
                        alignment: const Alignment(1, -1),
                        child: Icon(Icons.star,
                            size: badgeSize,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    if (point.isEdited)
                      Align(
                        alignment: const Alignment(1, -1),
                        child: Icon(Icons.edit,
                            size: badgeSize,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    if (point.deleted)
                      Align(
                        alignment: point.isEdited
                            ? const Alignment(1, 0)
                            : const Alignment(1, -1),
                        child: Icon(Icons.delete,
                            size: badgeSize,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    if (point.ownerId == 0)
                      Align(
                        alignment: const Alignment(1, -1),
                        child: Icon(Icons.lock,
                            size: badgeSize,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    for (var attr in point.attributes)
                      Align(
                        alignment: Alignment(attr.xAlign, attr.yAlign),
                        child: Icon(attr.iconData,
                            size: badgeSize, color: attr.color),
                      )
                  ],
                ))),
      );
    }).toList();
  }

  List<Polygon> createPolygons() {
    if (storage == null) {
      return [];
    }
    FeatureFilter filter = storage!.getFeatureFilter(FeatureFilterInst.map);
    Iterable<data.Poly> polys =
        storage!.features.whereType<data.Poly>().where((e) => e.polygon);
    return filter.filter(polys).map((data.Feature feature) {
      data.Poly polygon = feature.asPoly();
      return Polygon(
          points: polygon.coords,
          borderColor: polygon.color,
          color: (polygon.colorFill ?? Colors.transparent).withOpacity(
              infoTarget == polygon
                  ? constants.polySelectedFillColorOpacity
                  : constants.polyFillColorOpacity),
          isFilled: polygon.colorFill != null,
          isDotted: polygon.isLocal,
          borderStrokeWidth: infoTarget == polygon ? 4 : 2);
    }).toList(growable: false);
  }

  List<TaggedPolyline> createPolylines() {
    if (storage == null) {
      return [];
    }
    FeatureFilter filter = storage!.getFeatureFilter(FeatureFilterInst.map);
    Iterable<data.Poly> polys =
        storage!.features.whereType<data.Poly>().whereNot((e) => e.polygon);
    return filter.filter(polys).map((data.Feature feature) {
      data.Poly polyline = feature.asPoly();
      return TaggedPolyline(
          tag: '${polyline.id}',
          points: polyline.coords,
          color: polyline.color,
          isDotted: polyline.isLocal,
          strokeWidth: infoTarget == polyline ? 4 : 2);
    }).toList(growable: false);
  }

  Widget createInfoContentDistance(BuildContext context) {
    utils.NavigationData nav = utils.NavigationData.compute(
        currentLocation!, navigationTarget.coords, currentHeading);
    return Card(
        child: InkWell(
      onTap: onInfoDistanceTap,
      child: Container(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'd: ${nav.distanceM.toStringAsFixed(2)} m  '
            'b: ${nav.bearingDeg.toStringAsFixed(2)}°  '
            'rb: ${nav.relativeBearingDeg == null ? '-' : nav.relativeBearingDeg!.toStringAsFixed(2)}°',
            textAlign: TextAlign.center,
          )),
    ));
  }

  Widget createInfoContentFull(BuildContext context) {
    bool isNavigating = navigationTarget.isNotNone &&
        currentLocation != null &&
        infoTarget != null &&
        navigationTarget.isSameFeature(infoTarget!);
    String? navText;
    if (isNavigating) {
      utils.NavigationData nav = utils.NavigationData.compute(
          currentLocation!, navigationTarget.coords, currentHeading);
      var distStr = '${I18N.of(context).distance}: ${nav.distanceM} m';
      var brgStr =
          '${I18N.of(context).bearing}: ${nav.bearingDeg.toStringAsFixed(1)}°';
      var relBrgStr =
          '${I18N.of(context).relativeBearing}: ${nav.relativeBearingDeg == null ? '-' : nav.relativeBearingDeg!.toStringAsFixed(1)}°';
      navText = '$distStr $brgStr $relBrgStr';
    }
    Widget content = createInfoContent(context, infoTarget!, navText);
    return Dismissible(
        key: const Key('fullInfoDismissible'),
        onDismissed: (DismissDirection dd) {
          setState(() {
            infoTarget = null;
          });
        },
        resizeDuration: null,
        child: Card(
            child: Container(
                padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                child: content)));
  }

  Widget createInfoContent(
      BuildContext context, data.Feature feature, String? navText) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.only(
                top: 0.0, left: 16.0, right: 16.0, bottom: 4.0),
            child: createInfoContentTitleRow(context, feature, navText),
          ),
          if (feature.description?.isNotEmpty ?? false)
            Container(
                padding:
                    const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 4.0),
                child: Text(feature.description!)),
          ButtonBar(
              alignment: MainAxisAlignment.spaceEvenly,
              buttonHeight: 0,
              buttonPadding: EdgeInsets.zero,
              layoutBehavior: ButtonBarLayoutBehavior.padded,
              mainAxisSize: MainAxisSize.min,
              children: createInfoContentButtons(context, feature)),
        ]);
  }

  Widget createInfoContentTitleRow(
      BuildContext context, data.Feature feature, String? navText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
            ('${feature.name} | '
                '${storage?.users[feature.ownerId]}'
                '${storage?.getFeatureFilter(FeatureFilterInst.map).passes(feature) == true ? '' : ' (${I18N.of(context).filteredOut})'}'),
            style: Theme.of(context).textTheme.titleLarge),
        if (feature.isPoint())
          Text(
              [
                utils.formatCoords(feature.asPoint().coords, false),
                '${I18N.of(context).categoryTitle}: ${I18N.of(context).category(feature.asPoint().category)}'
              ].join(' '),
              style: Theme.of(context).textTheme.bodySmall),
        if (navText != null)
          Text(navText, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  List<Widget> createInfoContentButtons(
      BuildContext context, data.Feature feature) {
    return <Widget>[
      IconButton(
        icon: navigationTarget.isNotNone &&
                navigationTarget.isSameFeature(feature)
            ? const Icon(Icons.navigation)
            : const Icon(Icons.navigation_outlined),
        tooltip: navigationTarget.isNotNone &&
                navigationTarget.isSameFeature(feature)
            ? I18N.of(context).stopNavigationButton
            : I18N.of(context).navigateToButton,
        onPressed: currentLocation == null
            ? null
            : () async {
                if (feature.isPoint()) {
                  toggleNavigation(feature.center(), feature);
                } else if (feature.isPoly()) {
                  if (navigationTarget.isNotNone) {
                    setState(() {
                      navigationTarget = utils.Target.none;
                    });
                  } else {
                    LatLng? coords = await getPolyCoords(feature.asPoly());
                    if (coords != null) {
                      toggleNavigation(coords, feature);
                    }
                  }
                }
              },
      ),
      GestureDetector(
        child: IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: I18N.of(context).centerViewInfoButton,
            onPressed: () => onCenterView(feature, false)),
        onDoubleTap: () => onCenterView(feature, true),
      ),
      if (feature.ownerId != 0)
        if (feature.deleted)
          IconButton(
            icon: const Icon(Icons.restore_from_trash),
            tooltip: I18N.of(context).undelete,
            onPressed: () => onUndeleteFeature(feature),
          )
        else
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: I18N.of(context).delete,
            onPressed: () => onDeleteFeature(feature),
          ),
      if (feature.ownerId != 0)
        IconButton(
            icon: const Icon(Icons.edit),
            tooltip: I18N.of(context).edit,
            onPressed: () {
              if (feature.isPoint()) {
                onEditPoint(feature.asPoint());
              } else if (feature.isPoly()) {
                onStartPolyEdit(feature.asPoly());
              }
            }),
      if (feature.ownerId != 0 && feature.isEdited)
        IconButton(
            icon: const Icon(Icons.restore),
            tooltip: I18N.of(context).revert,
            onPressed: () => onRevertFeature(feature)),
      if (feature.ownerId != 0)
        IconButton(
          icon: const Icon(Icons.photo_library),
          tooltip: I18N.of(context).managePhotos,
          onPressed: () => onOpenGallery(feature),
        ),
    ];
  }

  Widget createMapControls(BuildContext context) {
    return Container(
      alignment: Alignment.topRight,
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        alignment: WrapAlignment.start,
        direction: Axis.vertical,
        crossAxisAlignment: WrapCrossAlignment.center,
        runAlignment: WrapAlignment.end,
        spacing: 10,
        children: <Widget>[
          FloatingActionButton(
            heroTag: 'fab-zoom-in',
            tooltip: I18N.of(context).zoomIn,
            elevation: 0,
            backgroundColor: !mapReady ||
                    mapController.zoom >=
                        (storage?.mapState?.zoomMax ?? fallbackMaxZoom)
                ? Theme.of(context).colorScheme.secondary.withOpacity(.35)
                : null,
            onPressed: !mapReady ||
                    mapController.zoom >=
                        (storage?.mapState?.zoomMax ?? fallbackMaxZoom)
                ? null
                : () => onZoom(1),
            child: const Icon(
              Icons.zoom_in,
              size: 30,
            ),
          ),
          FloatingActionButton(
            heroTag: 'fab-zoom-out',
            tooltip: I18N.of(context).zoomOut,
            elevation: 0,
            backgroundColor: !mapReady ||
                    mapController.zoom <=
                        (storage?.serverSettings?.minZoom ?? fallbackMinZoom)
                ? Theme.of(context).colorScheme.secondary.withOpacity(.35)
                : null,
            onPressed: !mapReady ||
                    mapController.zoom <=
                        (storage?.serverSettings?.minZoom ?? fallbackMinZoom)
                ? null
                : () => onZoom(-1),
            child: const Icon(
              Icons.zoom_out,
              size: 30,
            ),
          ),
          FloatingActionButton(
            heroTag: 'fab-reset-rotation',
            tooltip: I18N.of(context).resetRotation,
            elevation: 0,
            backgroundColor: !mapReady || mapController.rotation == 0.0
                ? Theme.of(context).colorScheme.secondary.withOpacity(.35)
                : null,
            onPressed: () {
              if (mapReady) {
                setState(() {
                  mapController.rotate(0);
                });
              }
            },
            child: Transform.rotate(
              angle: mapReady ? mapController.rotation * math.pi / 180 : 0,
              child: const Icon(
                Icons.north,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget createMapFilterControl(BuildContext context) {
    return Container(
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        alignment: WrapAlignment.end,
        direction: Axis.vertical,
        crossAxisAlignment: WrapCrossAlignment.center,
        runAlignment: WrapAlignment.end,
        spacing: 2,
        children: <Widget>[
              FloatingActionButton(
                heroTag: 'fab-filter',
                tooltip: I18N.of(context).toFilter,
                elevation: 0,
                onPressed: () {
                  setState(() {
                    filterExpanded = !filterExpanded;
                    if (!filterExpanded && searchController != null) {
                      onToggleFilterSearch();
                    }
                  });
                },
                child: Icon(
                  Icons.filter_alt,
                  size: 30,
                  color: storage != null &&
                          storage!
                              .getFeatureFilter(FeatureFilterInst.map)
                              .doesFilter(storage!.users.keys)
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ] +
            (!filterExpanded
                ? <Widget>[]
                : <Widget>[
                    FloatingActionButton(
                      heroTag: 'fab-filter-type',
                      tooltip: I18N.of(context).filterByType,
                      elevation: 0,
                      mini: true,
                      onPressed: () async {
                        FeatureFilter f =
                            storage!.getFeatureFilter(FeatureFilterInst.map);
                        bool changed = await f.setTypes(context);
                        if (changed) {
                          await storage!
                              .setFeatureFilter(FeatureFilterInst.map, f);
                          setState(() {});
                        }
                      },
                      child: Icon(
                        constants.typeFilterIcon,
                        size: 16,
                        color: storage != null &&
                                storage!
                                    .getFeatureFilter(FeatureFilterInst.map)
                                    .doesFilterType()
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    FloatingActionButton(
                      heroTag: 'fab-filter-people',
                      tooltip: I18N.of(context).filterByOwner,
                      elevation: 0,
                      mini: true,
                      onPressed: () async {
                        FeatureFilter f =
                            storage!.getFeatureFilter(FeatureFilterInst.map);
                        bool changed = await f.setUsers(
                            context: context,
                            users: storage!.users,
                            myId: storage!.serverSettings!.id);
                        if (changed) {
                          await storage!
                              .setFeatureFilter(FeatureFilterInst.map, f);
                          setState(() {});
                        }
                      },
                      child: Icon(
                        Icons.people,
                        size: 16,
                        color: storage != null &&
                                storage!
                                    .getFeatureFilter(FeatureFilterInst.map)
                                    .doesFilterUsers(storage!.users.keys)
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    FloatingActionButton(
                      heroTag: 'fab-filter-category',
                      tooltip: I18N.of(context).filterByCategory,
                      elevation: 0,
                      mini: true,
                      onPressed: () async {
                        FeatureFilter f =
                            storage!.getFeatureFilter(FeatureFilterInst.map);
                        bool changed = await f.setCategories(context: context);
                        if (changed) {
                          await storage!
                              .setFeatureFilter(FeatureFilterInst.map, f);
                          setState(() {});
                        }
                      },
                      child: Icon(
                        Icons.category,
                        size: 16,
                        color: storage != null &&
                                storage!
                                    .getFeatureFilter(FeatureFilterInst.map)
                                    .doesFilterCategories()
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    FloatingActionButton(
                      heroTag: 'fab-filter-attributes',
                      tooltip: I18N.of(context).filterByAttributes,
                      elevation: 0,
                      mini: true,
                      onPressed: () async {
                        FeatureFilter f =
                            storage!.getFeatureFilter(FeatureFilterInst.map);
                        bool changed = await f.setAttributes(context: context);
                        if (changed) {
                          await storage!
                              .setFeatureFilter(FeatureFilterInst.map, f);
                          setState(() {});
                        }
                      },
                      child: Icon(
                        Icons.edit_attributes,
                        size: 16,
                        color: storage != null &&
                                storage!
                                    .getFeatureFilter(FeatureFilterInst.map)
                                    .doesFilterAttributes()
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    FloatingActionButton(
                      heroTag: 'fab-filter-editState',
                      tooltip: I18N.of(context).filterByEditState,
                      elevation: 0,
                      mini: true,
                      onPressed: () async {
                        FeatureFilter f =
                            storage!.getFeatureFilter(FeatureFilterInst.map);
                        bool changed = await f.setEditState(context: context);
                        if (changed) {
                          await storage!
                              .setFeatureFilter(FeatureFilterInst.map, f);
                          setState(() {});
                        }
                      },
                      child: Icon(
                        Icons.edit,
                        size: 16,
                        color: storage != null &&
                                storage!
                                    .getFeatureFilter(FeatureFilterInst.map)
                                    .doesFilterEditState()
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    FloatingActionButton(
                      heroTag: 'fab-filter-search',
                      tooltip: I18N.of(context).filterByText,
                      elevation: 0,
                      mini: true,
                      onPressed: () {
                        setState(() {
                          onToggleFilterSearch();
                        });
                      },
                      child: Icon(
                        Icons.search,
                        size: 16,
                        color: storage != null &&
                                storage!
                                    .getFeatureFilter(FeatureFilterInst.map)
                                    .doesFilterSearch()
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    FloatingActionButton(
                      heroTag: 'fab-filter-clear',
                      tooltip: I18N.of(context).clearFilter,
                      elevation: 0,
                      mini: true,
                      onPressed: () async {
                        FeatureFilter f = FeatureFilter.empty();
                        f.users = Set.of(storage!.users.keys);
                        f.categories = Set.of(PointCategory.allCategories);
                        await storage!
                            .setFeatureFilter(FeatureFilterInst.map, f);
                        setState(() {});
                      },
                      child: const Icon(
                        Icons.clear,
                        size: 16,
                      ),
                    )
                  ]),
      ),
    );
  }

  Widget createPolyEditingChip() {
    return Container(
      alignment: Alignment.bottomCenter,
      child: ActionChip(
        label: Text(I18N.of(context).creatingPath),
        tooltip: I18N.of(context).help,
        avatar: const Icon(Icons.help),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        onPressed: () {
          showDialog(
              context: context,
              builder: (context) => SimpleDialog(
                      title: Text(I18N.of(context).creatingPath),
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 0, horizontal: 24),
                          title: Text(
                              I18N.of(context).creatingPathHelpAddingNodes),
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 0, horizontal: 24),
                          leading: const Icon(Icons.adjust),
                          title: Text(I18N.of(context).creatingPathHelpNodes),
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 0, horizontal: 24),
                          leading: const Icon(Icons.filter_tilt_shift),
                          title:
                              Text(I18N.of(context).creatingPathHelpMidpoints),
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 0, horizontal: 24),
                          leading: const Icon(Icons.all_inclusive),
                          title:
                              Text(I18N.of(context).creatingPathHelpClosePath),
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 0, horizontal: 24),
                          leading: const Icon(Icons.settings),
                          title:
                              Text(I18N.of(context).creatingPathHelpSettings),
                        ),
                        TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(I18N.of(context).dismiss))
                      ]));
        },
      ),
    );
  }

  Widget createPolyEditingControls(BuildContext context) {
    return Container(
      alignment: Alignment.bottomRight,
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        alignment: WrapAlignment.start,
        direction: Axis.vertical,
        crossAxisAlignment: WrapCrossAlignment.center,
        runAlignment: WrapAlignment.end,
        spacing: 10,
        children: <Widget>[
          FloatingActionButton(
            heroTag: 'fab-close-path',
            tooltip: I18N.of(context).closePath,
            elevation: 0,
            onPressed: () => setState(() {
              editedPoly.closed = !editedPoly.closed;
            }),
            child: Icon(
              Icons.all_inclusive,
              size: 30,
              color: editedPoly.closed
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          FloatingActionButton(
            heroTag: 'fab-path-settings',
            tooltip: I18N.of(context).pathSettings,
            elevation: 0,
            onPressed: onEditPolySettings,
            child: const Icon(
              Icons.settings,
              size: 30,
            ),
          ),
          FloatingActionButton(
            heroTag: 'fab-path-cancel',
            tooltip: I18N.of(context).dialogCancel,
            elevation: 0,
            onPressed: () => setState(() {
              polyEditing = false;
              editedPoly.copyFrom(utils.EditedPoly.fresh());
            }),
            child: const Icon(
              Icons.clear,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget createFilterSearch(BuildContext context) {
    return Dismissible(
        key: const Key('filterSearchDismissible'),
        onDismissed: (DismissDirection dd) {
          setState(() {
            onToggleFilterSearch();
          });
        },
        resizeDuration: null,
        child: Card(
            child: Container(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
                icon: const Icon(Icons.search),
                suffixIcon: searchController!.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: searchController!.clear,
                        icon: const Icon(Icons.clear),
                        tooltip: I18N.of(context).clearButtonTooltip,
                      )),
            controller: searchController!,
          ),
        )));
  }

  Widget createBottomBar(BuildContext context) {
    TextStyle ts = const TextStyle(fontFamily: 'monospace');
    return BottomAppBar(
      //color: Theme.of(context).colorScheme.primaryVariant,
      child: Padding(
          padding: const EdgeInsets.all(0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                flex: 0,
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  children: <TableRow>[
                    TableRow(children: <Widget>[
                      Container(),
                      Container(
                          alignment: Alignment.center,
                          child: Text(
                            'GPS',
                            style: ts,
                          )),
                      Container(
                        alignment: Alignment.center,
                        child: Text(
                          'TGT',
                          style: ts,
                        ),
                      )
                    ]),
                    TableRow(children: <Widget>[
                      Container(
                        padding: const EdgeInsets.only(right: 1),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Lat',
                          style: ts,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 1),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          currentLocation == null
                              ? '-'
                              : currentLocation!.latitude
                                  .toStringAsPrecision(8),
                          style: ts,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 1),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          !mapReady
                              ? '-'
                              : mapController.center.latitude
                                  .toStringAsPrecision(8),
                          style: ts,
                        ),
                      ),
                    ]),
                    TableRow(children: <Widget>[
                      Container(
                        padding: const EdgeInsets.only(right: 1),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Lng',
                          style: ts,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 1),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          currentLocation == null
                              ? '-'
                              : currentLocation!.longitude
                                  .toStringAsPrecision(8),
                          style: ts,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 1),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          !mapReady
                              ? '-'
                              : mapController.center.longitude
                                  .toStringAsPrecision(8),
                          style: ts,
                        ),
                      ),
                    ])
                  ],
                ),
              ),
              Expanded(
                flex: 0,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: I18N.of(context).locationContinuousButtonTooltip,
                      icon: Icon(locationSubscription == null
                          ? Icons.location_off
                          : Icons.location_on),
                      iconSize: 30.0,
                      onPressed: onToggleLocationContinuous,
                    ),
                    GestureDetector(
                        onDoubleTap: currentLocation == null
                            ? null
                            : () => onLockViewToLocation(true),
                        child: IconButton(
                          tooltip:
                              I18N.of(context).lockViewToLocationButtonTooltip,
                          icon: Icon(viewLockedToLocation
                              ? Icons.gps_fixed
                              : Icons.gps_not_fixed),
                          iconSize: 30.0,
                          onPressed: currentLocation == null
                              ? null
                              : () => onLockViewToLocation(false),
                        )),
                  ],
                ),
              ),
            ],
          )),
    );
  }

  void onLockViewToLocation(bool zoom) {
    setState(() {
      viewLockedToLocation = !viewLockedToLocation;
      if (viewLockedToLocation) {
        mapController.move(
            currentLocation!,
            zoom
                ? (storage?.mapState?.zoomMax ?? fallbackMaxZoom).toDouble()
                : mapController.zoom);
      }
    });
  }

  void onZoom(int amount) {
    developer.log(
        'min zoom: ${(storage?.serverSettings?.minZoom ?? fallbackMinZoom)}');
    developer
        .log('max zoom: ${(storage?.mapState?.zoomMax ?? fallbackMaxZoom)}');
    if (!mapReady) {
      return;
    }
    developer.log('zoom before: ${mapController.zoom}');
    if (mapReady) {
      setState(() {
        mapController.move(mapController.center, mapController.zoom + amount);
      });
    }
    developer.log('zoom after: ${mapController.zoom}');
  }

  void onMapEvent(MapEvent evt) {
    //developer.log('onMapEvent: $evt');
    setState(() {});
    if (evt is MapEventWithMove || evt is MapEventMoveEnd) {
      mapStateStorageController.add(evt);
    }
  }

  void onMapEventStorage(MapEvent evt) async {
    //developer.log('onMapEventStorage: $evt');
    if (evt is MapEventWithMove) {
      if (mapReady && evt.targetCenter != currentLocation) {
        viewLockedToLocation = false;
      }
    }
    if (storage?.mapState != null) {
      if (evt is MapEventWithMove) {
        await storage!.setMapState(storage!.mapState!
            .from(center: evt.targetCenter, zoom: evt.targetZoom.round()));
      } else {
        await storage!.setMapState(storage!.mapState!
            .from(center: evt.center, zoom: evt.zoom.round()));
      }
    }
  }

  void onToggleFilterSearch({bool disable = false}) {
    if (searchController == null && !disable) {
      TextEditingController controller = TextEditingController();
      FeatureFilter filter = storage!.getFeatureFilter(FeatureFilterInst.map);
      controller.text = filter.searchTerm;
      controller.addListener(() {
        setState(() {
          FeatureFilter filter =
              storage!.getFeatureFilter(FeatureFilterInst.map);
          filter.searchTerm = controller.text;
          storage!.setFeatureFilter(FeatureFilterInst.featureList, filter);
        });
      });
      searchController = controller;
    } else if (searchController != null) {
      TextEditingController controller = searchController!;
      setState(() {
        searchController = null;
      });
      controller.dispose();
    }
  }

  void onStartPolyEdit([data.Poly? source]) {
    setState(() {
      if (source != null) {
        editedPolySourceFeature = source.id;
        editedPoly.copyFrom(utils.EditedPoly.fresh(
            color: source.color,
            colorFill: source.colorFill,
            closed: source.polygon,
            coords: List.of(source.coords)));
      }
      infoTarget = null;
      navigationTarget = utils.Target.none;
      polyEditing = true;
    });
  }

  void onEditPolySettings() async {
    if (storage == null) {
      utils.notifySnackbar(
          context, 'No storage!', utils.NotificationLevel.error);
    }
    Poly? sourcePoly;
    if (editedPolySourceFeature != null) {
      sourcePoly = storage!.featuresMap[editedPolySourceFeature!]!.asPoly();
    }
    var res = await Navigator.of(context).push(MaterialPageRoute(
        builder: (context) =>
            EditPoly(editedPoly: editedPoly, source: sourcePoly)));
    developer.log('$res');
    if (res is utils.EditedPoly) {
      setState(() {
        editedPoly.copyFrom(res);
      });
      return;
    }
    Poly poly = res as Poly;
    if (editedPolySourceFeature == null) {
      poly.id = await storage!.nextLocalId();
    }
    await storage!.upsertFeature(poly);
    if (context.mounted && editedPolySourceFeature == null) {
      utils.notifySnackbar(context, I18N.of(context).polyCreated,
          utils.NotificationLevel.success);
    }
    setState(() {
      if (navigationTarget.isNotNone) {
        if (sourcePoly != null && navigationTarget.isSameFeature(sourcePoly)) {
          int idx = sourcePoly.coords.indexOf(navigationTarget.coords);
          if (idx != -1 && poly.coords.length > idx) {
            navigationTarget = utils.Target(poly, poly.coords[idx]);
          } else {
            navigationTarget = utils.Target(poly);
          }
        }
      }
      if (infoTarget == sourcePoly) {
        infoTarget = poly;
      }
      editedPolySourceFeature = null;
      polyEditing = false;
      editedPoly.copyFrom(utils.EditedPoly.fresh());
    });
  }

  void onToggleLocationContinuous() async {
    if (locationSubscription == null) {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          if (context.mounted) {
            utils.notifySnackbar(context, I18N.of(context).noLocationService,
                utils.NotificationLevel.error);
          }
          return;
        }
      }
      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          if (context.mounted) {
            utils.notifySnackbar(
                context,
                I18N.of(context).noLocationPermissions,
                utils.NotificationLevel.error);
          }
          return;
        }
      }

      locationSubscription =
          location.onLocationChanged.listen((LocationData loc) {
        developer.log('Continuous location: ${loc.latitude} ${loc.longitude}');
        setState(() {
          currentLocation = LatLng(loc.latitude!, loc.longitude!);
          onCurrentLocation();
        });
      });
      compassSubscription = FlutterCompass.events!.listen((CompassEvent evt) {
        setState(() {
          currentHeading = math.pi * evt.heading! / 180.0;
        });
      });
      developer.log('Compass subscription: $compassSubscription');
    } else {
      locationSubscription!.cancel();
      setState(() {
        locationSubscription = null;
      });
      compassSubscription!.cancel();
      compassSubscription = null;
    }
  }

  void onCurrentLocation() {
    developer.log('onCurrentLocation');
    if (viewLockedToLocation) {
      mapController.move(currentLocation!, mapController.zoom);
    }
  }

  void onPair() async {
    data.ServerSettings? settings = await Navigator.of(context).push(
        MaterialPageRoute<data.ServerSettings>(
            builder: (context) => Pairing(scaffoldKey: scaffoldKey)));
    if (context.mounted) {
      Navigator.of(context).pop();
    }
    if (settings == null) {
      developer.log('no settings');
    } else {
      developer.log(settings.toString());
      await storage?.setServerSettings(settings);
      await storage?.setMapState(data.MapState(
          true,
          false,
          storage!.serverSettings!.defaultCenter,
          storage!.serverSettings!.minZoom,
          null,
          null,
          null));
      getIt.get<comm.AppClient>().setUserID(settings.id);
      // TODO with photos?
      bool success = await download(true);
      if (success) {
        if (context.mounted) {
          utils.notifySnackbar(context, I18N.of(context).syncSuccessful,
              utils.NotificationLevel.success);
        }
      }
      setState(() {});
      mapController.move(storage!.serverSettings!.defaultCenter,
          storage!.serverSettings!.minZoom.toDouble());
      startPinging();
    }
  }

  void onPing() async {
    if (storage?.serverSettings?.serverAddress == null) {
      return;
    }
    setState(() {
      pingInProgress = true;
    });
    bool knowsNewVersion =
        pingResponse != null && pingResponse!.appVersion != null;
    var res = await comm.ping(storage!.serverSettings!.serverAddress);
    setState(() {
      pingInProgress = false;
      pingResponse = res;
    });
    if (res != null && res.appVersion != null && !knowsNewVersion) {
      setState(() {
        pinging = false;
      });

      if (context.mounted) {
        await showDialog(
            context: context,
            builder: (context) => AlertDialog(
                    title: Text(I18N.of(context).newVersionNotificationTitle),
                    content: SingleChildScrollView(
                      child: Column(
                        children: [
                          Text(I18N.of(context).newVersionNotificationText(
                              getIt.get<PackageInfo>().version,
                              res.appVersion!.version)),
                          const SizedBox(height: 10),
                          Text(I18N.of(context).newVersionDismissalInfo)
                        ],
                      ),
                    ),
                    actionsAlignment: MainAxisAlignment.spaceBetween,
                    actions: [
                      TextButton(
                          child: Column(children: [
                            Text(I18N
                                .of(context)
                                .newVersionNotificationDownloadButton),
                          ]),
                          onPressed: () async {
                            if (!await launchUrlString(
                                res.appVersion!.address)) {
                              if (context.mounted) {
                                utils.notifyDialog(context, 'TODO', 'TODO',
                                    utils.NotificationLevel.error);
                              }
                            }
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          }),
                      TextButton(
                          child: Text(I18N.of(context).dismiss),
                          onPressed: () => Navigator.of(context).pop())
                    ]));
      }
      startPinging();
    }
  }

  void startPinging() {
    if (storage?.serverSettings == null) {
      developer.log('No settings, cannot start pinging.');
      return;
    }
    if (pinging) {
      return;
    }
    pinging = true;
    Future.doWhile(() async {
      if (storage?.serverSettings == null) {
        return Future.delayed(const Duration(seconds: 5), () => pinging);
      }
      await Future.delayed(const Duration(seconds: 5), onPing);
      return pinging;
    });
  }

  Future<void> onRenderMap(bool render) async {
    developer.log('onRenderMap: $render');
    if (storage?.mapState != null) {
      await storage!.setMapState(storage!.mapState!.from(render: render));
    }
    setState(() {});
  }

  void onUseOffline(bool use) async {
    developer.log('onUseOffline');
    Navigator.of(context).pop();
    if (!use) {
      await offlineMapProvider?.destroy();
      offlineMapProvider = null;
      await storage!.setMapState(storage!.mapState!.from(usingOffline: false));
      setState(() {});
      return;
    }

    var offlineMap = storage!.offlineMap;
    // if there is no map pack, download
    if (!offlineMap.existsSync()) {
      utils.notifySnackbar(
          context, I18N.of(context).downloading, utils.NotificationLevel.info);
      offlineMap.parent.createSync(recursive: true);
      bool indeterminateSet = false;
      await comm.downloadMap(storage!.serverSettings!.serverAddress, offlineMap,
          (read, total) {
        if (total == null) {
          if (!indeterminateSet) {
            indeterminateSet = true;
            setState(() {
              progressValue = -1;
            });
          }
        } else {
          setState(() {
            progressValue = read / total;
            developer.log('download progress: $progressValue');
          });
        }
      });
      setState(() {
        progressValue = null;
      });
      if (context.mounted) {
        utils.notifySnackbar(context, I18N.of(context).downloaded,
            utils.NotificationLevel.success);
      }
    }

    // set
    offlineMapProvider = await MbtilesTileProvider.create(14, offlineMap.path);
    await storage!.setMapState(storage!.mapState!.from(usingOffline: true));
    setState(() {});
  }

  Future<bool> download(bool withPhotos) async {
    bool res = await (withPhotos ? downloadWithPhotos() : downloadBare());
    if (res) {
      setState(() {});
    }
    return res;
  }

  Future<bool> downloadBare() async {
    developer.log('downloadBare');
    late data.ServerData serverData;
    try {
      serverData =
          await comm.downloadData(storage!.serverSettings!.serverAddress);
    } on comm.UnexpectedStatusCode catch (e, stack) {
      developer.log('exception: ${e.toString()}\n$stack');
      await utils.notifyDialog(context, e.getMessage(context), e.detail,
          utils.NotificationLevel.error);
      return false;
    } catch (e, stack) {
      developer.log('exception: ${e.toString()}\n$stack');
      await utils.notifyDialog(context, I18N.of(context).error, e.toString(),
          utils.NotificationLevel.error);
      return false;
    }
    bool usersChanged =
        !setEquals(serverData.users.keys.toSet(), storage!.users.keys.toSet());
    await storage!.setUsers(serverData.users);

    List<Feature> features = storage!.features.where((f) => f.isLocal).toList();
    features.addAll(serverData.features);
    await storage!.setFeatures(features);
    if (usersChanged) {
      var ff = storage!.getFeatureFilter(FeatureFilterInst.featureList);
      ff.users.clear();
      ff.users.addAll(storage!.users.keys);
      await storage!.setFeatureFilter(FeatureFilterInst.featureList, ff);
    }
    await storage!.setProposalsExternal(serverData.proposals);
    return true;
  }

  Future<bool> downloadWithPhotos() async {
    developer.log('downloadWithPhotos');
    var tempDir = storage!.createTempDir();
    var downloadFile = File(join(tempDir.path, 'data.zip'));
    utils.notifySnackbar(
        context, I18N.of(context).downloading, utils.NotificationLevel.info,
        vibrate: false);
    try {
      try {
        bool indeterminateSet = false;
        await comm.downloadDataWithPhotos(
            storage!.serverSettings!.serverAddress, downloadFile,
            (read, total) {
          if (total == null) {
            if (!indeterminateSet) {
              indeterminateSet = true;
              setState(() {
                progressValue = -1;
              });
            }
          } else {
            setState(() {
              progressValue = read / total;
              developer.log('download progress: $progressValue');
            });
          }
        });
      } on comm.UnexpectedStatusCode catch (e, stack) {
        developer.log('exception: ${e.toString()}\n$stack');
        await utils.notifyDialog(context, e.getMessage(context), e.detail,
            utils.NotificationLevel.error);
        return false;
      } catch (e, stack) {
        developer.log('exception: ${e.toString()}\n$stack');
        await utils.notifyDialog(context, I18N.of(context).error, e.toString(),
            utils.NotificationLevel.error);
        return false;
      }

      var unpackDir = tempDir.createTempSync();
      if (context.mounted) {
        utils.notifySnackbar(
            context, I18N.of(context).unpacking, utils.NotificationLevel.info,
            vibrate: false);
      }
      await utils.unzip(downloadFile, unpackDir, (progress) {
        if (progress.isNaN || progress.isInfinite) {
          developer.log('unpack NaN/infinite progress');
          return;
        }
        setState(() {
          progressValue = progress;
          developer.log('unpack progress: $progressValue');
        });
      });

      var dataJson = File(join(unpackDir.path, 'data.json'));
      Map<String, dynamic> dataRaw = jsonDecode(dataJson.readAsStringSync());
      data.ServerData serverData = data.ServerData(dataRaw);

      bool usersChanged = !setEquals(
          serverData.users.keys.toSet(), storage!.users.keys.toSet());
      await storage!.setUsers(serverData.users);
      if (usersChanged) {
        for (FeatureFilterInst ffi in FeatureFilterInst.values) {
          var ff = storage!.getFeatureFilter(ffi);
          ff.users.clear();
          ff.users.addAll(storage!.users.keys);
          await storage!.setFeatureFilter(ffi, ff);
        }
      }

      List<Feature> localFeatures =
          storage!.features.where((f) => f.isLocal).toList();
      List<Feature> features = List.of(localFeatures);
      features.addAll(serverData.features);
      await storage!.setFeatures(features);
      await storage!.setProposalsExternal(serverData.proposals);

      Map<int, int> photo2feature = Map.fromEntries(serverData.features
          .expand((f) => f.photoIDs.map((pid) => MapEntry(pid, f.id))));

      var photos = serverData.photoMetadata.entries
          .where((e) => photo2feature.containsKey(e.value.id))
          .map((e) {
        String photoFilename = e.key;
        data.PhotoMetadata photoMetadata = e.value;
        return FileFeaturePhoto(
            File(join(unpackDir.path, photoMetadata.thumbnailFilename)),
            File(join(unpackDir.path, photoFilename)),
            id: photoMetadata.id,
            thumbnailContentType: photoMetadata.thumbnailContentType,
            contentType: photoMetadata.contentType,
            photoDataSize: photoMetadata.size,
            featureID: photo2feature[photoMetadata.id]!);
      });
      var keep = localFeatures.expand((f) => f.photoIDs).toSet();
      await storage!.setPhotos(photos, keep);
      return true;
    } finally {
      tempDir.deleteSync(recursive: true);
      setState(() {
        progressValue = null;
      });
    }
  }

  Future<void> onDownload(BuildContext ctx) async {
    developer.log('onDownload');
    bool? confirm = await showDialog<bool>(
        context: ctx,
        builder: (context) => AlertDialog(
              title: Text(I18N.of(context).downloadConfirm),
              content: SingleChildScrollView(
                child: Text(I18N.of(context).downloadConfirmDetail),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      child: Text(I18N.of(context).dialogConfirm),
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                    ),
                    TextButton(
                      child: Text(I18N.of(context).dialogCancel),
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                    )
                  ],
                )
              ],
            ));
    if (confirm != true) {
      return;
    }
    // TODO with photos?
    bool success = await download(true);
    if (context.mounted) {
      Navigator.of(context).pop();
      if (success) {
        utils.notifySnackbar(context, I18N.of(context).downloaded,
            utils.NotificationLevel.success);
      }
    }
    setState(() {
      infoTarget = null;
    });
  }

  Future<bool> upload() async {
    developer.log('upload');
    var created = storage!.features
        .where((data.Feature f) => f.isLocal)
        .toList(growable: false);
    var edited = storage!.features
        .where((data.Feature f) => f.isEdited)
        .toList(growable: false);
    var deleted = storage!.features
        .where((data.Feature f) => f.deleted)
        .toList(growable: false);
    var proposals = await storage!.getProposals(local: true);
    var createdPhotos = <int, List<data.FeaturePhoto>>{};
    for (var f in created) {
      if (f.photoIDs.isEmpty) {
        continue;
      }
      createdPhotos[f.id] = await storage!.getPhotos(f.id);
    }
    var addedPhotos = <int, List<data.FeaturePhoto>>{};
    for (var f in edited) {
      var addedPhotoIDs = f.photoIDs.difference(f.origPhotoIDs);
      if (addedPhotoIDs.isEmpty) {
        continue;
      }
      addedPhotos[f.id] = await storage!.getPhotosByID(addedPhotoIDs);
    }
    List<int> deletedPhotoIDs = storage!.features
        .expand((data.Feature f) => f.origPhotoIDs.difference(f.photoIDs))
        .toList(growable: false);
    try {
      await comm.uploadData(
        serverAddress: storage!.serverSettings!.serverAddress,
        created: created,
        edited: edited,
        deleted: deleted,
        proposals: proposals,
        createdPhotos: createdPhotos,
        addedPhotos: addedPhotos,
        deletedPhotoIDs: deletedPhotoIDs,
      );
    } on comm.DetailedCommException catch (e, stack) {
      developer.log('exception: ${e.toString()}\n$stack');
      if (context.mounted) {
        await utils.notifyDialog(context, e.getMessage(context), e.detail,
            utils.NotificationLevel.error);
      }
      return false;
    } catch (e, stack) {
      developer.log('exception: ${e.toString()}\n$stack');
      if (context.mounted) {
        utils.notifySnackbar(context, I18N.of(context).serverUnavailable,
            utils.NotificationLevel.error);
      }
      return false;
    }
    storage!.clearProposals();
    return true;
  }

  FutureOr<void> onUpload() async {
    developer.log('onUpload');
    bool success = await upload();
    if (context.mounted) {
      Navigator.of(context).pop();
      if (success) {
        utils.notifySnackbar(context, I18N.of(context).syncSuccessful,
            utils.NotificationLevel.success);
      }
    }
    setState(() {});
  }

  Future<void> onSync() async {
    developer.log('onSync');
    Navigator.of(context).pop();
    if (!await upload()) {
      return;
    }
    await storage!.setFeatures([]);
    // TODO with photos?
    if (!await download(true)) {
      return;
    }
    setState(() {
      infoTarget = null;
    });

    if (!mounted) return;
    utils.notifySnackbar(context, I18N.of(context).syncSuccessful,
        utils.NotificationLevel.success);
  }

  void onLogPoint(utils.PointLogType type) async {
    developer.log('Log poi $type');
    LatLng loc = mapController.center;
    if (type == utils.PointLogType.currentLocation && currentLocation != null) {
      loc = currentLocation!;
    }
    data.Point? point = await Navigator.of(context).push(
        MaterialPageRoute<data.Point>(
            builder: (context) => EditPoint(
                myId: storage!.serverSettings!.id,
                targetLocation: loc,
                users: storage!.users)));
    if (point == null) {
      return;
    }
    if (context.mounted) {
      Navigator.pop(context);
    }
    point.id = await storage!.nextLocalId();
    await storage!.upsertFeature(point);
    setState(() {});
    if (context.mounted) {
      if (storage!.getFeatureFilter(FeatureFilterInst.map).passes(point)) {
        utils.notifySnackbar(context, I18N.of(context).pointCreated,
            utils.NotificationLevel.success);
      } else {
        utils.notifySnackbar(context, I18N.of(context).pointCreatedFiltered,
            utils.NotificationLevel.success);
      }
    }
  }

  void onEditPoint(data.Point point) async {
    developer.log('Edit poi $point');
    data.Point? replacement = await Navigator.of(context).push(
        MaterialPageRoute<data.Point>(
            builder: (context) => EditPoint(
                point: point,
                myId: storage!.serverSettings!.id,
                targetLocation: storage!.mapState!.center,
                users: storage!.users)));
    if (replacement == null) {
      return;
    }
    await storage!.upsertFeature(replacement);
    setState(() {
      if (infoTarget == point) {
        infoTarget = storage!.featuresMap[point.id]!.asPoint();
      }
      if (navigationTarget.isSameFeature(point)) {
        navigationTarget = utils.Target(replacement);
      }
    });
  }

  void onMapTap(TapPosition tapPosition, LatLng coords) {
    developer.log('onMapTap: $coords');
    setState(() {
      if (polyEditing) {
        onToggleFilterSearch(disable: true);
        editedPoly.coords.add(utils.ReferencedLatLng.latLng(coords));
        return;
      }
      for (Feature f in storage!.features) {
        if (!f.isPoly() || !f.asPoly().polygon) {
          continue;
        }
        if (utils.geodesy.isGeoPointInPolygon(coords, f.asPoly().coords)) {
          infoTarget = f;
          return;
        }
      }
      if (searchController != null) {
        onToggleFilterSearch();
      } else {
        infoTarget = null;
      }
    });
  }

  void onPointListTap() async {
    if (storage == null) {
      utils.notifySnackbar(
          context, 'No storage!', utils.NotificationLevel.error);
      Navigator.of(context).pop();
    }
    data.Feature? selected = await Navigator.of(context).push(
        MaterialPageRoute<data.Feature>(
            builder: (context) => const FeatureList()));
    if (selected == null) {
      setState(() {});
      return;
    }
    setState(() {
      infoTarget = selected;
    });
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void onUserListTap() {
    if (storage == null) {
      utils.notifySnackbar(
          context, 'No storage!', utils.NotificationLevel.error);
      Navigator.of(context).pop();
    }
    List<MapEntry<int, String>> users = Map.of(storage!.users).entries.toList();
    users.sort((a, b) {
      if (a.key == 0 && b.key != 0) {
        return 1;
      }
      if (a.key != 0 && b.key == 0) {
        return -1;
      }
      return a.key - b.key;
    });
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              actionsAlignment: MainAxisAlignment.center,
              title: Text(I18N.of(context).userListTitle),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  children: users
                      .map((e) => Text(
                          '\u2022 ${e.value} <ID: ${e.key}> ${e.key == storage!.serverSettings?.id ? ' (${I18N.of(context).me})' : ''}'))
                      .toList(growable: false),
                ),
              ),
              actions: [
                TextButton(
                    child: Text(I18N.of(context).close),
                    onPressed: () => Navigator.of(context).pop())
              ],
            ));
  }

  void onPointTap(data.Point point) {
    developer.log('Point ${point.name} (ID ${point.id}) tap.');
    setState(() {
      if (polyEditing) {
        editedPoly.coords.add(utils.ReferencedLatLng.fromPoint(point));
        return;
      }
      if (infoTarget == point) {
        infoTarget = null;
      } else {
        infoTarget = point;
      }
    });
  }

  void onPointLongPress(data.Point point) {
    developer.log('Poi ${point.name} long press.');
    if (!polyEditing) {
      toggleNavigation(point.coords, point);
    }
  }

  void onPolylineTap(data.Poly polyline) {
    developer.log('LineString ${polyline.name} (ID ${polyline.id}) tap.');
    setState(() {
      infoTarget = polyline;
    });
  }

  void onInfoDistanceTap() {
    developer.log('onInfoDistanceTap');
    setState(() {
      infoTarget = navigationTarget.feature;
    });
  }

  void onDeleteFeature(data.Feature toDelete) async {
    developer.log('onDeleteFeature');
    if (toDelete.isLocal) {
      bool confirmed = await pointDataConfirm(
          (context) => I18N.of(context).aboutToDeleteLocalFeature, toDelete);
      if (!confirmed) {
        return;
      }
      await storage!.removeFeature(toDelete.id);
    } else {
      var replacement = toDelete.copy();
      replacement.deleted = true;
      await storage!.upsertFeature(replacement);
    }
    data.Feature? r = storage!.featuresMap[toDelete.id];
    if (infoTarget == toDelete) {
      if (r != null) {
        infoTarget = r;
      } else {
        infoTarget = null;
      }
    }
    if (navigationTarget.isNotNone &&
        navigationTarget.isSameFeature(toDelete)) {
      if (r != null) {
        assert(r.isPoint());
        navigationTarget = utils.Target(r.asPoint());
      } else {
        navigationTarget = utils.Target.none;
      }
    }
    setState(() {});
  }

  void onUndeleteFeature(data.Feature toUndelete) async {
    var replacement = toUndelete.copy();
    replacement.deleted = false;
    await storage!.upsertFeature(replacement);
    data.Feature? r = storage!.featuresMap[toUndelete.id];
    if (infoTarget == toUndelete) {
      assert(r != null);
      infoTarget = r;
    }
    if (navigationTarget.isNotNone &&
        navigationTarget.isSameFeature(toUndelete)) {
      assert(r != null && r.isPoint());
      navigationTarget = utils.Target(r!.asPoint());
    }
    setState(() {});
  }

  void onRevertFeature(data.Feature toRevert) async {
    bool confirmed = await pointDataConfirm(
        (context) => I18N.of(context).aboutToRevertGlobalFeature, toRevert);
    if (!confirmed) {
      return;
    }
    var replacement = toRevert.copy();
    //await storage!.delete
    replacement.revert();
    await storage!.upsertFeature(replacement);
    if (infoTarget == toRevert) {
      data.Feature? r = storage!.featuresMap[toRevert.id];
      assert(r != null);
      infoTarget = r;
    }
    setState(() {});
  }

  void onOpenGallery(data.Feature feature) async {
    developer.log('onOpenGallery $feature');
    if (storage == null) {
      utils.notifySnackbar(
          context, 'TODO no storage', utils.NotificationLevel.error);
      return;
    }
    data.Point? replacement = await Navigator.of(context).push(
        MaterialPageRoute<data.Point>(
            builder: (context) =>
                Gallery(storage: storage!, feature: feature, editable: true)));
    if (replacement == null) {
      return;
    }
    await storage!.upsertFeature(replacement);
    setState(() {});
    if (infoTarget == feature) {
      setState(() {
        infoTarget = storage!.featuresMap[feature.id]!;
      });
    }
  }

  void onProposeImprovement() async {
    List<data.Proposal> externalProposals =
        await storage!.getProposals(external: true);
    List<data.Proposal> localProposals =
        await storage!.getProposals(local: true);
    if (!context.mounted) {
      return;
    }
    data.Proposal? proposal =
        await Navigator.of(context).push(MaterialPageRoute<data.Proposal>(
            builder: (context) => CreateProposal(
                  users: storage!.users,
                  externalProposals: externalProposals,
                  localProposals: localProposals,
                )));
    if (proposal == null) {
      return;
    }
    await storage!.addProposal(Proposal(
        storage!.serverSettings!.id, proposal.description, proposal.how));

    if (!mounted) return;
    Navigator.pop(context);
    setState(() {});
    utils.notifySnackbar(context, I18N.of(context).suggestionSaved,
        utils.NotificationLevel.info);
  }

  void onReset() async {
    bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(I18N.of(context).resetConfirm),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      child: Text(I18N.of(context).dialogConfirm),
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                    ),
                    TextButton(
                      child: Text(I18N.of(context).dialogCancel),
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                    )
                  ],
                )
              ],
            ));
    if (confirm != true) {
      return;
    }
    developer.log('Resetting app.');
    if (storage == null) {
      developer.log('No storage - nothing to reset.');
      return;
    }
    storage = await Storage.getInstance(reset: true);
    infoTarget = null;
    progressValue = null;
    getIt.get<comm.AppClient>().unsetUserID();
    setState(() {});
    if (!mounted) return;
    Navigator.of(context).pop();
    utils.notifySnackbar(
        context, I18N.of(context).resetDone, utils.NotificationLevel.info);
  }

  Future<bool> pointDataConfirm(
      String Function(BuildContext) question, data.Feature feature) async {
    return await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
            title: Text(question(context)),
            content: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(feature.name),
                      subtitle: Text(I18N.of(context).nameLabel),
                    ),
                    ListTile(
                        title: Text(storage?.users[feature.ownerId] ??
                            '<unknown ID: ${feature.ownerId}>'),
                        subtitle: Text(I18N.of(context).owner)),
                    if (feature.isPoint())
                      ListTile(
                        title: Text(
                            utils.formatCoords(feature.asPoint().coords, true)),
                        subtitle: Text(I18N.of(context).position),
                      ),
                    if (feature.description?.isNotEmpty ?? false)
                      ListTile(
                        title: Text(feature.description!),
                        subtitle: Text(I18N.of(context).descriptionLabel),
                      ),
                    if (feature.isPoint())
                      ListTile(
                          title: Text(I18N
                              .of(context)
                              .category(feature.asPoint().category)),
                          subtitle: Text(I18N.of(context).categoryTitle),
                          trailing: Icon(feature.asPoint().category.iconData)),
                    if (feature.isPoint())
                      ListTile(
                          title: feature.asPoint().attributes.isEmpty
                              ? Text(I18N.of(context).noAttributes)
                              : Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: feature
                                      .asPoint()
                                      .attributes
                                      .map((attr) => Tooltip(
                                            message: I18N
                                                .of(context)
                                                .attribute(attr),
                                            child: Icon(attr.iconData),
                                          ))
                                      .toList(growable: false),
                                ),
                          subtitle: Text(I18N.of(context).attributes)),
                    if (feature.deadline != null)
                      ListTile(
                        title: Text(I18N
                            .of(context)
                            .dateFormat
                            .format(feature.deadline!)),
                        subtitle: Text(I18N.of(context).deadline),
                      ),
                  ],
                ))),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              TextButton(
                child: Text(I18N.of(context).yes.toUpperCase()),
                onPressed: () => Navigator.of(context).pop(true),
              ),
              TextButton(
                child: Text(I18N.of(context).no.toUpperCase()),
                onPressed: () => Navigator.of(context).pop(false),
              )
            ],
          );
        });
  }

  void onCenterView(data.Feature feature, bool zoom) {
    mapController.move(
        feature.center(),
        zoom
            ? (storage?.mapState?.zoomMax ?? fallbackMaxZoom).toDouble()
            : mapController.zoom);
  }

  void toggleNavigation(LatLng coords, data.Feature f) {
    setState(() {
      if (navigationTarget.isNotNone && navigationTarget.isSameFeature(f)) {
        navigationTarget = utils.Target.none;
      } else {
        navigationTarget = utils.Target(f, coords);
      }
    });
  }

  Future<LatLng?> getPolyCoords(Poly p) async {
    LatLng? res = await showDialog<LatLng>(
        context: context, builder: (context) => PolyNavPointChooser(poly: p));
    developer.log('getPolyCoords = $res');
    return res;
  }
}
