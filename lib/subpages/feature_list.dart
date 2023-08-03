import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:oko/data.dart';
import 'package:oko/feature_filters.dart';
import 'package:oko/i18n.dart';
import 'package:oko/storage.dart';
import 'package:oko/utils.dart';
import 'package:oko/constants.dart' as constants;

String _sortToString(Sort sort, BuildContext context) {
  switch (sort) {
    case Sort.owner:
      return I18N.of(context).owner;
    case Sort.name:
      return I18N.of(context).nameLabel;
  }
}

class FeatureList extends StatefulWidget {
  final String? title;
  final bool multiple;
  final FeatureType? typeRestriction;

  const FeatureList(
      {this.title, this.multiple = false, this.typeRestriction, Key? key})
      : super(key: key);

  @override
  State createState() => _FeatureListState();
}

class _FeatureListState extends State<FeatureList> {
  late Future<void> storageWait;
  late Storage storage;
  late final List<Feature> features;
  final Set<int> checked = {};
  FeatureFilter filter = FeatureFilter.empty();
  Sort sort = Sort.name;
  int asc = 1;

  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    storageWait = Storage.getInstance().then((value) {
      setState(() {
        storage = value;
        switch (widget.typeRestriction) {
          case null:
            features = List.of(storage.features);
            break;
          case FeatureType.point:
            features =
                storage.features.whereType<Point>().toList();
            break;
          case FeatureType.polyline:
            features = storage.features
                .whereType<Poly>()
                .whereNot((e) => e.polygon)
                .toList();
            break;
          case FeatureType.polygon:
            features = storage.features
                .whereType<Poly>()
                .where((e) => e.polygon)
                .toList();
            break;
        }
        asc = storage.featureListSortDir;
        sort = storage.featureListSortKey;
        filter = storage.getFeatureFilter(FeatureFilterInst.featureList);
        searchController.text = filter.searchTerm;
        doSort();
        searchController.addListener(() {
          setState(() {
            filter.searchTerm = searchController.text;
            storage.setFeatureFilter(FeatureFilterInst.featureList, filter);
          });
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: storageWait,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: Scaffold(
                appBar: buildAppBar(context),
                body: buildBody(context),
              ),
            );
          }
          return Container();
        });
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
          Navigator.of(context).pop(features
              .where((f) => checked.contains(f.id))
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
        Expanded(child: buildList(context))
      ],
    );
  }

  Widget buildFilterRow(BuildContext context) {
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
                    iconSize: constants.filterButtonIconSize,
                    tooltip: I18N.of(context).filterByType,
                    icon: Icon(
                      constants.typeFilterIcon,
                      color: filter.doesFilterType()
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    onPressed: onTypesButtonPressed,
                  )),
              Expanded(
                  flex: 0,
                  child: IconButton(
                    iconSize: constants.filterButtonIconSize,
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
                    iconSize: constants.filterButtonIconSize,
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
                    iconSize: constants.filterButtonIconSize,
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
                    iconSize: constants.filterButtonIconSize,
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

  Widget buildList(BuildContext context) {
    return ListView(
        children: filter
            .filter(features)
            .map((Feature feature) => buildListTile(context, feature))
            .toList(growable: false));
  }

  Widget buildListTile(BuildContext context, Feature feature) {
    Widget icon = SizedBox(
        width: 40,
        child: Stack(
          children: [
            Icon(
              feature.isPoint()
                  ? feature.asPoint().category.iconData
                  : (feature.asPoly().polygon
                      ? constants.polygonIcon
                      : constants.polylineIcon),
              color: feature.color,
              size: 40,
            ),
            if (feature.isLocal)
              Align(
                alignment: const Alignment(1, -1),
                child: Icon(Icons.star,
                    size: constants.badgeSize,
                    color: Theme.of(context).colorScheme.primary),
              ),
            if (feature.isEdited)
              Align(
                alignment: const Alignment(1, -1),
                child: Icon(Icons.edit,
                    size: constants.badgeSize,
                    color: Theme.of(context).colorScheme.primary),
              ),
            if (feature.deleted)
              Align(
                alignment: feature.isEdited
                    ? const Alignment(1, 0)
                    : const Alignment(1, -1),
                child: Icon(Icons.delete,
                    size: constants.badgeSize,
                    color: Theme.of(context).colorScheme.primary),
              ),
            if (feature.isLocked)
              Align(
                alignment: const Alignment(1, -1),
                child: Icon(Icons.lock,
                    size: constants.badgeSize,
                    color: Theme.of(context).colorScheme.primary),
              ),
            if (feature.isPoint())
              for (var attr in feature.asPoint().attributes)
                Align(
                    alignment: Alignment(attr.xAlign, attr.yAlign),
                    child: Icon(
                      attr.iconData,
                      color: attr.color,
                      size: constants.badgeSize,
                    ))
          ],
        ));
    Widget title = Text('${feature.name} | ${storage.users[feature.ownerId]}');
    Widget subtitle = Text(
        [
          if (feature.description?.isNotEmpty ?? false) feature.description,
          formatCoords(feature.center(), false) + (feature.isPoly() ? ' (${I18N.of(context).centroid})' : 'xxx')
        ].join('\n'),
        maxLines: 2);
    bool isThreeLine = feature.description?.isNotEmpty ?? false;
    if (widget.multiple) {
      return CheckboxListTile(
        value: checked.contains(feature.id),
        secondary: icon,
        title: title,
        subtitle: subtitle,
        isThreeLine: isThreeLine,
        onChanged: (bool? value) {
          setState(() {
            if (value ?? false) {
              checked.add(feature.id);
            } else {
              checked.remove(feature.id);
            }
          });
        },
      );
    } else {
      return ListTile(
        leading: icon,
        title: Text('${feature.name} | ${storage.users[feature.ownerId]}'),
        subtitle: subtitle,
        dense: true,
        isThreeLine: feature.description?.isNotEmpty ?? false,
        onTap: () {
          Navigator.of(context).pop(feature);
        },
      );
    }
  }

  void onStoreMapFilter() {
    storage.setFeatureFilter(FeatureFilterInst.map, filter);
  }

  Future<void> onTypesButtonPressed() async {
    bool changed = await filter.setTypes(context);
    if (changed) {
      setState(() {});
      await storage.setFeatureFilter(FeatureFilterInst.featureList, filter);
    }
  }

  Future<void> onUsersButtonPressed() async {
    bool changed = await filter.setUsers(
        context: context,
        users: storage.users,
        myId: storage.serverSettings?.id);
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
        features.sort((a, b) =>
            asc *
            removeDiacritics(a.name)
                .toLowerCase()
                .compareTo(removeDiacritics(b.name).toLowerCase()));
        break;
      case Sort.owner:
        features.sort((a, b) {
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
