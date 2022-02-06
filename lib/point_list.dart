import 'dart:developer' as developer;

import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:oko/data.dart';
import 'package:oko/dialogs/multi_checker.dart';
import 'package:oko/i18n.dart';
import 'package:oko/storage.dart';
import 'package:oko/utils.dart';

String _sortToString(Sort sort, BuildContext context) {
  switch (sort) {
    case Sort.owner:
      return I18N.of(context).owner;
    case Sort.name:
      return I18N.of(context).nameLabel;
  }
}

class PointList extends StatefulWidget {
  final List<Point> points;
  final int? myId;
  final Users users;

  const PointList(this.points, this.myId, this.users, {Key? key})
      : super(key: key);

  @override
  State createState() => _PointListState();
}

class _PointListState extends State<PointList> {
  late Storage storage;
  late final List<Point> points;
  Set<int> checkedUsers = <int>{};
  Set<PointCategory> checkedCategories = <PointCategory>{};
  Sort sort = Sort.name;
  int asc = 1;

  @override
  void initState() {
    super.initState();
    points = List.of(widget.points, growable: false);

    getStorage().whenComplete(() => setState(() {
          asc = storage.pointListSortDir;
          sort = storage.pointListSort;
          checkedCategories.clear();
          developer.log('modified checkedCategories: $checkedCategories');
          checkedCategories.addAll(storage.pointListCheckedCategories);
          developer.log('modified checkedCategories: $checkedCategories');
          checkedUsers.clear();
          checkedUsers.addAll(storage.pointListCheckedUsers);
          doSort();
        }));
  }

  Future<void> getStorage() async {
    storage = await Storage.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('List of points'),
          primary: true,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          verticalDirection: VerticalDirection.down,
          children: [
            Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 0,
                          child: IconButton(
                            icon: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Icon(
                                  Icons.people,
                                  size: 40,
                                  color: checkedUsers.length <
                                          widget.users.length
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(context).colorScheme.primary,
                                )),
                            onPressed: onUsersButtonPressed,
                          )),
                      Expanded(
                          flex: 0,
                          child: IconButton(
                            icon: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Icon(
                                  Icons.category,
                                  size: 40,
                                  color: checkedCategories.length <
                                          PointCategory.allCategories.length
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(context).colorScheme.primary,
                                )),
                            onPressed: onCategoryButtonPressed,
                          ))
                    ],
                  ),
                  Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                            flex: 0,
                            child: DropdownButton<Sort>(
                              items: Sort.values
                                  .map((sort) => DropdownMenuItem<Sort>(
                                        value: sort,
                                        child:
                                            Text(_sortToString(sort, context)),
                                      ))
                                  .toList(growable: false),
                              icon: const Icon(Icons.sort),
                              value: sort,
                              onChanged: onSort,
                            )),
                        IconButton(
                          icon: Icon(asc > 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward),
                          onPressed: onSortDir,
                        )
                      ])
                ]),
            const Divider(),
            Expanded(
                child: ListView(
                    children: points
                        .where((point) => checkedUsers.contains(point.ownerId))
                        .where((point) =>
                            checkedCategories.contains(point.category))
                        .map((Point point) => ListTile(
                              leading: Icon(point.category.iconData,
                                  color: getPoiColor(point, widget.myId)),
                              title: Text(point.name),
                              subtitle: Text(
                                  [
                                    if (point.description?.isNotEmpty ?? false)
                                      point.description,
                                    formatCoords(point.coords, false)
                                  ].join('\n'),
                                  maxLines: 2),
                              dense: true,
                              isThreeLine:
                                  point.description?.isNotEmpty ?? false,
                              onTap: () {
                                Navigator.of(context).pop(point);
                              },
                            ))
                        .toList(growable: false)))
          ],
        ));
  }

  Future<void> onUsersButtonPressed() async {
    Set<int>? checked = await showDialog<Set<int>>(
      context: context,
      builder: (context) => MultiChecker<int>(
        items: widget.users.keys.toList(growable: false),
        checkedItems: checkedUsers,
        titleBuilder: (int uid, bool _) => Text(
            '${widget.users[uid] ?? '<unknown ID: $uid>'}${uid == widget.myId ? ' (${I18N.of(context).me})' : ''}'),
      ),
    );
    if (checked == null) {
      return;
    }
    await storage.setPointListCheckedUsers(checked);
    setState(() {
      checkedUsers.clear();
      checkedUsers.addAll(storage.pointListCheckedUsers);
    });
  }

  Future<void> onCategoryButtonPressed() async {
    Set<PointCategory>? checked = await showDialog<Set<PointCategory>>(
      context: context,
      builder: (context) => MultiChecker<PointCategory>(
        items: PointCategory.allCategories,
        checkedItems: checkedCategories,
        titleBuilder: (PointCategory cat, bool _) =>
            Text(I18N.of(context).categories(cat)),
        secondaryBuilder: (PointCategory cat, bool _) => Icon(cat.iconData),
      ),
    );
    if (checked == null) {
      return;
    }
    await storage.setPointListCheckedCategories(checked);
    setState(() {
      checkedCategories.clear();
      checkedCategories.addAll(storage.pointListCheckedCategories);
    });
  }

  void doSort() {
    switch (sort) {
      case Sort.name:
        points.sort((a, b) =>
            asc *
            removeDiacritics(a.name)
                .toLowerCase()
                .compareTo(removeDiacritics(b.name).toLowerCase()));
        break;
      case Sort.owner:
        points.sort((a, b) {
          var ua = widget.users[a.ownerId];
          var ub = widget.users[b.ownerId];
          int c;
          if (ua == null && ub == null) {
            c = a.ownerId.compareTo(b.ownerId);
          } else if (ua == null && ub != null) {
            c = 1;
          } else if (ua != null && ub == null) {
            c = -1;
          } else {
            c = removeDiacritics(ua!)
                .toLowerCase()
                .compareTo(removeDiacritics(ub!).toLowerCase());
          }
          return asc * c;
        });
        break;
      default:
        break;
    }
  }

  void onSort(Sort? s) async {
    if (s == null) {
      return;
    }
    sort = s;
    await storage.setPointListSort(sort);
    doSort();
    setState(() {});
  }

  void onSortDir() async {
    asc = asc * -1;
    await storage.setPointListSortDir(asc);
    doSort();
    setState(() {});
  }
}
