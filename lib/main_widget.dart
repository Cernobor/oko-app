import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:oko/main.dart';
import 'package:oko/map.dart';
import 'package:positioned_tap_detector_2/positioned_tap_detector_2.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' hide Theme;
import 'package:rxdart/rxdart.dart';

import 'package:oko/storage.dart';
import 'package:oko/subpages/edit_point.dart';
import 'package:oko/subpages/pairing.dart';
import 'package:oko/communication.dart' as comm;
import 'package:oko/utils.dart' as utils;
import 'package:oko/data.dart' as data;
import 'package:oko/i18n.dart';
import 'package:oko/subpages/point_list.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

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

  // handling flags and values
  bool mapReady = false;
  double progressValue = -1;
  bool pinging = false;
  bool serverAvailable = false;
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
    try {
      storage = await Storage.getInstance();
    } catch (e) {
      developer.log(e.toString());
      utils.notifySnackbar(
          context,
          'Error while getting storage: ${e.toString()}',
          utils.NotificationLevel.error);
    }
    if (storage?.serverSettings?.serverAddress != null) {
      startPinging();
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
            child: const Center(
              child: Image(
                image: AssetImage('assets/splash.png'),
                width: 320.0,
                height: 147.0,
              ),
            ),
            decoration:
                const BoxDecoration(color: cbGreen),
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
      title: Text(I18N.of(context).appTitle),
      centerTitle: true,
      primary: true,
      bottom: PreferredSize(
        preferredSize: const Size(double.infinity, 6.0),
        child: progressValue == -1
            ? Container(height: 6.0)
            : LinearProgressIndicator(
                value: progressValue,
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
            title: Text(I18N.of(context).drawerServerAvailable),
            enabled: storage?.serverSettings != null,
            trailing: storage?.serverSettings != null && pinging
                ? const SizedBox(
                    child: CircularProgressIndicator(
                        value: null, strokeWidth: 2.5),
                    height: 16,
                    width: 16,
                  )
                : (storage?.serverSettings != null && serverAvailable
                    ? const Icon(
                        Icons.done,
                        color: Colors.green,
                      )
                    : const Icon(
                        Icons.clear,
                        color: Colors.red,
                      )),
            onTap: onPing,
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
                            onDownload(true, context);
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
            child: createInfoContentDistance(context),
            alignment: Alignment.bottomCenter,
            constraints: const BoxConstraints.expand(),
          ),
        if (infoTarget.isSet)
          Container(
            child: createInfoContentFull(context),
            alignment: Alignment.bottomCenter,
            constraints: const BoxConstraints.expand(),
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
          child: createMapControls(context),
          alignment: Alignment.topRight,
          padding: const EdgeInsets.all(8.0),
        )
      ],
    );
  }

  Widget createMap(BuildContext context) {
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
          plugins: [VectorMapTilesPlugin()],
          onMapCreated: (MapController mapController) {
            Future.microtask(() {
              setState(() {
                mapReady = true;
              });
            });
          }),
      mapController: mapController,
      children: [
        if (storage?.serverSettings != null)
          if (storage?.mapState?.render ?? false)
            VectorTileLayerWidget(
                options: VectorTileLayerOptions(
                    tileProviders: TileProviders({
                      'openmaptiles': MemoryCacheVectorTileProvider(
                          delegate: NetworkVectorTileProvider(
                              urlTemplate:
                                  '${comm.ensureNoTrailingSlash(storage!.serverSettings!.serverAddress)}${storage!.serverSettings!.tilePathTemplate}',
                              maximumZoom: 14),
                          maxSizeBytes: 1024 * 1024 * 5)
                    }),
                    theme: ThemeReader().read(mapThemeData()),
                    backgroundTheme: ThemeReader().readAsBackground(
                        mapThemeData(),
                        layerPredicate: defaultBackgroundLayerPredicate)))
          else
            SolidColorLayerWidget(options: SolidColorLayerOptions(
              color: mapBackgroundColor
            ))
      ],
      layers: [
        // limits
        PolylineLayerOptions(
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
                : []),
        // line to target
        if (currentLocation != null && navigationTarget.isSet)
          PolylineLayerOptions(polylines: <Polyline>[
            Polyline(points: <LatLng>[
              currentLocation!,
              navigationTarget.coords,
            ], strokeWidth: 5, color: Colors.blue),
          ]),
        // current location
        if (currentLocation != null)
          MarkerLayerOptions(markers: [
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
          ]),
        // extra geometry
        GroupLayerOptions(group: createGeometry()),
        // Points
        MarkerLayerOptions(markers: createMarkers()),
      ],
    );
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
                      color: point.deleted ? point.color.withOpacity(0.5) : point.color,
                    ),
                    if (point.isEdited)
                      Align(
                        alignment: const Alignment(1, -1),
                        child: Icon(Icons.edit,
                            size: badgeSize *
                                (infoTarget.isSamePoint(point) ? 1.5 : 1),
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    if (point.isLocal)
                      Align(
                        alignment: const Alignment(1, -1),
                        child: Icon(Icons.star,
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
                            color: point.deleted
                                ? attr.color.withOpacity(0.5)
                                : attr.color),
                      )
                  ],
                ))),
      );
    }).toList();
  }

  List<LayerOptions> createGeometry() {
    if (storage == null) {
      return [];
    }
    return [
      PolylineLayerOptions(
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
      child: Container(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'd: ${nav.distanceM.toStringAsFixed(2)} m  '
            'b: ${nav.bearingDeg.toStringAsFixed(2)}°  '
            'rb: ${nav.relativeBearingDeg == null ? '-' : nav.relativeBearingDeg!.toStringAsFixed(2)}°',
            textAlign: TextAlign.center,
          )),
      onTap: onInfoDistanceTap,
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
                                '${infoTarget.point.name} (${storage?.users[infoTarget.point.ownerId]})',
                                style: Theme.of(context).textTheme.headline6),
                            Text(
                                [
                                  utils.formatCoords(infoTarget.coords, false),
                                  '${I18N.of(context).categoryTitle}: ${I18N.of(context).category(infoTarget.point.category)}'
                                ].join(' '),
                                style: Theme.of(context).textTheme.caption),
                            if (isNavigating)
                              Text('$distStr $brgStr $relBrgStr',
                                  style: Theme.of(context).textTheme.caption),
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
                          IconButton(
                              icon: const Icon(Icons.center_focus_strong),
                              tooltip: I18N.of(context).centerViewInfoButton,
                              onPressed: () => onCenterView(infoTarget)),
                          if (infoTarget.point.ownerId != 0)
                            if (infoTarget.point.deleted)
                              IconButton(
                                icon: const Icon(Icons.restore_from_trash),
                                tooltip: I18N.of(context).undeleteButton,
                                onPressed: () =>
                                    onUndeletePoint(infoTarget.point),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: I18N.of(context).deleteButton,
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
                                onPressed: () => onRevertPoi(infoTarget.point))
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
          child: const Icon(
            Icons.zoom_in,
            size: 30,
          ),
          backgroundColor: !mapReady ||
                  mapController.zoom >=
                      (storage?.mapState?.zoomMax ?? fallbackMaxZoom)
              ? Theme.of(context).disabledColor
              : null,
          onPressed: !mapReady ||
                  mapController.zoom >=
                      (storage?.mapState?.zoomMax ?? fallbackMaxZoom)
              ? null
              : () => onZoom(1),
        ),
        Container(
          padding: const EdgeInsets.only(top: 6),
          child: FloatingActionButton(
            heroTag: 'fab-zoom-out',
            tooltip: I18N.of(context).zoomOut,
            elevation: 0,
            child: const Icon(
              Icons.zoom_out,
              size: 30,
            ),
            backgroundColor: !mapReady ||
                mapController.zoom <=
                    (storage?.serverSettings?.minZoom ?? fallbackMinZoom)
                ? Theme.of(context).disabledColor
                : null,
            onPressed: !mapReady ||
                    mapController.zoom <=
                        (storage?.serverSettings?.minZoom ?? fallbackMinZoom)
                ? null
                : () => onZoom(-1),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 6),
          child: FloatingActionButton(
            heroTag: 'fab-reset-rotation',
            tooltip: I18N.of(context).resetRotation,
            elevation: 0,
            child: Transform.rotate(
              angle: mapReady ? mapController.rotation * math.pi / 180 : 0,
              child: const Icon(
                Icons.north,
                size: 30,
              ),
            ),
            backgroundColor: !mapReady || mapController.rotation == 0.0
                ? Theme.of(context).disabledColor
                : null,
            onPressed: () {
              if (mapReady) {
                setState(() {
                  mapController.rotate(0);
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget createBottomBar(BuildContext context) {
    TextStyle ts = TextStyle(
        //color: Theme.of(context).colorScheme.onPrimary,
        fontFamily: 'monospace');
    return BottomAppBar(
      //color: Theme.of(context).colorScheme.primaryVariant,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
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
                          padding: const EdgeInsets.symmetric(
                              vertical: 1, horizontal: 4),
                          alignment: Alignment.center,
                          child: Text(
                            'GPS',
                            style: ts,
                          )),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 1, horizontal: 4),
                        alignment: Alignment.center,
                        child: Text(
                          'TGT',
                          style: ts,
                        ),
                      )
                    ]),
                    TableRow(children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 1, horizontal: 4),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Lat',
                          style: ts,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 1, horizontal: 4),
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
                            vertical: 1, horizontal: 4),
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
                        padding: const EdgeInsets.symmetric(
                            vertical: 1, horizontal: 4),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Lng',
                          style: ts,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 1, horizontal: 4),
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
                            vertical: 1, horizontal: 4),
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
                    IconButton(
                      tooltip: I18N.of(context).lockViewToLocationButtonTooltip,
                      icon: Icon(viewLockedToLocation
                          ? Icons.gps_fixed
                          : Icons.gps_not_fixed),
                      iconSize: 30.0,
                      onPressed:
                          currentLocation == null ? null : onLockViewToLocation,
                    ),
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

  void onLockViewToLocation() {
    setState(() {
      viewLockedToLocation = true;
      mapController.move(currentLocation!, mapController.zoom);
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
    if (mapReady && evt.center != currentLocation) {
      viewLockedToLocation = false;
    }
    setState(() {});
    if (evt is MapEventWithMove || evt is MapEventMoveEnd) {
      mapStateStorageController.add(evt);
    }
  }

  void onMapEventStorage(MapEvent evt) async {
    //developer.log('onMapEventStorage: $evt');
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
        //developer.log('Continuous location: ${loc.latitude} ${loc.longitude}');
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
      await onDownload(false);
      setState(() {});
      mapController.move(storage!.serverSettings!.defaultCenter,
          storage!.serverSettings!.minZoom.toDouble());
      Navigator.of(context).pop();
      startPinging();
    }
  }

  void onPing() {
    setState(() {
      if (storage?.serverSettings?.serverAddress == null) {
        return;
      }
      pinging = true;
      comm.ping(storage!.serverSettings!.serverAddress).then((bool pong) {
        setState(() {
          pinging = false;
          serverAvailable = pong;
        });
      });
    });
  }

  void startPinging() {
    if (storage?.serverSettings == null) {
      developer.log('No settings, cannot start pinging.');
      return;
    }
    Future.doWhile(() {
      if (storage?.serverSettings == null) {
        return Future.delayed(const Duration(seconds: 5), () => true);
      }
      return Future.delayed(const Duration(seconds: 5), () {
        onPing();
        return true;
      });
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
    utils.notifySnackbar(
        context, 'not implemented (yet)', utils.NotificationLevel.error);
    /*
    Navigator.of(context).pop();
    // download
    var res = await comm.downloadMap(storage!.serverSettings!.serverAddress,
        storage!.serverSettings!.tilePackPath);
    var received = 0;
    var stream = res.dataStream.map(res.contentLength != null
        ? (chunk) {
            received += chunk.length;
            developer.log('Received $received of ${chunk.length} bytes.');
            setState(() {
              progressValue = received / res.contentLength!;
            });
            return chunk;
          }
        : (chunk) {
            received += chunk.length;
            developer.log('Received $received bytes.');
            return chunk;
          });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(I18N.of(context).downloadingMapSnackBar),
      duration: const Duration(seconds: 3),
    ));
    await saveTilePackRaw(stream);

    // unpack
    setState(() {
      progressValue = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(I18N.of(context).unpackingMapSnackBar),
      duration: Duration(seconds: 3),
    ));
    await unpackTilePack((int n, int total) {
      var p = n.toDouble() / total.toDouble();
      setState(() {
        progressValue = p;
      });
    });

    // get and focus on map center
    var mapLimits = await getMapLimits();
    if (mapLimits != null) {
      mapController.fitBounds(mapLimits.latLngBounds);
      if (mapController.zoom < mapLimits.zoom.min) {
        mapController.move(mapController.center, mapLimits.zoom.min.toDouble());
      } else if (mapController.zoom > mapLimits.zoom.max) {
        mapController.move(mapController.center, mapLimits.zoom.max.toDouble());
      }
      setState(() {
        this.mapLimits = mapLimits;
      });
    }

    // done
    setState(() {
      progressValue = -1;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(I18N.of(context).doneMapSnackBar),
      duration: const Duration(seconds: 3),
    ));
    */
  }

  Future<void> onDownload(bool only, [BuildContext? ctx]) async {
    developer.log('onDownload');
    if (only) {
      bool? confirm = await showDialog<bool>(
          context: ctx!,
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
    }
    late comm.Data data;
    try {
      data = await comm.downloadData(storage!.serverSettings!.serverAddress);
    } on comm.UnexpectedStatusCode catch (e, stack) {
      developer.log('exception: ${e.toString()} $stack');
      await utils.notifyDialog(context, e.getMessage(context), e.detail,
          utils.NotificationLevel.error);
      return;
    } catch (e, stack) {
      developer.log('exception: ${e.toString()} $stack');
      await utils.notifyDialog(context, I18N.of(context).error, e.toString(),
          utils.NotificationLevel.error);
      return;
    }
    bool usersChanged =
        !setEquals(data.users.keys.toSet(), storage!.users.keys.toSet());
    await storage!.setUsers(data.users);
    await storage!.setFeatures(data.features);
    if (usersChanged) {
      await storage!.setPointListCheckedUsers(storage!.users.keys);
    }
    setState(() {
      infoTarget = Target.none();
    });
    if (only) {
      Navigator.of(context).pop();
      utils.notifySnackbar(context, I18N.of(context).downloaded,
          utils.NotificationLevel.success);
    }
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
    try {
      await comm.uploadData(
          storage!.serverSettings!.serverAddress, created, edited, deleted);
    } on comm.DetailedCommException catch (e, stack) {
      developer.log('exception: ${e.toString()} $stack');
      await utils.notifyDialog(context, e.getMessage(context), e.detail,
          utils.NotificationLevel.error);
      return false;
    } on Exception catch (e, stack) {
      developer.log('exception: ${e.toString()} $stack');
      utils.notifySnackbar(context, I18N.of(context).serverUnavailable,
          utils.NotificationLevel.error);
      return false;
    }
    return true;
  }

  FutureOr<void> onUpload() async {
    developer.log('onUpload');
    bool success = await upload();
    Navigator.of(context).pop();
    if (success) {
      utils.notifySnackbar(context, I18N.of(context).syncSuccessful,
          utils.NotificationLevel.success);
    }
    setState(() {});
  }

  Future<void> onSync() async {
    developer.log('onSync');
    if (!await upload()) {
      Navigator.of(context).pop();
      return;
    }
    await onDownload(false);
    Navigator.of(context).pop();
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
    Navigator.pop(context);
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
    Navigator.of(context).pop();
  }

  void onUserListTap() {
    if (storage == null) {
      utils.notifySnackbar(
          context, 'No storage!', utils.NotificationLevel.error);
      Navigator.of(context).pop();
    }
    Map<int, String>? users = Map.of(storage!.users);
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              actionsAlignment: MainAxisAlignment.center,
              title: Text(I18N.of(context).userListTitle),
              content: ListView(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                children: users.entries
                    .map((e) => Text(
                        '\u2022 ${e.value}${e.key == storage!.serverSettings?.id ? ' (${I18N.of(context).me})' : ''}'))
                    .toList(growable: false)
                  ..sort((Text a, Text b) => -a.data!.compareTo(b.data!)),
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
    replacement.revert();
    await storage!.upsertFeature(replacement);
    if (infoTarget.isSamePoint(toRevert)) {
      data.Feature? r = storage!.featuresMap[toRevert.id];
      assert(r != null && r.isPoint());
      infoTarget = Target(r!.asPoint());
    }
    setState(() {});
  }

  void onReset() async {
    developer.log('Resetting app.');
    if (storage == null) {
      developer.log('No storage - nothing to reset.');
      return;
    }
    storage = await Storage.getInstance(reset: true);
    setState(() {});
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
                isAlwaysShown: true,
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
                        subtitle: Text(I18N.of(context).attributes))
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

  void onCenterView(Target t) {
    mapController.move(t.coords, mapController.zoom);
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
