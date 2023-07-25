import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:oko/data.dart';
import 'package:oko/i18n.dart';
import 'package:oko/storage.dart';
import 'package:oko/subpages/point_list.dart';
import 'package:oko/utils.dart';

String _sortToString(Sort sort, BuildContext context) {
  switch (sort) {
    case Sort.owner:
      return I18N.of(context).owner;
    case Sort.name:
      return I18N.of(context).nameLabel;
  }
}

class PathCreationResult {
  LineString path;
  Set<int> toDelete;

  PathCreationResult({required this.path, required this.toDelete});
}

class PathCreator extends StatefulWidget {
  final UsersView users;
  final int myId;

  const PathCreator({super.key, required this.users, required this.myId});

  @override
  State createState() => _PathCreatorState();
}

class _PathCreatorState extends State<PathCreator> with TickerProviderStateMixin {
  final badgeSize = 13.7;
  static final List<Color> _colors = [
    Colors.red.shade500,
    Colors.pink.shade500,
    Colors.purple.shade500,
    Colors.deepPurple.shade500,
    Colors.indigo.shade500,
    Colors.blue.shade500,
    Colors.lightBlue.shade500,
    Colors.cyan.shade500,
    Colors.teal.shade500,
    Colors.green.shade500,
    Colors.lightGreen.shade500,
    Colors.lime.shade500,
    Colors.yellow.shade500,
    Colors.amber.shade500,
    Colors.orange.shade500,
    Colors.deepOrange.shade500,
    Colors.brown.shade500,
    Colors.grey.shade500,
    Colors.blueGrey.shade500,
    Colors.black,
  ];

  late Future<void> storageWait;
  late Storage storage;
  late Map<int, Point> points;
  late List<int> order;
  final Set<int> checked = {};
  final TextEditingController nameInputController = TextEditingController();
  String? nameInputError;
  late int ownerId;
  late Color color;
  late bool hasDeadline;
  DateTime? deadline;

  late final TabController tabController;

  bool? sortByNameAsc;
  bool? deletePointsAfterCreation = false;
  bool loop = false;

  @override
  void initState() {
    super.initState();
    storageWait = getStorage();
    tabController = TabController(length: 2, vsync: this);
    ownerId = widget.myId;
    color = Colors.black;
    hasDeadline = false;
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> getStorage() async {
    storage = await Storage.getInstance();
    points = {for (Point p in storage.features.whereType<Point>()) p.id: p};
    order = List.of(storage.pathCreation);
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
        title: Text(I18N.of(context).createPath),
        primary: true,
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: tabController,
          tabs: [
            Tab(icon: const Icon(Icons.polyline)),
            Tab(icon: const Icon(Icons.settings))
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          buildBody(context),
          buildSettings(context)
        ],
      ),
    );
  }

  Widget buildSettings(BuildContext context) {
    Widget settings = Column(
      children: [
        /*ListTile(
          title: Text(I18N.of(context).orderPointsByName),
          leading: const Icon(Icons.sort_by_alpha),
          trailing: sortByNameAsc == null
              ? const Icon(Icons.remove)
              : Icon(
              sortByNameAsc! ? Icons.arrow_downward : Icons.arrow_upward),
          onTap: () {
            setState(() {
              sortByNameAsc =
              !(sortByNameAsc == null ? false : sortByNameAsc!);
              sortByName();
            });
          },
        ),*/
        ExpansionTile(
          title: Text(I18N.of(context).deletePointsAfterPathCreated),
          subtitle: Text(() {
            switch (deletePointsAfterCreation) {
              case false:
                return I18N.of(context).deletePointsNone;
              case null:
                return I18N.of(context).deletePointsChecked;
              case true:
                return I18N.of(context).deletePointsAll;
              default:
                throw IllegalStateException(
                    'invalid deletePointsAfterCreation state: $deletePointsAfterCreation');
            }
          }()),
          leading: const Icon(Icons.auto_delete),
          children: [
            RadioListTile<bool?>(
                value: false,
                groupValue: deletePointsAfterCreation,
                title: Text(I18N.of(context).deletePointsNone),
                onChanged: (bool? value) {
                  setState(() {
                    deletePointsAfterCreation = value;
                  });
                }),
            RadioListTile<bool?>(
                value: null,
                groupValue: deletePointsAfterCreation,
                title: Text(I18N.of(context).deletePointsChecked),
                onChanged: (bool? value) {
                  setState(() {
                    deletePointsAfterCreation = value;
                  });
                }),
            RadioListTile<bool?>(
                value: true,
                groupValue: deletePointsAfterCreation,
                title: Text(I18N.of(context).deletePointsAll),
                onChanged: (bool? value) {
                  setState(() {
                    deletePointsAfterCreation = value;
                  });
                })
          ],
        ),
        CheckboxListTile(
            title: Text(I18N.of(context).closePath),
            subtitle: Text(I18N.of(context).closePathSubtitle),
            secondary: const Icon(Icons.all_inclusive),
            tristate: false,
            value: loop,
            onChanged: (bool? value) {
              setState(() {
                loop = value ?? false;
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
                items: widget.users.keys.map((int oid) {
                  return DropdownMenuItem<int>(
                      value: oid, child: Text(widget.users[oid]!));
                }).toList(growable: false))),
        ListTile(
          title: Text(I18N.of(context).color),
          leading: Icon(Icons.circle, color: color),
          onTap: onChooseColor,
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
    Widget create = Column(
      children: [
        ListTile(
          title: Text(I18N.of(context).pathCreationConfirm),
          leading: const Icon(Icons.check),
          onTap: () => onCreatePath(context),
        )
      ],
    );
    return SingleChildScrollView(
      child: Column(
        children: [
          settings,
          create,
        ],
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
              if (checked.isNotEmpty)
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
            final int item = order.removeAt(oldIndex);
            order.insert(newIndex, item);
            sortByNameAsc = null;
          });
          storage.setPathCreation(order);
        },
        children: order
            .map((e) => points[e])
            .whereNotNull()
            .map((Point point) => buildListItem(context, point))
            .toList(growable: false));
  }

  Widget buildListItem(BuildContext context, Point point) {
    return CheckboxListTile(
      key: ValueKey(point.id),
      secondary: SizedBox(
          width: 40,
          child: Stack(
            children: [
              Icon(
                point.category.iconData,
                color: point.color,
                size: 40,
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
                    child: Icon(
                      attr.iconData,
                      color: attr.color,
                      size: badgeSize,
                    ))
            ],
          )),
      title: Text('${point.name} | ${storage.users[point.ownerId]}'),
      subtitle: Text(
          [
            if (point.description?.isNotEmpty ?? false) point.description,
            formatCoords(point.coords, false)
          ].join('\n'),
          maxLines: 2),
      dense: true,
      isThreeLine: point.description?.isNotEmpty ?? false,
      value: checked.contains(point.id),
      onChanged: (bool? value) {
        setState(() {
          if (value!) {
            checked.add(point.id);
          } else {
            checked.remove(point.id);
          }
        });
      },
    );
  }

  void onAddPoint() async {
    developer.log('onAddPoint');
    List<Point>? selected = await Navigator.of(context).push(
        MaterialPageRoute<List<Point>>(
            builder: (context) => PointList(
                storage.features
                    .whereType<Point>()
                    .whereNot((e) => order.contains(e.id))
                    .toList(growable: false),
                storage.serverSettings!.id,
                storage.users,
                title: I18N.of(context).pickAPoint,
                multiple: true)));
    if (selected == null) {
      setState(() {});
      return;
    }
    setState(() {
      order.addAll(selected.map((e) => e.id));
    });
    storage.setPathCreation(order);
  }

  void onRemovePoints() {
    setState(() {
      order.removeWhere((e) => checked.contains(e));
      checked.clear();
    });
    storage.setPathCreation(order);
  }

  void sortByName() {
    if (sortByNameAsc == true) {
      order.sortBy((e) => points[e]!.name);
    } else {
      order.sort((a, b) => points[b]!.name.compareTo(points[a]!.name));
    }
  }

  void onChooseColor() async {
    Color? c = await chooseColorBlock(context,
        availableColors: _colors, initialColor: color);
    if (c != null) {
      setState(() {
        color = c;
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

  void onCreatePath(BuildContext context) async {
    List<Widget> lines = [Text(I18N.of(context).pathCreatedFrom(order.length))];
    if (deletePointsAfterCreation == null && checked.isNotEmpty) {
      int nChecked = checked.length;
      int nLocal = checked
          .where((e) => points[e]!.isLocal && points[e]!.ownerId != 0)
          .length;
      int nSystem = checked.where((e) => points[e]!.ownerId == 0).length;
      if (nLocal > 0 || nSystem > 0) {
        lines.add(Text(
            '${I18N.of(context).checkedPointsToBeDeleted(nChecked)}${I18N.of(context).ofWhich}'));
        if (nLocal > 0) {
          lines.add(Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('  \u2022 '),
              Expanded(
                  flex: 1,
                  child: Text(I18N.of(context).pathOfWhichLocal(nLocal)))
            ],
          ));
        }
        if (nSystem > 0) {
          lines.add(Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('  \u2022 '),
              Expanded(
                  flex: 1,
                  child: Text(I18N.of(context).pathOfWhichSystem(nSystem)))
            ],
          ));
        }
      } else {
        lines.add(
            Text('${I18N.of(context).checkedPointsToBeDeleted(nChecked)}.'));
      }
    } else if (deletePointsAfterCreation == true) {
      int n = order.length;
      int nLocal = order
          .where((e) => points[e]!.isLocal && points[e]!.ownerId != 0)
          .length;
      int nSystem = order.where((e) => points[e]!.ownerId == 0).length;
      if (nLocal > 0 || nSystem > 0) {
        lines.add(Text(
            '${I18N.of(context).allPointsToBeDeleted(n)}${I18N.of(context).ofWhich}'));
        if (nLocal > 0) {
          lines.add(Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('  \u2022 '),
              Expanded(
                  flex: 1,
                  child: Text(I18N.of(context).pathOfWhichLocal(nLocal)))
            ],
          ));
        }
        if (nSystem > 0) {
          lines.add(Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('  \u2022 '),
              Expanded(
                  flex: 1,
                  child: Text(I18N.of(context).pathOfWhichSystem(nSystem)))
            ],
          ));
        }
      } else {
        lines.add(Text('${I18N.of(context).allPointsToBeDeleted(n)}.'));
      }
    }
    bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(I18N.of(context).pathCreateCheckTitle),
              content: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                verticalDirection: VerticalDirection.down,
                mainAxisSize: MainAxisSize.min,
                children: lines,
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
    if (context.mounted) {
      Navigator.of(context).pop(createPath());
    }
  }

  PathCreationResult createPath() {
    List<LatLng> coords =
        order.map((e) => points[e]!.coords).toList(growable: false);
    Set<int> toDelete;
    if (deletePointsAfterCreation == null) {
      toDelete = Set.of(checked);
    } else if (deletePointsAfterCreation == true) {
      toDelete = order.map((e) => points[e]!.id).toSet();
    } else {
      toDelete = {};
    }
    return PathCreationResult(
        path: LineString.origSame(
            0, ownerId, nameInputController.text, deadline, null, color, {}, coords, false),
        toDelete: toDelete);
  }
}
