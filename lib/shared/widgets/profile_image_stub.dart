import 'package:flutter/material.dart';

Widget buildProfileImage(String photoUrl, double size) {
  return Image.network(
    photoUrl,
    width: size,
    height: size,
    fit: BoxFit.cover,
  );
}
