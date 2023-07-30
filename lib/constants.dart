import 'package:flutter/material.dart';

const IconData polyNode = Icons.adjust;
const IconData polyMidpoint = Icons.filter_tilt_shift;
const IconData pointLocalBadge = Icons.star;
const IconData pointEditedBadge = Icons.edit;
const IconData pointDeletedBadge = Icons.delete;
const IconData pointLocked = Icons.lock;
const IconData closePath = Icons.all_inclusive;
const Color polyEditColor = Colors.red;
final Color polyEditFillColor = Colors.grey.withOpacity(.5);
final List<Color> palette = List.unmodifiable([
  Colors.red.shade500,
  Colors.pink.shade500,
  Colors.purple.shade500,
  Colors.deepPurple.shade500,
  Colors.indigo.shade500,
  Colors.blue.shade500,
  Colors.lightBlue.shade500,
  Colors.cyan.shade500,
  Colors.teal.shade500,
  Colors.green.shade500,
  Colors.lightGreen.shade500,
  Colors.lime.shade500,
  Colors.yellow.shade500,
  Colors.amber.shade500,
  Colors.orange.shade500,
  Colors.deepOrange.shade500,
  Colors.brown.shade500,
  Colors.grey.shade500,
  Colors.blueGrey.shade500,
  Colors.black,
]);
const double polyFillColorOpacity = .5;
const double polySelectedFillColorOpacity = .75;
const int defaultPointColorIndex = 5;
const int defaultPolyStrokeColorIndex = 5;
const int defaultPolyFillColorIndex = 17;