import 'package:diacritic/diacritic.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oko/data.dart';
import 'package:oko/dialogs/multi_checker.dart';
import 'package:oko/dialogs/single_chooser.dart';
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

bool _fulltext(Point point, String needle) {
  String n = removeDiacritics(needle).toLowerCase();
  return removeDiacritics(point.name).toLowerCase().contains(n) ||
      removeDiacritics(point.description ?? '').toLowerCase().contains(n);
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
  Set<PointAttribute> checkedAttributes = <PointAttribute>{};
  bool exact = false;
  EditState editState = EditState.anyState;
  Sort sort = Sort.name;
  int asc = 1;

  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    points = List.of(widget.points, growable: false);
    searchController.addListener(() {
      setState(() {});
    });

    getStorage().whenComplete(() => setState(() {
          asc = storage.pointListSortDir;
          sort = storage.pointListSortKey;
          exact = storage.pointListAttributeFilterExact;
          editState = storage.pointListEditStateFilter;
          checkedCategories.clear();
          checkedCategories.addAll(storage.pointListCheckedCategories);
          checkedUsers.clear();
          checkedUsers.addAll(storage.pointListCheckedUsers);
          checkedAttributes.clear();
          checkedAttributes.addAll(storage.pointListCheckedAttributes);
          doSort();
        }));
  }

  Future<void> getStorage() async {
    storage = await Storage.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    const double filterButtonIconSize = 35;
    const badgeSize = 13.7;
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('List of points'),
          primary: true,
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
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
                            iconSize: filterButtonIconSize,
                            tooltip: I18N.of(context).filterByOwner,
                            icon: Icon(
                              Icons.people,
                              color: checkedUsers.length < widget.users.length
                                  ? const Color(0xffff0000)
                                  : null,
                            ),
                            onPressed: onUsersButtonPressed,
                          )),
                      Expanded(
                          flex: 0,
                          child: IconButton(
                            iconSize: filterButtonIconSize,
                            tooltip: I18N.of(context).filterByCategory,
                            icon: Icon(
                              Icons.category,
                              color: checkedCategories.length <
                                      PointCategory.allCategories.length
                                  ? const Color(0xffff0000)
                                  : null,
                            ),
                            onPressed: onCategoryButtonPressed,
                          )),
                      Expanded(
                          flex: 0,
                          child: IconButton(
                            iconSize: filterButtonIconSize,
                            tooltip: I18N.of(context).filterByAttributes,
                            icon: Icon(
                              Icons.edit_attributes,
                              color: (exact || checkedAttributes.isNotEmpty)
                                  ? const Color(0xffff0000)
                                  : null,
                            ),
                            onPressed: onAttributesButtonPressed,
                          )),
                      Expanded(
                          flex: 0,
                          child: IconButton(
                            iconSize: filterButtonIconSize,
                            tooltip: I18N.of(context).filterByEditState,
                            icon: Icon(
                              Icons.edit,
                              color: editState != EditState.anyState
                                  ? const Color(0xffff0000)
                                  : null,
                            ),
                            onPressed: onEditStateButtonPressed,
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
            Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  decoration: const InputDecoration(icon: Icon(Icons.search)),
                  controller: searchController,
                )),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Divider(
                thickness: 0,
                height: 0,
              ),
            ),
            Expanded(
                child: ListView(
                    children: points
                        .where((point) =>
                            checkedUsers.contains(point.ownerId) &&
                            checkedCategories.contains(point.category) &&
                            ((editState == EditState.newState &&
                                    point.isLocal) ||
                                (editState == EditState.editedState &&
                                    point.isEdited) ||
                                (editState == EditState.pristineState &&
                                    !point.isEdited &&
                                    !point.isLocal) ||
                                (editState == EditState.anyState)) &&
                            (exact
                                ? setEquals(point.attributes, checkedAttributes)
                                : (point.attributes.any((attr) =>
                                        checkedAttributes.contains(attr))) ||
                                    checkedAttributes.isEmpty) &&
                            _fulltext(point, searchController.text))
                        .map((Point point) => ListTile(
                              leading: SizedBox(
                                  width: 40,
                                  child: Stack(
                                    children: [
                                      Icon(
                                        point.category.iconData,
                                        color: point.deleted ? point.color.withOpacity(0.5) : point.color,
                                        size: 40,
                                      ),
                                      if (point.isEdited)
                                        const Align(
                                          alignment: Alignment(1, -1),
                                          child: Icon(Icons.edit,
                                              size: badgeSize,
                                              color: Color(0xffff0000)),
                                        ),
                                      if (point.isLocal)
                                        const Align(
                                          alignment: Alignment(1, -1),
                                          child: Icon(Icons.star,
                                              size: badgeSize,
                                              color: Color(0xffff0000)),
                                        ),
                                      for (var attr in point.attributes)
                                        Align(
                                            alignment: Alignment(
                                                attr.xAlign, attr.yAlign),
                                            child: Icon(
                                              attr.iconData,
                                              color: attr.color,
                                              size: badgeSize,
                                            ))
                                    ],
                                  )),
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
        ),
      ),
    );
  }

  Future<void> onUsersButtonPressed() async {
    MultiCheckerResult<int>? result = await showDialog<MultiCheckerResult<int>>(
      context: context,
      builder: (context) => MultiChecker<int>(
        items: widget.users.keys.toList(growable: false),
        checkedItems: checkedUsers,
        titleBuilder: (int uid, bool _) => Text(
            '${widget.users[uid] ?? '<unknown ID: $uid>'}${uid == widget.myId ? ' (${I18N.of(context).me})' : ''}'),
      ),
    );
    if (result == null) {
      return;
    }
    await storage.setPointListCheckedUsers(result.checked);
    setState(() {
      checkedUsers.clear();
      checkedUsers.addAll(storage.pointListCheckedUsers);
    });
  }

  Future<void> onCategoryButtonPressed() async {
    MultiCheckerResult<PointCategory>? result =
        await showDialog<MultiCheckerResult<PointCategory>>(
      context: context,
      builder: (context) => MultiChecker<PointCategory>(
        items: PointCategory.allCategories,
        checkedItems: checkedCategories,
        titleBuilder: (PointCategory cat, bool _) =>
            Text(I18N.of(context).category(cat)),
        secondaryBuilder: (PointCategory cat, bool _) => Icon(cat.iconData),
      ),
    );
    if (result == null) {
      return;
    }
    await storage.setPointListCheckedCategories(result.checked);
    setState(() {
      checkedCategories.clear();
      checkedCategories.addAll(storage.pointListCheckedCategories);
    });
  }

  Future<void> onAttributesButtonPressed() async {
    MultiCheckerResult<PointAttribute>? result =
        await showDialog<MultiCheckerResult<PointAttribute>>(
      context: context,
      builder: (context) => MultiChecker<PointAttribute>(
        switcher: MultiCheckerSwitcher(
            value: exact,
            offLabel: I18N.of(context).intersection,
            onLabel: I18N.of(context).exact),
        items: PointAttribute.attributes,
        checkedItems: checkedAttributes,
        titleBuilder: (PointAttribute attr, bool _) =>
            Text(I18N.of(context).attribute(attr)),
        secondaryBuilder: (PointAttribute attr, bool _) => Icon(attr.iconData),
      ),
    );
    if (result == null) {
      return;
    }
    await storage.setPointListAttributeFilterExact(result.switcher);
    await storage.setPointListCheckedAttributes(result.checked);
    setState(() {
      exact = result.switcher;
      checkedAttributes.clear();
      checkedAttributes.addAll(storage.pointListCheckedAttributes);
    });
  }

  Future<void> onEditStateButtonPressed() async {
    var titles = {
      EditState.newState: I18N.of(context).newState,
      EditState.editedState: I18N.of(context).editedState,
      EditState.pristineState: I18N.of(context).pristineState,
      EditState.anyState: I18N.of(context).anyState,
    };
    var secondaries = const {
      EditState.newState: Icon(Icons.star),
      EditState.editedState: Icon(Icons.edit),
      EditState.pristineState: SizedBox(),
      EditState.anyState: SizedBox()
    };
    EditState? result = await showDialog<EditState>(
      context: context,
      builder: (context) => SingleChooser<EditState>(
        value: editState,
        items: EditState.values,
        titleBuilder: (item, _) => Text(titles[item]!),
        secondaryBuilder: (item, _) => secondaries[item],
      ),
    );
    if (result == null) {
      return;
    }
    await storage.setPointListEditStateFilter(result);
    setState(() {
      editState = result;
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
    await storage.setPointListSortKey(sort);
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
