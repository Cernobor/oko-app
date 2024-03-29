import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:oko/data.dart';
import 'package:oko/i18n.dart';
import 'package:oko/utils.dart';
import 'package:oko/constants.dart' as constants;

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
  late Set<PointAttribute> attributes;
  final TextEditingController nameInputController = TextEditingController();
  final TextEditingController descriptionInputController =
      TextEditingController();
  late Color color;
  late bool hasDeadline;
  DateTime? deadline;

  String? nameInputError;

  @override
  void initState() {
    super.initState();
    location = widget.point?.coords ?? widget.targetLocation;
    category = widget.point?.category ?? PointCategory.general;
    ownerId = widget.point?.ownerId ?? widget.myId;
    nameInputController.text = widget.point?.name ?? '';
    descriptionInputController.text = widget.point?.description ?? '';
    attributes = Set.of(widget.point?.attributes ?? {});
    color = widget.point?.color ?? constants.palette[constants.defaultPointColorIndex];
    hasDeadline = widget.point?.deadline != null;
    deadline = widget.point?.deadline;
  }

  @override
  Widget build(BuildContext context) {
    if (nameInputController.text.isNotEmpty) {
      nameInputError = null;
    } else {
      nameInputError = I18N.of(context).errorNameRequired;
    }
    return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.point == null
                ? I18N.of(context).newPoint
                : I18N.of(context).editPoint),
            primary: true,
            leading: BackButton(
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                tooltip: I18N.of(context).dialogSave,
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
                TextField(
                  controller: descriptionInputController,
                  keyboardAppearance: Theme.of(context).brightness,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
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
                        child: Text(I18N.of(context).categoryTitle)),
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
                                    padding:
                                        const EdgeInsets.fromLTRB(15, 0, 0, 0),
                                    child: Text(I18N.of(context).category(cat)),
                                  )
                                ]),
                              );
                            }).toList(growable: false)))
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(I18N.of(context).attributes),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: PointAttribute.attributes
                          .map((attr) => IconButton(
                                icon: Icon(
                                  attr.iconData,
                                  color: attributes.contains(attr)
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onBackground
                                      : Theme.of(context)
                                          .colorScheme
                                          .onBackground
                                          .withOpacity(0.25),
                                ),
                                tooltip: I18N.of(context).attribute(attr),
                                onPressed: () {
                                  setState(() {
                                    if (attributes.contains(attr)) {
                                      attributes.remove(attr);
                                    } else {
                                      attributes.add(attr);
                                    }
                                  });
                                },
                              ))
                          .toList(growable: false),
                    )
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(I18N.of(context).color),
                    IconButton(
                      icon: const Icon(Icons.circle),
                      iconSize: 30,
                      color: color,
                      onPressed: onChooseColor,
                    )
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 0),
                        child: Row(children: [
                          Text(I18N.of(context).deadline),
                          Checkbox(
                              value: hasDeadline,
                              onChanged: (value) => setState(() {
                                    hasDeadline = value ?? false;
                                  }))
                        ])),
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
              ],
            ),
          ),
        ));
  }

  void onChooseColor() async {
    Color? c = await chooseColorBlock(context,
        availableColors: constants.palette, initialColor: color);
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

  bool _isValid() {
    return nameInputController.text.isNotEmpty &&
        (!hasDeadline || deadline != null);
  }

  void _save() {
    Point point;
    if (widget.point == null) {
      point = Point.origSame(
          0,
          ownerId,
          nameInputController.text,
          hasDeadline ? deadline : null,
          descriptionInputController.text.isEmpty
              ? null
              : descriptionInputController.text,
          color,
          Set.identity(),
          location,
          category,
          attributes,
          false);
    } else if (widget.point!.isLocal) {
      point = Point.origSame(
          widget.point!.id,
          ownerId,
          nameInputController.text,
          hasDeadline ? deadline : null,
          descriptionInputController.text.isEmpty
              ? null
              : descriptionInputController.text,
          color,
          widget.point!.photoIDs,
          location,
          category,
          attributes,
          widget.point!.deleted);
    } else {
      point = Point(
          widget.point!.id,
          ownerId,
          widget.point!.origOwnerId,
          nameInputController.text,
          widget.point!.origName,
          hasDeadline ? deadline : null,
          widget.point!.origDeadline,
          descriptionInputController.text.isEmpty
              ? null
              : descriptionInputController.text,
          widget.point!.origDescription,
          color,
          widget.point!.origColor,
          widget.point!.photoIDs,
          widget.point!.origPhotoIDs,
          location,
          widget.point!.origCoords,
          category,
          widget.point!.origCategory,
          attributes,
          widget.point!.origAttributes,
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
