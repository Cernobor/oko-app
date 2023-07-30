import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:oko/data.dart';
import 'package:oko/feature_filters.dart';
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
  final String? title;
  final bool multiple;

  const PointList(this.points,
      {this.title, this.multiple = false, Key? key})
      : super(key: key);

  @override
  State createState() => _PointListState();
}

class _PointListState extends State<PointList> {
  late Storage storage;
  late final List<Point> points;
  final Set<int> checked = {};
  FeatureFilter filter = FeatureFilter.empty();
  Sort sort = Sort.name;
  int asc = 1;

  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    points = List.of(widget.points, growable: false);
    searchController.addListener(() {
      setState(() {
        filter.searchTerm = searchController.text;
        storage.setFeatureFilter(FeatureFilterInst.featureList, filter);
      });
    });

    getStorage().whenComplete(() => setState(() {
          asc = storage.featureListSortDir;
          sort = storage.featureListSortKey;

          filter = storage.getFeatureFilter(FeatureFilterInst.featureList);
          searchController.text = filter.searchTerm;
          doSort();
        }));
  }

  Future<void> getStorage() async {
    storage = await Storage.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: buildAppBar(context),
        body: buildBody(context),
      ),
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    Widget action;
    if (widget.multiple) {
      action = IconButton(
        icon: Badge(
          label: Text(checked.length.toString()),
          child: const Icon(Icons.check),
        ),
        onPressed: () {
          Navigator.of(context).pop(points
              .where((p) => checked.contains(p.id))
              .toList(growable: false));
        },
      );
    } else {
      action = IconButton(
        tooltip: I18N.of(context).applyFilterToMap,
        icon: const SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              children: [
                Align(
                    alignment: Alignment.topLeft,
                    child: Icon(Icons.filter_alt)),
                Align(alignment: Alignment.bottomRight, child: Icon(Icons.map)),
              ],
            )),
        onPressed: onStoreMapFilter,
      );
    }
    return AppBar(
      title: Text(
          widget.title == null ? I18N.of(context).poiListTitle : widget.title!),
      primary: true,
      leading: BackButton(
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [action],
    );
  }

  Widget buildBody(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      verticalDirection: VerticalDirection.down,
      children: [
        buildFilterRow(context),
        Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                  icon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: searchController.clear,
                          icon: const Icon(Icons.clear),
                          tooltip: I18N.of(context).clearButtonTooltip,
                        )),
              controller: searchController,
            )),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Divider(
            thickness: 0,
            height: 0,
          ),
        ),
        Expanded(child: buildPointList(context))
      ],
    );
  }

  Widget buildFilterRow(BuildContext context) {
    const double filterButtonIconSize = 35;
    return Row(
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
                      color: filter.doesFilterUsers(storage.users.keys)
                          ? Theme.of(context).colorScheme.primary
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
                      color: filter.doesFilterCategories()
                          ? Theme.of(context).colorScheme.primary
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
                      color: filter.doesFilterAttributes()
                          ? Theme.of(context).colorScheme.primary
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
                      color: filter.doesFilterEditState()
                          ? Theme.of(context).colorScheme.primary
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
                                child: Text(_sortToString(sort, context)),
                              ))
                          .toList(growable: false),
                      icon: const Icon(Icons.sort),
                      value: sort,
                      onChanged: onSort,
                    )),
                IconButton(
                  icon:
                      Icon(asc > 0 ? Icons.arrow_upward : Icons.arrow_downward),
                  onPressed: onSortDir,
                )
              ])
        ]);
  }

  Widget buildPointList(BuildContext context) {
    return ListView(
        children: filter
            .filter(points)
            .map((Point point) => buildListTile(context, point))
            .toList(growable: false));
  }

  Widget buildListTile(BuildContext context, Point point) {
    const badgeSize = 13.7;
    Widget icon = SizedBox(
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
        ));
    Widget title = Text('${point.name} | ${storage.users[point.ownerId]}');
    Widget subtitle = Text(
        [
          if (point.description?.isNotEmpty ?? false) point.description,
          formatCoords(point.coords, false)
        ].join('\n'),
        maxLines: 2);
    bool isThreeLine = point.description?.isNotEmpty ?? false;
    if (widget.multiple) {
      return CheckboxListTile(
        value: checked.contains(point.id),
        secondary: icon,
        title: title,
        subtitle: subtitle,
        isThreeLine: isThreeLine,
        onChanged: (bool? value) {
          setState(() {
            if (value ?? false) {
              checked.add(point.id);
            } else {
              checked.remove(point.id);
            }
          });
        },
      );
    } else {
      return ListTile(
        leading: SizedBox(
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
        onTap: () {
          Navigator.of(context).pop(point);
        },
      );
    }
  }

  void onStoreMapFilter() {
    storage.setFeatureFilter(FeatureFilterInst.map, filter);
  }

  Future<void> onUsersButtonPressed() async {
    bool changed = await filter.setUsers(
        context: context, users: storage.users, myId: storage.serverSettings?.id);
    if (changed) {
      setState(() {});
      await storage.setFeatureFilter(FeatureFilterInst.featureList, filter);
    }
  }

  Future<void> onCategoryButtonPressed() async {
    bool changed = await filter.setCategories(context: context);
    if (changed) {
      setState(() {});
      await storage.setFeatureFilter(FeatureFilterInst.featureList, filter);
    }
  }

  Future<void> onAttributesButtonPressed() async {
    bool changed = await filter.setAttributes(context: context);
    if (changed) {
      setState(() {});
      await storage.setFeatureFilter(FeatureFilterInst.featureList, filter);
    }
  }

  Future<void> onEditStateButtonPressed() async {
    bool changed = await filter.setEditState(context: context);
    if (changed) {
      setState(() {});
      await storage.setFeatureFilter(FeatureFilterInst.featureList, filter);
    }
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
          var ua = storage.users[a.ownerId];
          var ub = storage.users[b.ownerId];
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
    await storage.setFeatureListSortKey(sort);
    doSort();
    setState(() {});
  }

  void onSortDir() async {
    asc = asc * -1;
    await storage.setFeatureListSortDir(asc);
    doSort();
    setState(() {});
  }
}
