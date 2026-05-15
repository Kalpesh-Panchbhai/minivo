import 'package:flutter/widgets.dart';

/// Responsive layout helpers. Imported wherever screens need to vary by
/// width, height, or system text scale. Use these instead of scattering
/// raw `MediaQuery.of(context).size.width < 600` checks across the
/// codebase — both for consistency and to make widening device coverage
/// (foldables, tablets, large-font users) a single-edit operation.
extension ResponsiveContext on BuildContext {
  // ─── Spacing tokens ───────────────────────────────────────────────────
  // Replaces the scattered 4/8/12/16/24/32/48 EdgeInsets numbers. Keep
  // this small — adding tokens dilutes the value of having tokens.

  double get sp4 => 4;
  double get sp8 => 8;
  double get sp12 => 12;
  double get sp16 => 16;
  double get sp24 => 24;
  double get sp32 => 32;
  double get sp48 => 48;

  // ─── Screen-size predicates ───────────────────────────────────────────

  Size get screenSize => MediaQuery.sizeOf(this);

  /// True when the screen width is narrower than a typical 5" phone.
  /// Use to drop secondary content (subtitles, action labels) on
  /// 320px Android Go / iPhone SE 1st gen / Pixel Fold (folded).
  bool get isCompactWidth => screenSize.width < 360;

  /// True on tablets and large foldables. Use to widen single-column
  /// content (max 600px) or switch grids to 3+ columns.
  bool get isWideScreen => screenSize.width >= 600;

  /// True when vertical space is tight — short phones, landscape (which
  /// we don't officially support, but rotation can briefly happen during
  /// orientation lock transitions). Use to compress vertical padding /
  /// hide non-essential subtitles.
  bool get isCompactHeight => screenSize.height < 700;

  // ─── Responsive typography ────────────────────────────────────────────

  /// Returns a font size that scales with the user's accessibility text
  /// scale, but capped so very large fonts don't overflow your layouts.
  /// [base] is the "natural" size the designer chose at 1.0× scale.
  /// [max] is the absolute ceiling (defaults to base × 1.35).
  ///
  /// Example: `fontSize: context.fontSize(20)` — renders at 20pt for
  /// most users, scales up to 27pt for users with large fonts, but never
  /// goes higher. Prevents layout overflow at extreme system text scales.
  double fontSize(double base, {double? max}) {
    final scaler = MediaQuery.textScalerOf(this);
    final scaled = scaler.scale(base);
    final ceiling = max ?? base * 1.35;
    return scaled > ceiling ? ceiling : scaled;
  }
}
