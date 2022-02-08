import 'package:flutter/material.dart';
import 'package:oko/i18n.dart';

class _MultiCheckerState<T> extends State<MultiChecker<T>> {
  _MultiCheckerState();

  late List<bool> checked;

  @override
  void initState() {
    super.initState();
    checked = widget.items
        .map((T item) => widget.checkedItems.contains(item))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            MaterialButton(
              color: Theme.of(context).colorScheme.primary,
              textColor: Theme.of(context).colorScheme.onPrimary,
              child: Text(I18N.of(context).allNothing),
              onPressed: () {
                bool val = checked.contains(false);
                  setState(() {
                    checked.setAll(0, List<bool>.filled(checked.length, val));
                  });
              },
            ),
            MaterialButton(
              color: Theme.of(context).colorScheme.primary,
              textColor: Theme.of(context).colorScheme.onPrimary,
              child: Text(I18N.of(context).invert),
              onPressed: () {
                setState(() {
                  checked.setAll(0, checked.map((e) => !e));
                });
              },
            )
          ],
        ),
        const Divider(),
        ListView(
          scrollDirection: Axis.vertical,
          shrinkWrap: true,
          children: widget.items
              .asMap()
              .map((int idx, T item) => MapEntry(
                  idx,
                  CheckboxListTile(
                      value: checked[idx],
                      title: widget.titleBuilder.call(item, checked[idx]),
                      subtitle: widget.subtitleBuilder(item, checked[idx]),
                      secondary: widget.secondaryBuilder(item, checked[idx]),
                      isThreeLine:
                          widget.isThreeLinePredicate(item, checked[idx]),
                      activeColor: Theme.of(context).colorScheme.secondary,
                      onChanged: (bool? val) => onChanged(idx, val))))
              .values
              .toList(growable: false),
        ),
        const Divider(),
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

  void onChanged(int idx, bool? val) {
    if (val == true) {
      setState(() {
        checked[idx] = true;
      });
    } else {
      setState(() {
        checked[idx] = false;
      });
    }
  }

  void onCancel() {
    Navigator.of(context).pop();
  }

  void onOk() {
    Navigator.of(context).pop(widget.items
        .asMap()
        .entries
        .where((MapEntry<int, T> e) => checked[e.key])
        .map((MapEntry<int, T> e) => e.value)
        .toSet());
  }
}

typedef ItemWidgetBuilder<T> = Widget? Function(T item, bool checked);
typedef ItemPredicate<T> = bool Function(T item, bool checked);
Widget? _null<U>(U _, bool __) => null;

class MultiChecker<T> extends StatefulWidget {
  final List<T> items;
  final Set<T> checkedItems;
  final ItemWidgetBuilder<T> titleBuilder;
  final ItemWidgetBuilder<T> subtitleBuilder;
  final ItemWidgetBuilder<T> secondaryBuilder;
  final ItemPredicate<T> isThreeLinePredicate;

  MultiChecker(
      {Key? key,
      required List<T> items,
      required Set<T> checkedItems,
      ItemWidgetBuilder<T>? titleBuilder,
      ItemWidgetBuilder<T>? subtitleBuilder,
      ItemWidgetBuilder<T>? secondaryBuilder,
      ItemPredicate<T>? isThreeLinePredicate})
      : items = List.of(items, growable: false),
        checkedItems = Set.of(checkedItems),
        titleBuilder = titleBuilder ?? _null<T>,
        subtitleBuilder = subtitleBuilder ?? _null<T>,
        secondaryBuilder = secondaryBuilder ?? _null<T>,
        isThreeLinePredicate =
            isThreeLinePredicate ?? ((T _, bool __) => false),
        super(key: key);

  @override
  State<StatefulWidget> createState() => _MultiCheckerState<T>();
}
