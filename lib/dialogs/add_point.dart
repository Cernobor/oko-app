import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:oko/data.dart';
import 'package:oko/i18n.dart';

class _AddPointDialogState extends State<AddPointDialog> {
  final TextEditingController nameInputController = TextEditingController();
  final TextEditingController descriptionInputController =
      TextEditingController();

  PointCategory category = PointCategory.general;

  String? nameInputError;

  _AddPointDialogState();

  @override
  Widget build(BuildContext context) {
    if (nameInputController.text.isNotEmpty) {
      nameInputError = null;
    } else {
      nameInputError = I18N.of(context).errorNameRequired;
    }
    return SimpleDialog(
      children: <Widget>[
        Text('Lat: ${widget.location.latitude}\nLng: ${widget.location.longitude}'),
        TextField(
          controller: nameInputController,
          cursorColor: Theme.of(context).colorScheme.onBackground,
          autofocus: false,
          decoration: InputDecoration(
              labelText: I18N.of(context).nameLabel,
              errorText: nameInputError,
              floatingLabelStyle:
                  TextStyle(color: Theme.of(context).colorScheme.onBackground),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onBackground))),
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
          cursorColor: Theme.of(context).colorScheme.onBackground,
          autofocus: false,
          decoration: InputDecoration(
              labelText: I18N.of(context).descriptionLabel,
              floatingLabelStyle:
                  TextStyle(color: Theme.of(context).colorScheme.onBackground),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onBackground))),
          maxLines: null,
        ),
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(I18N.of(context).category),
            PopupMenuButton<PointCategory>(
              icon: Icon(category.iconData),
              onSelected: (PointCategory v) {
                setState(() {
                  category = v;
                });
              },
              itemBuilder: (context) {
                return PointCategory.defaultCategories.map((PointCategory cat) {
                  return PopupMenuItem<PointCategory>(
                    value: cat,
                    child: ListTile(
                      leading: Icon(cat.iconData),
                      title: Text(I18N.of(context).categories(cat)),
                    ),
                  );
                }).toList(growable: false);
              },
            )
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            ElevatedButton(
              child: Text(I18N.of(context).dialogSave),
              onPressed: _isValid() ? _save : null,
            ),
            ElevatedButton(
              child: Text(I18N.of(context).dialogCancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        ),
      ]
          .map((Widget w) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: w))
          .toList(growable: false),
    );
  }

  bool _isValid() {
    return nameInputController.text.isNotEmpty;
  }

  void _save() {
    Navigator.of(context).pop({
      'name': nameInputController.text,
      'description': descriptionInputController.text,
      'category': category.name
    });
  }

  @override
  void dispose() {
    nameInputController.dispose();
    super.dispose();
  }
}

class AddPointDialog extends StatefulWidget {
  final LatLng location;

  const AddPointDialog({Key? key, required this.location}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _AddPointDialogState();
  }
}
