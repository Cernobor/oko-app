import 'package:flutter/material.dart';
import 'package:oko/i18n.dart';

typedef ItemWidgetBuilder<T> = Widget? Function(T item, bool checked);
typedef ItemPredicate<T> = bool Function(T item, bool checked);
Widget? _null<U>(U _, bool __) => null;

class MultiCheckerResult<T> {
  final Set<T> checked;
  final bool switcher;

  MultiCheckerResult._(this.checked, this.switcher);
}

class MultiCheckerSwitcher {
  final String offLabel;
  final String onLabel;
  final bool value;
  
  MultiCheckerSwitcher({required this.offLabel, required this.onLabel, required this.value});
}

class MultiChecker<T> extends StatefulWidget {
  final MultiCheckerSwitcher? switcher;
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
      this.switcher,
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

class _MultiCheckerState<T> extends State<MultiChecker<T>> {
  _MultiCheckerState();

  late bool switcher;
  late List<bool> checked;

  @override
  void initState() {
    super.initState();
    checked = widget.items
        .map((T item) => widget.checkedItems.contains(item))
        .toList(growable: false);
    switcher = widget.switcher?.value ?? false;
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
            TextButton(
              child: Text(I18N.of(context).allNothing),
              onPressed: () {
                bool val = checked.contains(false);
                setState(() {
                  checked.setAll(0, List<bool>.filled(checked.length, val));
                });
              },
            ),
            TextButton(
              child: Text(I18N.of(context).invert),
              onPressed: () {
                setState(() {
                  checked.setAll(0, checked.map((e) => !e));
                });
              },
            )
          ],
        ),
        if (widget.switcher != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(widget.switcher!.offLabel),
              Switch.adaptive(
                  /*
                  thumbColor: MaterialStateProperty.all(Theme.of(context)
                      .switchTheme
                      .thumbColor
                      ?.resolve({})),
                  trackColor: MaterialStateProperty.all(Theme.of(context)
                      .switchTheme
                      .trackColor
                      ?.resolve({})),
                  */
                  value: switcher,
                  onChanged: (value) => setState(() {
                        switcher = value;
                      })),
              Text(widget.switcher!.onLabel),
            ],
          ),
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Divider(
              thickness: 0,
              height: 0,
            )),
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
                      onChanged: (bool? val) => onChanged(idx, val))))
              .values
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
            TextButton(
              child: Text(I18N.of(context).dialogCancel),
              onPressed: onCancel,
            ),
            TextButton(
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
    Navigator.of(context).pop(MultiCheckerResult._(
        widget.items
            .asMap()
            .entries
            .where((MapEntry<int, T> e) => checked[e.key])
            .map((MapEntry<int, T> e) => e.value)
            .toSet(),
        switcher));
  }
}
