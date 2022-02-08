import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:oko/data.dart';
import 'package:oko/i18n.dart';

class EditPoint extends StatefulWidget {
  final Point? point;
  final LatLng targetLocation;
  final UsersView users;
  final int myId;

  const EditPoint(
      {Key? key,
      this.point,
      required this.targetLocation,
      required this.users,
      required this.myId})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _EditPointState();
}

class _EditPointState extends State<EditPoint> {
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
    location = widget.point?.coords ?? widget.targetLocation;
    category = widget.point?.category ?? PointCategory.general;
    ownerId = widget.point?.ownerId ?? widget.myId;
    nameInputController.text = widget.point?.name ?? '';
    descriptionInputController.text = widget.point?.description ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (nameInputController.text.isNotEmpty) {
      nameInputError = null;
    } else {
      nameInputError = I18N.of(context).errorNameRequired;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.point == null
            ? I18N.of(context).newPoint
            : I18N.of(context).editPoint),
        primary: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: I18N.of(context).dialogPair,
            onPressed: _isValid() ? _save : null,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          verticalDirection: VerticalDirection.down,
          children: [
            Text('Lat: ${location.latitude}'),
            Text('Lng: ${location.longitude}'),
            if (widget.point != null)
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
                        }).toList(growable: false))),
              ],
            ),
            TextField(
              controller: nameInputController,
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
          ],
        ),
      ),
    );
  }

  bool _isValid() {
    return nameInputController.text.isNotEmpty;
  }

  void _save() {
    Point point;
    if (widget.point == null) {
      point = Point.origSame(
          0,
          ownerId,
          nameInputController.text,
          descriptionInputController.text.isEmpty
              ? null
              : descriptionInputController.text,
          location,
          category,
          false);
    } else if (widget.point!.isLocal) {
      point = Point.origSame(
          widget.point!.id,
          ownerId,
          nameInputController.text,
          descriptionInputController.text.isEmpty
              ? null
              : descriptionInputController.text,
          location,
          category,
          widget.point!.deleted);
    } else {
      point = Point(
          widget.point!.id,
          ownerId,
          widget.point!.origOwnerId,
          nameInputController.text,
          widget.point!.origName,
          descriptionInputController.text.isEmpty
              ? null
              : descriptionInputController.text,
          widget.point!.origDescription,
          location,
          widget.point!.origCoords,
          category,
          widget.point!.origCategory,
          widget.point!.deleted);
    }
    Navigator.of(context).pop(point);
  }

  @override
  void dispose() {
    nameInputController.dispose();
    descriptionInputController.dispose();
    super.dispose();
  }
}
