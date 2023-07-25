import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:latlong2/latlong.dart';
import 'package:oko/i18n.dart';

const Distance _distance = Distance();

class NavigationData {
  double distanceM;
  double bearingDeg;
  double? relativeBearingDeg;

  NavigationData._(this.distanceM, this.bearingDeg, this.relativeBearingDeg);

  factory NavigationData.compute(LatLng loc, LatLng tgt, double? headingRad) {
    double dM = _distance.as(LengthUnit.Meter, loc, tgt);
    double bDeg = _distance.bearing(loc, tgt);
    if (bDeg < 0) {
      bDeg += 360;
    }
    if (headingRad == null) {
      return NavigationData._(dM, bDeg, null);
    }
    double hDeg = headingRad * 180 / pi;
    if (hDeg < 0) {
      hDeg += 360;
    }
    double rbDeg = bDeg - hDeg;
    if (rbDeg < -180) {
      rbDeg += 360;
    } else if (rbDeg > 180) {
      rbDeg -= 360;
    }
    return NavigationData._(dM, bDeg, rbDeg);
  }
}

String formatCoords(LatLng coords, bool onLines) {
  if (onLines) {
    return 'Lat: ${coords.latitude.toStringAsFixed(6)}\nLng: ${coords.longitude.toStringAsFixed(6)}';
  } else {
    return 'Lat: ${coords.latitude.toStringAsFixed(6)} Lng: ${coords.longitude.toStringAsFixed(6)}';
  }
}

enum NotificationType { snackbar, dialog }

enum NotificationLevel { error, info, success }

void notifySnackbar(BuildContext context, String msg, NotificationLevel level,
    {int seconds = 5, bool vibrate = true}) {
  _notify(
      context: context,
      message: msg,
      type: NotificationType.snackbar,
      level: level,
      vibrate: vibrate,
      duration: seconds);
}

Future<void> notifyDialog(BuildContext context, String title, String? content,
    NotificationLevel level,
    {bool vibrate = true}) async {
  return _notify(
      context: context,
      message: title,
      type: NotificationType.dialog,
      detail: content,
      level: level,
      vibrate: true);
}

FutureOr<void> _notify(
    {required String message,
    required NotificationType type,
    required BuildContext context,
    String? detail,
    required NotificationLevel level,
    bool vibrate = true,
    int duration = 5}) async {
  FeedbackType vf;
  final Color? sbbg, sbfg, dbg, dfg, dbfg;
  switch (level) {
    case NotificationLevel.error:
      vf = FeedbackType.error;
      sbbg = Theme.of(context).colorScheme.error;
      sbfg = Theme.of(context).colorScheme.onError;
      dbg = Theme.of(context).colorScheme.error;
      dfg = Theme.of(context).colorScheme.onError;
      dbfg = Theme.of(context).colorScheme.onError;
      break;
    case NotificationLevel.info:
      vf = FeedbackType.medium;
      sbbg = Theme.of(context).colorScheme.secondary;
      sbfg = Theme.of(context).colorScheme.onSecondary;
      dbg = null;
      dfg = null;
      dbfg = Theme.of(context).colorScheme.onSecondary;
      break;
    case NotificationLevel.success:
      vf = FeedbackType.success;
      sbbg = Theme.of(context).colorScheme.primaryContainer;
      sbfg = Theme.of(context).colorScheme.onPrimaryContainer;
      dbg = null;
      dfg = null;
      dbfg = Theme.of(context).colorScheme.onPrimary;
      break;
  }
  if (vibrate) {
    Vibrate.feedback(vf);
  }
  if (type == NotificationType.snackbar) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: TextStyle(color: sbfg)),
      backgroundColor: sbbg,
      duration: Duration(seconds: duration),
    ));
  } else if (type == NotificationType.dialog) {
    return showDialog(
        context: context,
        builder: (context) => AlertDialog(
                backgroundColor: dbg,
                title: Text(message, style: TextStyle(color: dfg)),
                content: detail == null
                    ? null
                    : SingleChildScrollView(
                        child: Text(detail, style: TextStyle(color: dfg))),
                actions: [
                  TextButton(
                      style: ButtonStyle(
                        foregroundColor: MaterialStateProperty.all(dbfg),
                        //backgroundColor: MaterialStateProperty.all(dbbg)
                      ),
                      child: Text(I18N.of(context).dismiss),
                      onPressed: () => Navigator.of(context).pop())
                ]));
  }
}

enum Sort { name, owner }

extension SortExt on Sort {
  String name() {
    return toString().split('.').last;
  }

  static Sort parse(String s) {
    switch (s) {
      case 'name':
        return Sort.name;
      case 'owner':
        return Sort.owner;
      default:
        throw IllegalStateException('unknown sort');
    }
  }
}

class _BaseException implements Exception {
  final String? msg;

  _BaseException([this.msg]);

  @override
  String toString() => msg ?? runtimeType.toString();
}

class IllegalStateException extends _BaseException {
  IllegalStateException(String msg) : super(msg);
}

Future<void> unzip(
    File src, Directory dest, void Function(double progress) onProgress) async {
  return ZipFile.extractToDirectory(
      zipFile: src,
      destinationDir: dest,
      onExtracting: (zipEntry, progress) {
        onProgress(progress);
        return ZipFileOperation.includeItem;
      });
}

Future<DateTime?> chooseTime(BuildContext context, {DateTime? initialTime}) async {
  DateTime? date;
  TimeOfDay? time;
  while (true) {
    date = await showDatePicker(
      context: context,
      initialDate: date ?? initialTime?.toLocal() ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      confirmText: I18N.of(context).dialogNext.toUpperCase(),
    );
    if (date == null) {
      return null;
    }
    if (context.mounted) {
      time = await showTimePicker(
        context: context,
        initialTime: time ??
            (initialTime == null
                ? TimeOfDay.fromDateTime(date)
                : TimeOfDay.fromDateTime(initialTime.toLocal())),
        cancelText: I18N.of(context).dialogBack.toUpperCase(),
      );
    } else {
      return null;
    }
    if (time == null) {
      continue;
    }
    break;
  }
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

Future<Color?> chooseColorBlock(BuildContext context, {required List<Color> availableColors, required Color initialColor}) async {
  Color color = initialColor;
  bool? ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: BlockPicker(
              availableColors: availableColors,
              pickerColor: initialColor,
              onColorChanged: (c) {
                color = c;
              },
              itemBuilder: (Color color,
                  bool isCurrentColor,
                  void Function() changeColor) {
                return Container(
                  margin: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: changeColor,
                      borderRadius:
                      BorderRadius.circular(50),
                      child: AnimatedOpacity(
                        duration: const Duration(
                            milliseconds: 210),
                        opacity: isCurrentColor ? 1 : 0,
                        child: Icon(Icons.done,
                            color: useWhiteForeground(color)
                                ? Colors.white
                                : Colors.black),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
                child: Text(I18N.of(context).ok),
                onPressed: () =>
                    Navigator.of(context).pop(true)),
            TextButton(
                child: Text(I18N.of(context).dialogCancel),
                onPressed: () =>
                    Navigator.of(context).pop(false))
          ],
        );
      });
  if (ok == true) {
    return color;
  }
  return null;
}