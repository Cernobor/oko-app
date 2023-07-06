import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:latlong2/latlong.dart';
import 'package:oko/data.dart';
import 'package:oko/i18n.dart';
import 'package:diacritic/diacritic.dart';

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

class FeatureFilter {
  Set<int> users;
  Set<PointCategory> categories;
  Set<PointAttribute> attributes;
  bool exact;
  EditState editState;
  String searchTerm;

  FeatureFilter(this.users, this.categories, this.attributes, this.exact,
      this.editState, this.searchTerm);

  FeatureFilter.empty() : this({}, {}, {}, false, EditState.anyState, '');

  FeatureFilter.copy(FeatureFilter other) : this(other.users, Set<PointCategory>.of(other.categories), Set<PointAttribute>.of(other.attributes), other.exact, other.editState, other.searchTerm);

  Iterable<Point> filter(Iterable<Point> points) {
    return points.where((point) =>
        users.contains(point.ownerId) &&
        categories.contains(point.category) &&
        ((editState == EditState.newState && point.isLocal) ||
            (editState == EditState.editedState && point.isEdited) ||
            (editState == EditState.pristineState &&
                !point.isEdited &&
                !point.isLocal &&
                !point.deleted) ||
            (editState == EditState.anyState) ||
            (editState == EditState.deletedState && point.deleted) ||
            (editState == EditState.editedDeletedState &&
                point.deleted &&
                point.isEdited)) &&
        (exact
            ? setEquals(point.attributes, attributes)
            : (point.attributes.any((attr) => attributes.contains(attr))) ||
                attributes.isEmpty) &&
        _fulltext(point, searchTerm));
  }

  bool _fulltext(Point point, String needle) {
    String n = removeDiacritics(needle).toLowerCase();
    return removeDiacritics(point.name).toLowerCase().contains(n) ||
        removeDiacritics(point.description ?? '').toLowerCase().contains(n);
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
