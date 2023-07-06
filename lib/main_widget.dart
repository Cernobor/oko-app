import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:get_it/get_it.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:oko/communication.dart' as comm;
import 'package:oko/data.dart' as data;
import 'package:oko/data.dart';
import 'package:oko/i18n.dart';
import 'package:oko/main.dart';
import 'package:oko/map.dart';
import 'package:oko/storage.dart';
import 'package:oko/subpages/edit_point.dart';
import 'package:oko/subpages/gallery.dart';
import 'package:oko/subpages/pairing.dart';
import 'package:oko/subpages/point_list.dart';
import 'package:oko/subpages/proposal.dart';
import 'package:oko/utils.dart' as utils;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' show join;
import 'package:rxdart/rxdart.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' hide Theme;

import 'mbtiles.dart';

GetIt getIt = GetIt.instance;

enum PointLogType { currentLocation, crosshair }

class Target {
  final data.Point? _point;

  static final Target _none = Target._(null);

  Target._(this._point);

  Target(data.Point p) : _point = p;

  static Target none() {
    return _none;
  }

  data.Point get point => _point!;

  bool get isSet => _point != null;

  LatLng get coords => _point!.coords;

  bool isSamePoint(data.Point p) {
    return identical(_point, p);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Target &&
          runtimeType == other.runtimeType &&
          _point == other._point;

  @override
  int get hashCode => _point.hashCode;
}

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
  final MapControllerImpl mapController = MapControllerImpl();
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
  Target infoTarget = Target.none();
  Target navigationTarget = Target.none();
  bool poiListExpanded = false;

  // settings
  Storage? storage;

  Future<dynamic>? initResult;

  @override
  void initState() {
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
            enabled: storage?.serverSettings != null,
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
            onTap: () => onLogPoint(PointLogType.currentLocation),
            enabled: storage?.serverSettings != null && currentLocation != null,
          ),
          // log on crosshair
          ListTile(
            title: Text(I18N.of(context).logPoiCrosshair),
            leading: const Icon(Icons.add_location_alt_outlined),
            trailing: const Icon(Icons.add),
            onTap: () => onLogPoint(PointLogType.crosshair),
            enabled: storage?.serverSettings != null,
          ),
          // point list
          ListTile(
            title: Text(I18N.of(context).poiListTitle),
            leading: const Icon(Icons.place),
            trailing: const Icon(Icons.arrow_forward),
            onTap: onPointListTap,
            enabled: storage?.serverSettings != null,
          ),
          // user list
          ListTile(
            title: Text(I18N.of(context).userListTitle),
            subtitle: Text(I18N.of(context).infoOnly),
            leading: const Icon(Icons.people),
            onTap: onUserListTap,
            enabled: storage?.serverSettings != null,
          ),
          ListTile(
            title: Text(I18N.of(context).proposeImprovement),
            leading: const Icon(Icons.settings_suggest),
            onTap: onProposeImprovement,
            enabled: storage?.serverSettings != null,
          ),
          ListTile(
            title: Text(I18N.of(context).reset),
            subtitle: Text(I18N.of(context).resetInfo),
            leading: const Icon(Icons.warning),
            onLongPress: onReset,
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
    return Stack(
      children: <Widget>[
        createMap(context),
        if (navigationTarget.isSet && currentLocation != null)
          Container(
            alignment: Alignment.bottomCenter,
            constraints: const BoxConstraints.expand(),
            child: createInfoContentDistance(context),
          ),
        if (infoTarget.isSet)
          Container(
            alignment: Alignment.bottomCenter,
            constraints: const BoxConstraints.expand(),
            child: createInfoContentFull(context),
          ),
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
        Container(
          alignment: Alignment.topRight,
          padding: const EdgeInsets.all(8.0),
          child: createMapControls(context),
        )
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
    // limits
    children.add(PolylineLayer(
        polylines: storage?.mapState?.hasPanLimits ?? false
            ? <Polyline>[
                Polyline(points: <LatLng>[
                  LatLng(storage!.mapState!.swBound!.latitude,
                      storage!.mapState!.swBound!.longitude),
                  LatLng(storage!.mapState!.swBound!.latitude,
                      storage!.mapState!.neBound!.longitude),
                  LatLng(storage!.mapState!.neBound!.latitude,
                      storage!.mapState!.neBound!.longitude),
                  LatLng(storage!.mapState!.neBound!.latitude,
                      storage!.mapState!.swBound!.longitude),
                ], strokeWidth: 5, color: Colors.red),
              ]
            : []));
    // line to target
    if (currentLocation != null && navigationTarget.isSet) {
      children.add(PolylineLayer(polylines: <Polyline>[
        Polyline(points: <LatLng>[
          currentLocation!,
          navigationTarget.coords,
        ], strokeWidth: 5, color: Colors.blue),
      ]));
    }
    // current location
    if (currentLocation != null) {
      children.add(MarkerLayer(markers: [
        Marker(
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
            })
      ]));
    }
    // extra geometry
    children.addAll(createGeometry());
    // Points
    children.add(MarkerLayer(markers: createMarkers()));

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
    return storage!.features.whereType<data.Point>().map((data.Point point) {
      var baseSize = 35.0;
      var badgeSize = 12.0;
      var width = baseSize * (infoTarget.isSamePoint(point) ? 1.5 : 1);
      var height = baseSize * (infoTarget.isSamePoint(point) ? 1.5 : 1);
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
                      size:
                          baseSize * (infoTarget.isSamePoint(point) ? 1.5 : 1),
                      color: point.color,
                    ),
                    if (point.isLocal)
                      Align(
                        alignment: const Alignment(1, -1),
                        child: Icon(Icons.star,
                            size: badgeSize *
                                (infoTarget.isSamePoint(point) ? 1.5 : 1),
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    if (point.isEdited)
                      Align(
                        alignment: const Alignment(1, -1),
                        child: Icon(Icons.edit,
                            size: badgeSize *
                                (infoTarget.isSamePoint(point) ? 1.5 : 1),
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    if (point.deleted)
                      Align(
                        alignment: point.isEdited
                            ? const Alignment(1, 0)
                            : const Alignment(1, -1),
                        child: Icon(Icons.delete,
                            size: badgeSize *
                                (infoTarget.isSamePoint(point) ? 1.5 : 1),
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    if (point.ownerId == 0)
                      Align(
                        alignment: const Alignment(1, -1),
                        child: Icon(Icons.lock,
                            size: badgeSize *
                                (infoTarget.isSamePoint(point) ? 1.5 : 1),
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    for (var attr in point.attributes)
                      Align(
                        alignment: Alignment(attr.xAlign, attr.yAlign),
                        child: Icon(attr.iconData,
                            size: badgeSize *
                                (infoTarget.isSamePoint(point) ? 1.5 : 1),
                            color: attr.color),
                      )
                  ],
                ))),
      );
    }).toList();
  }

  List<Widget> createGeometry() {
    if (storage == null) {
      return [];
    }
    return [
      PolylineLayer(
          polylines: storage!.features
              .whereType<data.LineString>()
              .map((data.LineString ls) =>
                  Polyline(points: ls.coords, color: extraGeometryColor))
              .toList(growable: false)),
      /*PolygonLayerOptions(
          polygons: grp.polygons
              .map((p) => Polygon(
                    points: p.boundary,
                    holePointsList: p.holes,
                    color: extraGeometryColor,
                  ))
              .toList(growable: false))*/
    ];
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
    bool isNavigating = navigationTarget.isSet &&
        currentLocation != null &&
        navigationTarget == infoTarget;
    String distStr = '', brgStr = '', relBrgStr = '';
    if (isNavigating) {
      utils.NavigationData nav = utils.NavigationData.compute(
          currentLocation!, navigationTarget.coords, currentHeading);
      distStr = '${I18N.of(context).distance}: ${nav.distanceM} m';
      brgStr =
          '${I18N.of(context).bearing}: ${nav.bearingDeg.toStringAsFixed(1)}°';
      relBrgStr =
          '${I18N.of(context).relativeBearing}: ${nav.relativeBearingDeg == null ? '-' : nav.relativeBearingDeg!.toStringAsFixed(1)}°';
    }
    return Dismissible(
        key: const Key('fullInfoDismissible'),
        onDismissed: (DismissDirection dd) {
          setState(() {
            infoTarget = Target.none();
          });
        },
        resizeDuration: null,
        child: Card(
            child: Container(
                padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.only(
                            top: 0.0, left: 16.0, right: 16.0, bottom: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                                '${infoTarget.point.name} | ${storage?.users[infoTarget.point.ownerId]}',
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(
                                [
                                  utils.formatCoords(infoTarget.coords, false),
                                  '${I18N.of(context).categoryTitle}: ${I18N.of(context).category(infoTarget.point.category)}'
                                ].join(' '),
                                style: Theme.of(context).textTheme.bodySmall),
                            if (isNavigating)
                              Text('$distStr $brgStr $relBrgStr',
                                  style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      if (infoTarget.point.description?.isNotEmpty ?? false)
                        Container(
                            padding: const EdgeInsets.only(
                                left: 16.0, right: 16.0, bottom: 4.0),
                            child: Text(infoTarget.point.description!)),
                      ButtonBar(
                        alignment: MainAxisAlignment.spaceEvenly,
                        buttonHeight: 0,
                        buttonPadding: EdgeInsets.zero,
                        layoutBehavior: ButtonBarLayoutBehavior.padded,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: navigationTarget == infoTarget
                                ? const Icon(Icons.navigation)
                                : const Icon(Icons.navigation_outlined),
                            tooltip: navigationTarget == infoTarget
                                ? I18N.of(context).stopNavigationButton
                                : I18N.of(context).navigateToButton,
                            onPressed: currentLocation == null
                                ? null
                                : () => onInfoNavigate(infoTarget),
                          ),
                          GestureDetector(
                            child: IconButton(
                                icon: const Icon(Icons.center_focus_strong),
                                tooltip: I18N.of(context).centerViewInfoButton,
                                onPressed: () =>
                                    onCenterView(infoTarget, false)),
                            onDoubleTap: () => onCenterView(infoTarget, true),
                          ),
                          if (infoTarget.point.ownerId != 0)
                            if (infoTarget.point.deleted)
                              IconButton(
                                icon: const Icon(Icons.restore_from_trash),
                                tooltip: I18N.of(context).undelete,
                                onPressed: () =>
                                    onUndeletePoint(infoTarget.point),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: I18N.of(context).delete,
                                onPressed: () =>
                                    onDeletePoint(infoTarget.point),
                              ),
                          if (infoTarget.point.ownerId != 0)
                            IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: I18N.of(context).edit,
                                onPressed: () => onEditPoint(infoTarget.point)),
                          if (infoTarget.point.ownerId != 0 &&
                              infoTarget.point.isEdited)
                            IconButton(
                                icon: const Icon(Icons.restore),
                                tooltip: I18N.of(context).revert,
                                onPressed: () => onRevertPoi(infoTarget.point)),
                          if (infoTarget.point.ownerId != 0)
                            IconButton(
                              icon: const Icon(Icons.photo_library),
                              tooltip: I18N.of(context).managePhotos,
                              onPressed: () => onOpenGallery(infoTarget.point),
                            )
                        ],
                      ),
                    ]))));
  }

  Widget createMapControls(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
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
        Container(
          padding: const EdgeInsets.only(top: 6),
          child: FloatingActionButton(
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
        ),
        Container(
          padding: const EdgeInsets.only(top: 6),
          child: FloatingActionButton(
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
        ),
      ],
    );
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
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
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
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
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
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
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
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
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

  void setLocation() {
    location.getLocation().then((LocationData loc) {
      developer.log('One-time location: ${loc.latitude} ${loc.longitude}');
      setState(() {
        currentLocation = LatLng(loc.latitude!, loc.longitude!);
        onCurrentLocation();
      });
    });
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

  void onToggleLocationContinuous() {
    if (locationSubscription == null) {
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
          utils.notifySnackbar(context, I18N
              .of(context)
              .syncSuccessful,
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
            builder: (context) =>
                AlertDialog(
                    title: Text(I18N
                        .of(context)
                        .newVersionNotificationTitle),
                    content: SingleChildScrollView(
                      child: Column(
                        children: [
                          Text(I18N.of(context).newVersionNotificationText(
                              getIt
                                  .get<PackageInfo>()
                                  .version,
                              res.appVersion!.version)),
                          const SizedBox(height: 10),
                          Text(I18N
                              .of(context)
                              .newVersionDismissalInfo)
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
                          child: Text(I18N
                              .of(context)
                              .dismiss),
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
        utils.notifySnackbar(context, I18N
            .of(context)
            .downloaded,
            utils.NotificationLevel.success);
      }
    }

    // set
    offlineMapProvider = await MbtilesTileProvider.create(14, offlineMap.path);
    await storage!.setMapState(storage!.mapState!.from(usingOffline: true));
    setState(() {});
  }

  Future<bool> download(bool withPhotos) async {
    return withPhotos ? downloadWithPhotos() : downloadBare();
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
            context, I18N
            .of(context)
            .unpacking, utils.NotificationLevel.info,
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
        var ff = storage!.getFeatureFilter(FeatureFilterInst.featureList);
        ff.users.clear();
        ff.users.addAll(storage!.users.keys);
        await storage!.setFeatureFilter(FeatureFilterInst.featureList, ff);
      }

      List<Feature> localFeatures =
          storage!.features.where((f) => f.isLocal).toList();
      List<Feature> features = List.of(localFeatures);
      features.addAll(serverData.features);
      await storage!.setFeatures(features);

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
        utils.notifySnackbar(context, I18N
            .of(context)
            .downloaded,
            utils.NotificationLevel.success);
      }
    }
    setState(() {
      infoTarget = Target.none();
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
    var proposals = await storage!.getProposals();
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
        utils.notifySnackbar(context, I18N
            .of(context)
            .serverUnavailable,
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
        utils.notifySnackbar(context, I18N
            .of(context)
            .syncSuccessful,
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
      infoTarget = Target.none();
    });

    if (!mounted) return;
    utils.notifySnackbar(context, I18N.of(context).syncSuccessful,
        utils.NotificationLevel.success);
  }

  void onLogPoint(PointLogType type) async {
    developer.log('Log poi $type');
    LatLng loc = mapController.center;
    if (type == PointLogType.currentLocation && currentLocation != null) {
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
    setState(() {});
    if (infoTarget.isSamePoint(point)) {
      setState(() {
        infoTarget = Target(storage!.featuresMap[point.id]! as data.Point);
      });
    }
  }

  void onMapTap(TapPosition tapPosition, LatLng coords) {
    developer.log('onMapTap: $coords');
    setState(() {
      infoTarget = Target.none();
    });
  }

  void onPointListTap() async {
    if (storage == null) {
      utils.notifySnackbar(
          context, 'No storage!', utils.NotificationLevel.error);
      Navigator.of(context).pop();
    }
    Map<int, String>? users = Map.of(storage!.users);
    data.Point? selected = await Navigator.of(context).push(
        MaterialPageRoute<data.Point>(
            builder: (context) => PointList(
                storage!.features
                    .whereType<data.Point>()
                    .toList(growable: false),
                storage!.serverSettings!.id,
                users)));
    if (selected == null) {
      return;
    }
    setState(() {
      infoTarget = Target(selected);
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
    developer.log('Poi ${point.name} tap.');
    setState(() {
      if (infoTarget.isSamePoint(point)) {
        infoTarget = Target.none();
      } else {
        infoTarget = Target(point);
      }
    });
  }

  void onPointLongPress(data.Point point) {
    developer.log('Poi ${point.name} long press.');
    toggleNavigation(Target(point));
  }

  void onInfoNavigate(Target t) {
    developer.log('onInfoNavigate: ${t.point.name}');
    toggleNavigation(t);
  }

  void onInfoDistanceTap() {
    developer.log('onInfoDistanceTap');
    setState(() {
      infoTarget = navigationTarget;
    });
  }

  void onDeletePoint(data.Point toDelete) async {
    developer.log('onDeletePoint');
    if (toDelete.isLocal) {
      bool confirmed = await pointDataConfirm(
          (context) => I18N.of(context).aboutToDeleteLocalPoi, toDelete);
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
    if (infoTarget.isSamePoint(toDelete)) {
      if (r != null) {
        assert(r.isPoint());
        infoTarget = Target(r.asPoint());
      } else {
        infoTarget = Target.none();
      }
    }
    if (navigationTarget.isSamePoint(toDelete)) {
      if (r != null) {
        assert(r.isPoint());
        navigationTarget = Target(r.asPoint());
      } else {
        navigationTarget = Target.none();
      }
    }
    setState(() {});
  }

  void onUndeletePoint(data.Point toUndelete) async {
    var replacement = toUndelete.copy();
    replacement.deleted = false;
    await storage!.upsertFeature(replacement);
    data.Feature? r = storage!.featuresMap[toUndelete.id];
    if (infoTarget.isSamePoint(toUndelete)) {
      assert(r != null && r.isPoint());
      infoTarget = Target(r!.asPoint());
    }
    if (navigationTarget.isSamePoint(toUndelete)) {
      assert(r != null && r.isPoint());
      navigationTarget = Target(r!.asPoint());
    }
    setState(() {});
  }

  void onRevertPoi(data.Point toRevert) async {
    bool confirmed = await pointDataConfirm(
        (context) => I18N.of(context).aboutToRevertGlobalPoi, toRevert);
    if (!confirmed) {
      return;
    }
    var replacement = toRevert.copy();
    //await storage!.delete
    replacement.revert();
    await storage!.upsertFeature(replacement);
    if (infoTarget.isSamePoint(toRevert)) {
      data.Feature? r = storage!.featuresMap[toRevert.id];
      assert(r != null && r.isPoint());
      infoTarget = Target(r!.asPoint());
    }
    setState(() {});
  }

  void onOpenGallery(data.Point point) async {
    developer.log('onOpenGallery $point');
    if (storage == null) {
      utils.notifySnackbar(
          context, 'TODO no storage', utils.NotificationLevel.error);
      return;
    }
    data.Point? replacement = await Navigator.of(context).push(
        MaterialPageRoute<data.Point>(
            builder: (context) =>
                Gallery(storage: storage!, feature: point, editable: true)));
    if (replacement == null) {
      return;
    }
    await storage!.upsertFeature(replacement);
    setState(() {});
    if (infoTarget.isSamePoint(point)) {
      setState(() {
        infoTarget = Target(storage!.featuresMap[point.id]! as data.Point);
      });
    }
  }

  void onProposeImprovement() async {
    data.Proposal? proposal = await Navigator.of(context).push(
        MaterialPageRoute<data.Proposal>(
            builder: (context) => const CreateProposal()));
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
    infoTarget = Target.none();
    progressValue = null;
    getIt.get<comm.AppClient>().unsetUserID();
    setState(() {});
    if (!mounted) return;
    Navigator.of(context).pop();
    utils.notifySnackbar(
        context, I18N.of(context).resetDone, utils.NotificationLevel.info);
  }

  Future<bool> pointDataConfirm(
      String Function(BuildContext) question, data.Point point) async {
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
                      title: Text(point.name),
                      subtitle: Text(I18N.of(context).nameLabel),
                    ),
                    ListTile(
                        title: Text(storage?.users[point.ownerId] ??
                            '<unknown ID: ${point.ownerId}>'),
                        subtitle: Text(I18N.of(context).owner)),
                    ListTile(
                      title: Text(utils.formatCoords(point.coords, true)),
                      subtitle: Text(I18N.of(context).position),
                    ),
                    if (point.description?.isNotEmpty ?? false)
                      ListTile(
                        title: Text(point.description!),
                        subtitle: Text(I18N.of(context).descriptionLabel),
                      ),
                    ListTile(
                        title: Text(I18N.of(context).category(point.category)),
                        subtitle: Text(I18N.of(context).categoryTitle),
                        trailing: Icon(point.category.iconData)),
                    ListTile(
                        title: point.attributes.isEmpty
                            ? Text(I18N.of(context).noAttributes)
                            : Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: point.attributes
                                    .map((attr) => Tooltip(
                                          message:
                                              I18N.of(context).attribute(attr),
                                          child: Icon(attr.iconData),
                                        ))
                                    .toList(growable: false),
                              ),
                        subtitle: Text(I18N.of(context).attributes)),
                    if (point.deadline != null)
                      ListTile(
                        title: Text(I18N
                            .of(context)
                            .dateFormat
                            .format(point.deadline!)),
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

  void onCenterView(Target t, bool zoom) {
    mapController.move(
        t.coords,
        zoom
            ? (storage?.mapState?.zoomMax ?? fallbackMaxZoom).toDouble()
            : mapController.zoom);
  }

  void toggleNavigation(Target t) {
    setState(() {
      if (navigationTarget == t) {
        navigationTarget = Target.none();
      } else {
        navigationTarget = t;
      }
    });
  }
}
