import 'package:flutter/material.dart';
import 'package:oko/data.dart';
import 'package:oko/i18n.dart';

class PolyNavPointChooser extends StatefulWidget {
  final Poly poly;

  const PolyNavPointChooser({Key? key, required this.poly}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _PolyNavPointChooserState();
}

class _PolyNavPointChooserState extends State<PolyNavPointChooser> {
  _PolyNavPointChooserState();

  bool centroid = true;
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      actionsPadding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      actions: [
        Column(
          children: [
            const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Divider(
                  thickness: 0,
                  height: 0,
                )),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: onCancel,
                  child: Text(I18N.of(context).dialogCancel),
                ),
                TextButton(
                  onPressed: onOk,
                  child: Text(I18N.of(context).ok),
                )
              ],
            ),
          ],
        )
      ],
      content: Column(
        children: [
          RadioListTile(
              controlAffinity: ListTileControlAffinity.leading,
              value: true,
              groupValue: centroid,
              title: Text(I18N.of(context).centroid),
              onChanged: (bool? value) => setState(() {
                    centroid = value!;
                  })),
          RadioListTile(
              value: false,
              groupValue: centroid,
              title: DropdownMenu(
                label: Text(I18N.of(context).nodeNo),
                initialSelection: index,
                dropdownMenuEntries: List.generate(
                    widget.poly.coords.length,
                    (index) =>
                        DropdownMenuEntry(value: index, label: '${index + 1}')),
                onSelected: (value) {
                  if (value != null) {
                    setState(() {
                      index = value;
                      centroid = false;
                    });
                  }
                },
              ),
              onChanged: (bool? value) => setState(() {
                    centroid = value!;
                  }))
        ],
      ),
    );
  }

  void onCancel() {
    Navigator.of(context).pop();
  }

  void onOk() {
    Navigator.of(context)
        .pop(centroid ? widget.poly.centroid : widget.poly.coords[index]);
  }
}
