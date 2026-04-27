import 'package:flutter/material.dart';

class TestDevice {
  final String name;
  final double width;
  final double height;
  final double pixelRatio;
  final TargetPlatform platform;

  const TestDevice({
    required this.name,
    required this.width,
    required this.height,
    required this.pixelRatio,
    required this.platform,
  });

  Size get size => Size(width, height);

  @override
  String toString() => '$name (${width}x$height)';
}

const allTestDevices = [
  // Android
  TestDevice(name: 'Small Android Phone', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.android),
  TestDevice(name: 'Nexus 5 / Pixel 2', width: 360, height: 640, pixelRatio: 3.0, platform: TargetPlatform.android),
  TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android),
  TestDevice(name: 'Samsung S21 Ultra', width: 384, height: 854, pixelRatio: 3.0, platform: TargetPlatform.android),
  TestDevice(name: 'Pixel Fold (folded)', width: 360, height: 752, pixelRatio: 3.0, platform: TargetPlatform.android),
  TestDevice(name: 'Pixel Fold (open)', width: 841, height: 701, pixelRatio: 2.0, platform: TargetPlatform.android),
  TestDevice(name: 'Nexus 10 Tablet', width: 800, height: 1280, pixelRatio: 2.0, platform: TargetPlatform.android),

  // iOS
  TestDevice(name: 'iPhone SE 1st gen', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.iOS),
  TestDevice(name: 'iPhone SE 3rd gen', width: 375, height: 667, pixelRatio: 2.0, platform: TargetPlatform.iOS),
  TestDevice(name: 'iPhone 13/14', width: 390, height: 844, pixelRatio: 3.0, platform: TargetPlatform.iOS),
  TestDevice(name: 'iPhone 14 Pro Max', width: 430, height: 932, pixelRatio: 3.0, platform: TargetPlatform.iOS),
  TestDevice(name: 'iPhone 16 Pro Max', width: 440, height: 956, pixelRatio: 3.0, platform: TargetPlatform.iOS),
  TestDevice(name: 'iPad Mini', width: 744, height: 1133, pixelRatio: 2.0, platform: TargetPlatform.iOS),
  TestDevice(name: 'iPad Pro 12.9"', width: 1024, height: 1366, pixelRatio: 2.0, platform: TargetPlatform.iOS),
];
