import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:oko/communication.dart';
import 'package:oko/data.dart';
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

const Color myGlobalPoiColor = Colors.blue;
const Color otherGlobalPoiColor = Colors.green;
final Color myLocalPoiColor = Colors.blue.withAlpha(128);
final Color otherLocalPoiColor = Colors.green.withAlpha(128);
const Color myGlobalEditedPoiColor = Colors.blueGrey;
const Color otherGlobalEditedPoiColor = Colors.teal;
final Color myGlobalDeletedPoiColor = Colors.black.withAlpha(128);
final Color otherGlobalDeletedPoiColor = Colors.black.withAlpha(128);

Color getPoiColor(Point point, int? myId) {
  if (point.isLocal) {
    if (point.ownerId == myId) {
      return myLocalPoiColor;
    } else {
      return otherLocalPoiColor;
    }
  } else {
    if (point.ownerId == myId) {
      if (point.deleted) {
        return myGlobalDeletedPoiColor;
      } else if (point.isEdited()) {
        return myGlobalEditedPoiColor;
      } else {
        return myGlobalPoiColor;
      }
    } else {
      if (point.deleted) {
        return otherGlobalDeletedPoiColor;
      } else if (point.isEdited()) {
        return otherGlobalEditedPoiColor;
      } else {
        return otherGlobalPoiColor;
      }
    }
  }
}

Future<void> commErrorDialog(Exception e, BuildContext context) async {
  String errorText;
  String subText;
  if (e is CommException) {
    errorText = e.error;
    subText = '\n${e.uri}\n${e.errorDetail}';
  } else {
    errorText = 'Unknown error';
    subText = e.toString();
  }
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(I18N
            .of(context)
            .alertErrorTitle),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(errorText),
            Text(subText, style: const TextStyle(fontFamily: 'monospace', fontSize: 10),),
          ],
        ),
        actions: <Widget>[
          MaterialButton(
            child: Text(I18N.of(context).ok),
            color: Theme.of(context).colorScheme.secondary,
            textTheme: Theme.of(context).buttonTheme.textTheme,
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      );
    }
  );
}

enum Sort {
  name,
  owner
}

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
  final String ?msg;

  _BaseException([this.msg]);

  @override
  String toString() => msg ?? runtimeType.toString();
}

class InvalidRangeException extends _BaseException {
  InvalidRangeException(String msg) : super(msg);
}

class IllegalStateException extends _BaseException {
  IllegalStateException(String msg) : super(msg);
}