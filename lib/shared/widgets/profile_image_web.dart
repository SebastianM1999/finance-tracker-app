import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final _registered = <String>{};

Widget buildProfileImage(String photoUrl, double size) {
  final viewType = 'profile-img-${photoUrl.hashCode}';

  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      return web.HTMLImageElement()
        ..src = photoUrl
        ..referrerPolicy = 'no-referrer'
        ..style.width = '${size}px'
        ..style.height = '${size}px'
        ..style.objectFit = 'cover'
        ..style.borderRadius = '50%';
    });
  }

  return SizedBox(
    width: size,
    height: size,
    child: HtmlElementView(viewType: viewType),
  );
}
