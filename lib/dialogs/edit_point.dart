import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:oko/data.dart';
import 'package:oko/i18n.dart';

class _EditPointDialogState extends State<EditPointDialog> {
  late LatLng location;
  late PointCategory category;
  late int ownerId;
  final TextEditingController nameInputController = TextEditingController();
  final TextEditingController descriptionInputController =
      TextEditingController();

  String? nameInputError;

  @override
  void initState() {
    super.initState();
    location = widget.point.coords;
    category = widget.point.category;
    ownerId = widget.point.ownerId;
    nameInputController.text = widget.point.name;
    descriptionInputController.text = widget.point.description ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (nameInputController.text.isNotEmpty) {
      nameInputError = null;
    } else {
      nameInputError = I18N.of(context).errorNameRequired;
    }
    return SimpleDialog(
      contentPadding: const EdgeInsets.all(5),
      children: <Widget>[
        Text('Lat: ${location.latitude}'),
        Text('Lng: ${location.longitude}'),
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(I18N.of(context).position),
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: () {
                setState(() {
                  location = widget.targetLocation;
                });
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(0, 0, 5, 0),
              child: Text(I18N.of(context).owner),
            ),
            Container(
                padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
                child: DropdownButton<int>(
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
                    }).toList(growable: false)))
          ],
        ),
        TextField(
          controller: nameInputController,
          decoration: InputDecoration(
              labelText: I18N.of(context).nameLabel, errorText: nameInputError),
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
        TextField(
          controller: descriptionInputController,
          decoration: InputDecoration(
            labelText: I18N.of(context).descriptionLabel,
          ),
          maxLines: null,
        ),
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
                padding: const EdgeInsets.fromLTRB(0, 0, 5, 0),
                child: Text(I18N.of(context).category)),
            Container(
                padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
                child: DropdownButton<PointCategory>(
                    value: category,
                    icon: const Icon(Icons.arrow_downward),
                    onChanged: (PointCategory? v) {
                      setState(() {
                        category = v!;
                      });
                    },
                    items: PointCategory.defaultCategories
                        .map((PointCategory cat) {
                      return DropdownMenuItem<PointCategory>(
                        value: cat,
                        child: Row(children: [
                          Icon(cat.iconData),
                          Container(
                            padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
                            child: Text(I18N.of(context).categories(cat)),
                          )
                        ]),
                      );
                    }).toList(growable: false)))
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: ElevatedButton(
                  child: Text(I18N.of(context).dialogSave),
                  onPressed: _isValid() ? _save : null,
                )),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: ElevatedButton(
                  child: Text(I18N.of(context).dialogCancel),
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                ))
          ],
        ),
      ],
    );
  }

  bool _isValid() {
    return nameInputController.text.isNotEmpty;
  }

  void _save() {
    Point point = Point(
        widget.point.id,
        ownerId,
        widget.point.origOwnerId,
        nameInputController.text,
        widget.point.origName,
        descriptionInputController.text.isEmpty
            ? null
            : descriptionInputController.text,
        widget.point.origDescription,
        location,
        widget.point.origCoords,
        category,
        widget.point.origCategory,
        widget.point.deleted);
    Navigator.of(context).pop(point);
  }

  @override
  void dispose() {
    nameInputController.dispose();
    descriptionInputController.dispose();
    super.dispose();
  }
}

class EditPointDialog extends StatefulWidget {
  final Point point;
  final LatLng targetLocation;
  final UsersView users;

  const EditPointDialog(
      {Key? key,
      required this.point,
      required this.targetLocation,
      required this.users})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _EditPointDialogState();
}
