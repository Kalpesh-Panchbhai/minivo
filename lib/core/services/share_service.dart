import 'dart:io' show File, Platform;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_strings.dart';
import '../widgets/share_card.dart';

class ShareService {
  ShareService._();
  static final ShareService _instance = ShareService._();
  factory ShareService() => _instance;

  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.puzzloragames.dropzy';
  static const _appStoreUrl =
      'https://apps.apple.com/app/minivo/id0000000000'; // TODO: replace with real App Store ID

  static String get _storeUrl =>
      Platform.isIOS ? _appStoreUrl : _playStoreUrl;

  Future<void> shareApp(BuildContext context) async {
    await _shareImage(
      context: context,
      card: const ShareCard(),
      text: '🕹️ ${AppStrings.appName} — 100+ addictive mini games, all FREE!\n\nPuzzles, arcade, board games & more in one app 🎮\n\n$_storeUrl',
    );
  }

  Future<void> shareScore({
    required BuildContext context,
    required String gameName,
    required int score,
    required int stars,
    String? emoji,
  }) async {
    await _shareImage(
      context: context,
      card: ShareCard(
        gameName: gameName,
        score: score,
        stars: stars,
        emoji: emoji,
      ),
      text: '🎮 I just scored $score in $gameName!\n\nThink you can beat that? 😏\n\nPlay 100+ free mini games on ${AppStrings.appName} 👇\n$_storeUrl',
    );
  }

  Rect _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final pos = box.localToGlobal(Offset.zero);
      return pos & box.size;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }

  Future<void> _shareImage({
    required BuildContext context,
    required ShareCard card,
    required String text,
  }) async {
    final origin = _shareOrigin(context);
    try {
      final imageBytes = await _captureWidget(context, card);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/minivo_share.png');
      await file.writeAsBytes(imageBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: text,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      try {
        await SharePlus.instance.share(
          ShareParams(text: text, sharePositionOrigin: origin),
        );
      } catch (_) {}
    }
  }

  Future<List<int>> _captureWidget(BuildContext context, Widget widget) async {
    final key = GlobalKey();

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        top: -9999,
        child: RepaintBoundary(
          key: key,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Material(
                color: Colors.transparent,
                child: widget,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    await Future.delayed(const Duration(milliseconds: 100));

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    entry.remove();

    return byteData!.buffer.asUint8List();
  }
}
