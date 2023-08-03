import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:oko/data.dart';
import 'package:oko/i18n.dart';
import 'package:oko/storage.dart';
import 'package:oko/subpages/feature_list.dart';
import 'package:oko/utils.dart';
import 'package:oko/constants.dart' as constants;

class EditPoly extends StatefulWidget {
  final EditedPoly editedPoly;
  final Poly? source;

  const EditPoly(
      {super.key, required this.editedPoly, this.source});

  @override
  State createState() => _EditPolyState();
}

class _EditPolyState extends State<EditPoly>
    with TickerProviderStateMixin {

  late Future<void> storageWait;
  late Storage storage;
  late Map<int, Point> points;
  late List<_Triple> nodes;
  final TextEditingController nameInputController = TextEditingController();
  String? nameInputError;
  late int ownerId;
  late bool closed;
  late Color color;
  late Color colorFill;
  late bool hasColorFill;
  late bool hasDeadline;

  DateTime? deadline;

  late final TabController tabController;

  @override
  void initState() {
    super.initState();
    storageWait = Storage.getInstance().then((value) {
      storage = value;
      points = {for (Point p in value.features.whereType<Point>()) p.id: p};

      setState(() {
        ownerId = widget.source?.ownerId ?? value.serverSettings!.id;
        nameInputController.text = widget.source?.name ?? '';
        color = widget.editedPoly.color;
        colorFill = widget.editedPoly.colorFill ?? constants.palette[constants.defaultPolyFillColorIndex];
        hasColorFill = widget.editedPoly.colorFill != null;
        hasDeadline = widget.source?.deadline != null;
        deadline = widget.source?.deadline;
        closed = widget.editedPoly.closed;
        nodes = widget.editedPoly.coords.mapIndexed((i, e) => _Triple(e, false, i)).toList();
      });
    });
    tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (nameInputController.text.isNotEmpty) {
      nameInputError = null;
    } else {
      nameInputError = I18N.of(context).errorNameRequired;
    }
    return FutureBuilder(
        future: storageWait,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: buildScaffold(context),
            );
          }
          return Container();
        });
  }

  Widget buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18N.of(context).createPoly),
        primary: true,
        leading: BackButton(
          onPressed: () => onBack(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: I18N.of(context).dialogSave,
            onPressed: _isValid() ? () => _save(context) : null,
          )
        ],
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(icon: Icon(Icons.polyline)),
            Tab(icon: Icon(Icons.settings))
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [buildBody(context), buildSettings(context)],
      ),
    );
  }

  Widget buildSettings(BuildContext context) {
    Widget settings = Column(
      children: [
        CheckboxListTile(
            title: Text(I18N.of(context).closePath),
            subtitle: Text(I18N.of(context).closePathSubtitle),
            secondary: const Icon(constants.closePath),
            tristate: false,
            value: closed,
            onChanged: (bool? value) {
              setState(() {
                closed = value ?? false;
              });
            }),
        ListTile(
          title: TextField(
            controller: nameInputController,
            keyboardAppearance: Theme.of(context).brightness,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                labelText: I18N.of(context).nameLabel,
                errorText: nameInputError),
            onChanged: (String value) {
              setState(() {
                if (value.isEmpty) {
                  nameInputError = I18N.of(context).errorNameRequired;
                } else {
                  nameInputError = null;
                }
              });
            },
          ),
        ),
        ListTile(
            title: Text(I18N.of(context).owner),
            subtitle: DropdownButton<int>(
                value: ownerId,
                icon: const Icon(Icons.arrow_downward),
                onChanged: (int? v) {
                  setState(() {
                    ownerId = v!;
                  });
                },
                items: storage.users.keys.map((int oid) {
                  return DropdownMenuItem<int>(
                      value: oid, child: Text(storage.users[oid]!));
                }).toList(growable: false))),
        ListTile(
          title: Text(I18N.of(context).color),
          leading: Icon(Icons.circle, color: color),
          onTap: () => onChooseColor(false),
        ),
        if (closed)
          CheckboxListTile(
            title: Text(I18N.of(context).colorFill),
            secondary: Icon(Icons.circle, color: colorFill),
            value: hasColorFill,
            onChanged: (value) {
              if (value ?? false) {
                onChooseColor(true);
              } else {
                setState(() {
                  hasColorFill = false;
                });
              }
            },
          ),
        ListTile(
          title: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Row(children: [
                Text(I18N.of(context).deadline),
                Checkbox(
                    value: hasDeadline,
                    onChanged: (value) => setState(() {
                          hasDeadline = value ?? false;
                        }))
              ]),
              Expanded(
                  child: TextField(
                      style: TextStyle(
                          color: hasDeadline
                              ? null
                              : Theme.of(context).disabledColor),
                      controller: TextEditingController(
                          text: deadline == null
                              ? null
                              : I18N
                                  .of(context)
                                  .dateFormat
                                  .format(deadline!.toLocal())),
                      decoration: InputDecoration(
                        suffixIcon: const Icon(Icons.calendar_today),
                        errorText: hasDeadline && deadline == null
                            ? I18N.of(context).chooseTime
                            : null,
                        //counterText: ' '
                      ),
                      enabled: hasDeadline,
                      readOnly: true,
                      onTap: onChooseTime)),
            ],
          ),
        ),
      ],
    );
    return SingleChildScrollView(
      child: Column(
        children: [settings],
      ),
    );
  }

  Widget buildBody(BuildContext context) {
    return Stack(
      children: [
        buildList(context),
        Container(
          alignment: Alignment.bottomRight,
          padding: const EdgeInsets.all(8),
          child: Wrap(
            alignment: WrapAlignment.start,
            verticalDirection: VerticalDirection.up,
            direction: Axis.vertical,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              FloatingActionButton(
                heroTag: 'fab-path-add-point',
                onPressed: onAddPoint,
                child: const Icon(Icons.add, size: 30),
              ),
              if (nodes.any((e) => e.checked))
                FloatingActionButton(
                  heroTag: 'fab-path-remove-point',
                  onPressed: onRemovePoints,
                  child: const Icon(Icons.delete, size: 30),
                )
            ],
          ),
        )
      ],
    );
  }

  Widget buildList(BuildContext context) {
    Widget proxyDecorator(Widget child, int index, Animation<double> _) {
      return Material(
        elevation: 8,
        surfaceTintColor: Theme.of(context).colorScheme.primary,
        shadowColor: Theme.of(context).colorScheme.primary,
        child: child,
      );
    }

    return ReorderableListView(
        proxyDecorator: proxyDecorator,
        buildDefaultDragHandles: true,
        onReorder: (int oldIndex, int newIndex) {
          developer.log('reorder: $oldIndex $newIndex');
          if (newIndex - oldIndex == 1) {
            return;
          } else if (newIndex - oldIndex > 1) {
            newIndex -= 1;
          }
          setState(() {
            final _Triple item = nodes.removeAt(oldIndex);
            nodes.insert(newIndex, item);
          });
        },
        children: nodes
            .map((e) => buildListItem(context, e))
            .toList(growable: false));
  }

  Widget buildListItem(BuildContext context, _Triple item) {
    Point? point;
    LatLng coords;
    LatLng p = item.coord;
    if (p is ReferencedLatLng && p.pointRef != null) {
      point = points[p.pointRef]!;
      coords = point.coords;
    } else {
      coords = item.coord;
    }
    bool checked = item.checked;

    return CheckboxListTile(
      key: ValueKey(item.key),
      secondary: SizedBox(
          width: 40,
          child: Stack(
            children: [
              Icon(
                point?.category.iconData ?? constants.polyNode,
                color: point?.color ?? constants.polyEditColor,
                size: 40,
              ),
              if (point?.isLocal ?? false)
                Align(
                  alignment: const Alignment(1, -1),
                  child: Icon(constants.pointLocalBadge,
                      size: constants.badgeSize,
                      color: Theme.of(context).colorScheme.primary),
                ),
              if (point?.isEdited ?? false)
                Align(
                  alignment: const Alignment(1, -1),
                  child: Icon(constants.pointEditedBadge,
                      size: constants.badgeSize,
                      color: Theme.of(context).colorScheme.primary),
                ),
              if (point?.deleted ?? false)
                Align(
                  alignment: point?.isEdited ?? false
                      ? const Alignment(1, 0)
                      : const Alignment(1, -1),
                  child: Icon(constants.pointDeletedBadge,
                      size: constants.badgeSize,
                      color: Theme.of(context).colorScheme.primary),
                ),
              if (point?.isLocked ?? false)
                Align(
                  alignment: const Alignment(1, -1),
                  child: Icon(constants.pointLocked,
                      size: constants.badgeSize,
                      color: Theme.of(context).colorScheme.primary),
                ),
              for (var attr in (point?.attributes ?? <PointAttribute>[]))
                Align(
                    alignment: Alignment(attr.xAlign, attr.yAlign),
                    child: Icon(
                      attr.iconData,
                      color: attr.color,
                      size: constants.badgeSize,
                    ))
            ],
          )),
      title: point == null
          ? null
          : Text('${point.name} | ${storage.users[point.ownerId]}'),
      subtitle: Text(
          [
            if (point?.description?.isNotEmpty ?? false) point!.description,
            formatCoords(coords, false)
          ].join('\n'),
          maxLines: 2),
      dense: true,
      isThreeLine: point?.description?.isNotEmpty ?? false,
      value: checked,
      onChanged: (bool? value) {
        setState(() {
          item.checked = value!;
        });
      },
    );
  }

  void onAddPoint() async {
    developer.log('onAddPoint');
    List<Point>? selected = await Navigator.of(context).push(
        MaterialPageRoute<List<Point>>(
            builder: (context) => FeatureList(
                title: I18N.of(context).pickAPoint,
                typeRestriction: FeatureType.point,
                multiple: true)));
    if (selected == null) {
      setState(() {});
      return;
    }
    setState(() {
      int l = nodes.length;
      nodes.addAll(selected.mapIndexed(
          (i, e) => _Triple(ReferencedLatLng.fromPoint(e), false, l + i)));
    });
  }

  void onRemovePoints() {
    setState(() {
      nodes.removeWhere((e) => e.checked);
    });
  }

  void onChooseColor(bool fill) async {
    Color? c = await chooseColorBlock(context,
        availableColors: constants.palette,
        initialColor: fill
            ? (colorFill ??
                constants.palette[constants.defaultPolyFillColorIndex])
            : color);
    if (c != null) {
      setState(() {
        if (fill) {
          colorFill = c;
          hasColorFill = true;
        } else {
          color = c;
        }
      });
    }
  }

  void onChooseTime() async {
    DateTime? dateTime =
        await chooseTime(context, initialTime: deadline?.toLocal());
    if (dateTime != null) {
      setState(() {
        deadline = dateTime.toUtc();
      });
    }
  }

  bool _isValid() {
    return nameInputController.text.isNotEmpty &&
        (!hasDeadline || deadline != null);
  }

  void onBack(BuildContext context) {
    Navigator.of(context).pop(EditedPoly(
        coords: nodes.map((e) => e.coord).toList(),
        closed: closed,
        color: color,
        colorFill: colorFill));
  }

  void _save(BuildContext context) {
    List<LatLng> coords = nodes.map((e) => e.coord).toList(growable: false);
    Poly poly;
    if (widget.source == null) {
      poly = Poly.origSame(
          0,
          ownerId,
          nameInputController.text,
          hasDeadline ? deadline : null,
          null,
          color,
          colorFill,
          Set.identity(),
          coords,
          closed,
          false);
    } else if (widget.source!.isLocal) {
      poly = Poly.origSame(
          widget.source!.id,
          ownerId,
          nameInputController.text,
          hasDeadline ? deadline : null,
          null,
          color,
          colorFill,
          widget.source!.photoIDs,
          coords,
          closed,
          widget.source!.deleted);
    } else {
      poly = Poly(
          widget.source!.id,
          ownerId,
          widget.source!.origOwnerId,
          nameInputController.text,
          widget.source!.origName,
          hasDeadline ? deadline : null,
          widget.source!.origDeadline,
          null,
          widget.source!.origDescription,
          color,
          widget.source!.origColor,
          colorFill,
          widget.source!.colorFill,
          widget.source!.photoIDs,
          widget.source!.origPhotoIDs,
          coords,
          widget.source!.origCoords,
          closed,
          widget.source!.polygon,
          widget.source!.deleted);
    }
    Navigator.of(context).pop(poly);
  }
}

class _Triple {
  LatLng coord;
  bool checked;
  int key;

  _Triple(this.coord, this.checked, this.key);
}