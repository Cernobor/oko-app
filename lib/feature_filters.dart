import 'package:diacritic/diacritic.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oko/data.dart';
import 'package:oko/dialogs/multi_checker.dart';
import 'package:oko/dialogs/single_chooser.dart';
import 'package:oko/i18n.dart';
import 'package:oko/constants.dart' as constants;

class FeatureFilter {
  Set<FeatureType> types;
  Set<int> users;
  Set<PointCategory> categories;
  Set<PointAttribute> attributes;
  bool exact;
  EditState editState;
  String searchTerm;

  FeatureFilter(this.types, this.users, this.categories, this.attributes, this.exact,
      this.editState, this.searchTerm);

  FeatureFilter.empty() : this(Set.of(FeatureType.values), {}, {}, {}, false, EditState.anyState, '');

  FeatureFilter.copy(FeatureFilter other)
      : this(
            Set<FeatureType>.of(other.types),
            Set<int>.of(other.users),
            Set<PointCategory>.of(other.categories),
            Set<PointAttribute>.of(other.attributes),
            other.exact,
            other.editState,
            other.searchTerm);

  bool passes(Feature feature) =>
      passesTypes(feature) &&
      passesUsers(feature) &&
      passesCategories(feature) &&
      passesEditState(feature) &&
      passesAttributes(feature) &&
      passesSearch(feature);

  bool passesTypes(Feature feature) =>
      (feature.isPoint() && types.contains(FeatureType.point) ||
          (feature.isPoly() &&
              feature.asPoly().polygon &&
              types.contains(FeatureType.polygon)) ||
          (feature.isPoly() &&
              !feature.asPoly().polygon &&
              types.contains(FeatureType.polyline)));

  bool passesUsers(Feature feature) => users.contains(feature.ownerId);

  bool passesCategories(Feature feature) => feature.isPoint()
      ? categories.contains(feature.asPoint().category)
      : true;

  /*anyState,
  pristineState,
  newState,
  editedState,
  deletedState,
  editedDeletedState*/
  bool passesEditState(Feature feature) =>
      editState == EditState.anyState ||
      (editState == EditState.pristineState &&
          !feature.isEdited &&
          !feature.isLocal &&
          !feature.deleted) ||
      (editState == EditState.newState && feature.isLocal) ||
      (editState == EditState.editedState && feature.isEdited) ||
      (editState == EditState.deletedState && feature.deleted) ||
      (editState == EditState.editedDeletedState &&
          feature.deleted &&
          feature.isEdited);

  bool passesAttributes(Feature feature) {
    if (feature.isPoint()) {
      Point point = feature.asPoint();
      if (exact) {
        return setEquals(point.attributes, attributes);
      }
      return (point.attributes.any((attr) => attributes.contains(attr))) ||
          attributes.isEmpty;
    }
    return true;
  }

  bool passesSearch(Feature feature) {
    String n = removeDiacritics(searchTerm).toLowerCase();
    return removeDiacritics(feature.name).toLowerCase().contains(n) ||
        removeDiacritics(feature.description ?? '').toLowerCase().contains(n);
  }

  Iterable<Feature> filter(Iterable<Feature> points) => points.where(passes);

  bool doesFilterType() => !types.containsAll(FeatureType.values);

  bool doesFilterUsers(Iterable<int> allUsers) => !users.containsAll(allUsers);

  bool doesFilterCategories() =>
      !categories.containsAll(PointCategory.allCategories);

  bool doesFilterEditState() => editState != EditState.anyState;

  bool doesFilterAttributes() => exact || attributes.isNotEmpty;

  bool doesFilterSearch() => searchTerm.isNotEmpty;

  bool doesFilter(Iterable<int> allUsers) =>
      doesFilterType() ||
      doesFilterUsers(allUsers) ||
      doesFilterCategories() ||
      doesFilterEditState() ||
      doesFilterAttributes() ||
      doesFilterSearch();

  Future<bool> setTypes(BuildContext context) async {
    MultiCheckerResult<FeatureType>? result = await showDialog<MultiCheckerResult<FeatureType>>(
      context: context,
      builder: (context) => MultiChecker<FeatureType>(
        items: FeatureType.values,
        checkedItems: types,
        titleBuilder: (FeatureType t, bool _) => Text(I18N.of(context).featureTypeName(t)),
        secondaryBuilder: (FeatureType t, bool _) {
          switch (t) {
            case FeatureType.point:
              return const Icon(constants.pointIcon);
            case FeatureType.polyline:
              return const Icon(constants.polylineIcon);
            case FeatureType.polygon:
              return const Icon(constants.polygonIcon);
          }
        },
      ),
    );
    if (result == null) {
      return false;
    }
    types = result.checked;
    return true;
  }
  
  Future<bool> setUsers(
      {required BuildContext context,
      required Map<int, String> users,
      int? myId}) async {
    MultiCheckerResult<int>? result = await showDialog<MultiCheckerResult<int>>(
      context: context,
      builder: (context) => MultiChecker<int>(
        items: users.keys.toList(growable: false),
        checkedItems: this.users,
        titleBuilder: (int uid, bool _) => Text(
            '${users[uid] ?? '<unknown ID: $uid>'}${uid == myId ? ' (${I18N.of(context).me})' : ''}'),
      ),
    );
    if (result == null) {
      return false;
    }
    this.users = result.checked;
    return true;
  }

  Future<bool> setCategories({required BuildContext context}) async {
    MultiCheckerResult<PointCategory>? result =
        await showDialog<MultiCheckerResult<PointCategory>>(
      context: context,
      builder: (context) => MultiChecker<PointCategory>(
        items: PointCategory.allCategories,
        checkedItems: categories,
        titleBuilder: (PointCategory cat, bool _) =>
            Text(I18N.of(context).category(cat)),
        secondaryBuilder: (PointCategory cat, bool _) => Icon(cat.iconData),
      ),
    );
    if (result == null) {
      return false;
    }
    categories = result.checked;
    return true;
  }

  Future<bool> setAttributes({required BuildContext context}) async {
    MultiCheckerResult<PointAttribute>? result =
        await showDialog<MultiCheckerResult<PointAttribute>>(
      context: context,
      builder: (context) => MultiChecker<PointAttribute>(
        switcher: MultiCheckerSwitcher(
            value: exact,
            offLabel: I18N.of(context).intersection,
            onLabel: I18N.of(context).exact),
        items: PointAttribute.attributes,
        checkedItems: attributes,
        titleBuilder: (PointAttribute attr, bool _) =>
            Text(I18N.of(context).attribute(attr)),
        secondaryBuilder: (PointAttribute attr, bool _) => Icon(attr.iconData),
      ),
    );
    if (result == null) {
      return false;
    }
    exact = result.switcher;
    attributes = result.checked;
    return true;
  }

  Future<bool> setEditState({required BuildContext context}) async {
    var titles = {
      EditState.newState: I18N.of(context).newState,
      EditState.editedState: I18N.of(context).editedState,
      EditState.deletedState: I18N.of(context).deletedState,
      EditState.editedDeletedState: I18N.of(context).editedDeletedState,
      EditState.pristineState: I18N.of(context).pristineState,
      EditState.anyState: I18N.of(context).anyState,
    };
    var secondaries = {
      EditState.newState: const Icon(Icons.star),
      EditState.editedState: const Icon(Icons.edit),
      EditState.deletedState: const Icon(Icons.delete),
      EditState.editedDeletedState: const SizedBox(
          width: 35,
          height: 35,
          child: Stack(
            children: [
              Align(alignment: Alignment.topLeft, child: Icon(Icons.delete)),
              Align(alignment: Alignment.bottomRight, child: Icon(Icons.edit)),
            ],
          )),
      EditState.pristineState: const SizedBox(),
      EditState.anyState: const SizedBox()
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
      return false;
    }
    editState = result;
    return true;
  }
}
