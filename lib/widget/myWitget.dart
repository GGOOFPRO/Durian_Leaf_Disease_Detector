import 'package:flutter/material.dart';

class MyWidget {
  static normalText(context, text, color, size, fontWeight) {
    return Text(
      text,
      style: TextStyle(fontSize: size, color: color, fontWeight: fontWeight),
    );
  }
}

AppBar appbar(context, text) {
  return AppBar(
    title: Text(
      text,
      style: TextStyle(
        fontSize: 22,
        color: Colors.black,
        fontWeight: FontWeight.w700,
      ),
    ),
    backgroundColor: Colors.white,
  );
}
