import 'package:flutter/material.dart';
import 'package:oko/i18n.dart';

typedef ItemWidgetBuilder<T> = Widget? Function(T item, bool checked);
typedef ItemPredicate<T> = bool Function(T item, bool checked);
Widget? _null<U>(U _, bool __) => null;

class SingleChooser<T> extends StatefulWidget {
  final List<T> items;
  final T value;
  final ItemWidgetBuilder<T> titleBuilder;
  final ItemWidgetBuilder<T> subtitleBuilder;
  final ItemWidgetBuilder<T> secondaryBuilder;
  final ItemPredicate<T> isThreeLinePredicate;

  SingleChooser(
      {Key? key,
      required List<T> items,
      T? value,
      ItemWidgetBuilder<T>? titleBuilder,
      ItemWidgetBuilder<T>? subtitleBuilder,
      ItemWidgetBuilder<T>? secondaryBuilder,
      ItemPredicate<T>? isThreeLinePredicate})
      : items = List.of(items, growable: false),
        value = value ?? items[0],
        titleBuilder = titleBuilder ?? _null<T>,
        subtitleBuilder = subtitleBuilder ?? _null<T>,
        secondaryBuilder = secondaryBuilder ?? _null<T>,
        isThreeLinePredicate =
            isThreeLinePredicate ?? ((T _, bool __) => false),
        super(key: key);

  @override
  State<StatefulWidget> createState() => _SingleChooserState<T>();
}

class _SingleChooserState<T> extends State<SingleChooser<T>> {
  _SingleChooserState();

  late T selected;

  @override
  void initState() {
    super.initState();
    selected = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      children: <Widget>[
        ListView(
          scrollDirection: Axis.vertical,
          shrinkWrap: true,
          children: widget.items
              .map((T item) => RadioListTile(
                  controlAffinity: ListTileControlAffinity.trailing,
                  value: item,
                  groupValue: selected,
                  title: widget.titleBuilder.call(item, selected == item),
                  subtitle: widget.subtitleBuilder(item, selected == item),
                  secondary: widget.secondaryBuilder(item, selected == item),
                  isThreeLine:
                      widget.isThreeLinePredicate(item, selected == item),
                  activeColor: Theme.of(context).colorScheme.secondary,
                  onChanged: (T? value) {
                    if (value != null) {
                      setState(() {
                        selected = value;
                      });
                    }
                  }))
              .toList(growable: false),
        ),
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
            MaterialButton(
              color: Theme.of(context).colorScheme.primary,
              textColor: Theme.of(context).colorScheme.onPrimary,
              child: Text(I18N.of(context).dialogCancel),
              onPressed: onCancel,
            ),
            MaterialButton(
              color: Theme.of(context).colorScheme.primary,
              textColor: Theme.of(context).colorScheme.onPrimary,
              child: Text(I18N.of(context).ok),
              onPressed: onOk,
            )
          ],
        ),
      ],
    );
  }

  void onCancel() {
    Navigator.of(context).pop();
  }

  void onOk() {
    Navigator.of(context).pop(selected);
  }
}
