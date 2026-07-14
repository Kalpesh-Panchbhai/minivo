import 'dart:math' as math;

import 'frame_rush_seeds.g.dart';

// ---------------------------------------------------------------------------
// Frame Rush — deterministic level engine
//
// A level is an object (car, bird, plane, …) looping along a closed path. A
// glowing silhouette "frame" sits at ONE pose on that path. The player taps to
// freeze the object; a WIN is when, at freeze time, the object's POSITION and
// ANGLE both fall inside the level's tolerance of the frame pose.
//
// Everything is a pure, deterministic function of (level, diffIndex, salt):
//   * the difficulty curves fix loop speed + tolerances from (level, diff),
//   * a seeded RNG rolls the path shape, its params, and the frame position,
//   * the offline generator increments `salt` until the config has EXACTLY ONE
//     alignment window per loop (strictly solvable) whose duration is fair for
//     the difficulty, then bakes that salt into frame_rush_seeds.g.dart.
// The device replays the baked salt — no solver ever runs at runtime.
//
// "Exactly one solution" (zip's rule) maps here to "exactly one contiguous
// alignment window per loop": there is a single moment each loop where the
// object fits the frame, so the aim point is unambiguous.
// ---------------------------------------------------------------------------

/// Object silhouettes the screen can draw. Cycles by level so the theme keeps
/// changing across thousands of levels (car, bird, plane, rocket, fish, bus).
const int frameRushObjectCount = 6;

/// Path shapes the object loops along.
class FrPath {
  static const int ellipse = 0;
  static const int bean = 1;
  static const int figure8 = 2;
  static const int ramp = 3;
}

List<int> _allowedPaths(int diffIndex) {
  switch (diffIndex) {
    case 0:
      return const [FrPath.ellipse, FrPath.bean];
    case 1:
      return const [FrPath.ellipse, FrPath.bean, FrPath.figure8, FrPath.ramp];
    default:
      return const [FrPath.ellipse, FrPath.bean, FrPath.figure8, FrPath.ramp];
  }
}

// ---------------------------------------------------------------------------
// Difficulty curves — smooth ramp with level, capped per difficulty.
// ---------------------------------------------------------------------------

/// 0.0 at level 1 → 1.0 at level `span`, clamped for higher levels.
double _ramp(int level, int span) =>
    ((math.min(level, span) - 1) / (span - 1)).clamp(0.0, 1.0);

/// Seconds for the object to travel one full loop. Faster = harder. Kept a
/// touch slower so the tight capture budget still leaves a hittable window.
double loopSecondsFor(int level, int diffIndex) {
  final p = _ramp(level, const [60, 80, 100][diffIndex]);
  final start = const [5.2, 4.6, 4.0][diffIndex];
  final end = const [4.2, 3.6, 3.0][diffIndex];
  return start + (end - start) * p;
}

/// Capture tolerance: the maximum "worst-edge displacement" allowed between the
/// object's outline and the frame — the object's centre offset PLUS how far its
/// tips swing out from an angle error — in normalized play-field units. A win
/// requires the WHOLE outline to sit within this budget, so position and angle
/// are judged together the way the eye sees the fit. Tightens with level.
double posTolFor(int level, int diffIndex) {
  final p = _ramp(level, const [60, 80, 120][diffIndex]);
  // Tight enough that an accepted capture visibly fills the frame: at perfect
  // position the allowed tilt is only ~12° (Easy) → ~5.5° (Hard, late).
  final start = const [0.135, 0.102, 0.082][diffIndex];
  final end = const [0.105, 0.078, 0.062][diffIndex];
  return start + (end - start) * p;
}

/// Half-length of each object's silhouette in normalized units (mirrors the
/// on-screen render scale: objR/posScale ≈ 0.54·scale, tip ≈ 1.2× that). Used to
/// convert an angle error into how far the object's extremities swing away.
double frameRushTipDistance(int objectType) {
  const scale = <double>[1.0, 1.0, 0.86, 1.0, 0.92, 0.92];
  return 0.64 * scale[objectType % frameRushObjectCount];
}

/// The winning window, in real milliseconds, must land inside this band for
/// the level to be accepted by the offline generator — long enough to be
/// humanly hittable (the floor rises for easier modes so Easy stays forgiving),
/// short enough to be a genuine challenge. Hard's floor equals the absolute
/// hittability floor below.
double frameRushMinWindowMs(int diffIndex) =>
    const [105.0, 72.0, 55.0][diffIndex];
double frameRushMaxWindowMs(int diffIndex) =>
    const [240.0, 190.0, 155.0][diffIndex];

/// Absolute floor asserted for EVERY baked level regardless of difficulty —
/// no level may ever be effectively impossible to capture.
const double kFrameRushHardFloorMs = 52.0;

// ---------------------------------------------------------------------------
// Level model
// ---------------------------------------------------------------------------

class FrameRushLevelResult {
  final int level;
  final int diffIndex;
  final int objectType;
  final int pathType;

  /// Path shape params. The LAST element is the whole-path rotation `phi`
  /// (radians); the leading elements are shape-specific amplitudes.
  final List<double> params;

  final double loopSeconds;

  /// Worst-edge-displacement capture budget (see [posTolFor]).
  final double posTol;

  /// Loop parameter in [0,1) where the frame silhouette sits.
  final double frameS;

  FrameRushLevelResult({
    required this.level,
    required this.diffIndex,
    required this.objectType,
    required this.pathType,
    required this.params,
    required this.loopSeconds,
    required this.posTol,
    required this.frameS,
  });
}

// ---------------------------------------------------------------------------
// Path geometry — pose(s) = (x, y, angle) in normalized space, s in [0,1).
// x,y live in roughly [-1,1]; angle is the direction of travel (tangent).
// ---------------------------------------------------------------------------

(double, double) _rawPoint(int pathType, List<double> p, double s) {
  final th = 2 * math.pi * s;
  switch (pathType) {
    case FrPath.ellipse:
      return (p[0] * math.cos(th), p[1] * math.sin(th));
    case FrPath.bean:
      return (p[0] * math.cos(th), p[1] * math.sin(th) + p[2] * math.sin(2 * th));
    case FrPath.figure8:
      return (p[0] * math.sin(th), p[1] * math.sin(th) * math.cos(th));
    case FrPath.ramp:
      final u = math.sin(th); // -1..1, reciprocating (the "car on a ramp")
      return (p[0] * u, p[1] * (u * u * 2 - 1) * 0.5);
    default:
      return (0, 0);
  }
}

/// Position of the object at loop parameter [s], with the path's rotation
/// applied. Pure + deterministic — identical offline and on device.
(double, double) frameRushPoint(FrameRushLevelResult r, double s) {
  final raw = _rawPoint(r.pathType, r.params, s);
  final phi = r.params.last;
  final c = math.cos(phi), sn = math.sin(phi);
  return (raw.$1 * c - raw.$2 * sn, raw.$1 * sn + raw.$2 * c);
}

/// Direction of travel at [s], via a stable centered finite difference. Near a
/// cusp (e.g. the ramp apex, where the object momentarily stops) it falls back
/// to a forward difference so the angle never snaps to noise.
double frameRushAngle(FrameRushLevelResult r, double s) {
  const ds = 0.004;
  final a = frameRushPoint(r, (s - ds) % 1.0);
  final b = frameRushPoint(r, (s + ds) % 1.0);
  double dx = b.$1 - a.$1, dy = b.$2 - a.$2;
  if (dx * dx + dy * dy < 1e-9) {
    final c = frameRushPoint(r, (s + ds * 5) % 1.0);
    dx = c.$1 - a.$1;
    dy = c.$2 - a.$2;
  }
  return math.atan2(dy, dx);
}

/// Full pose (x, y, angle) at [s].
(double, double, double) frameRushPose(FrameRushLevelResult r, double s) {
  final pt = frameRushPoint(r, s);
  return (pt.$1, pt.$2, frameRushAngle(r, s));
}

/// The frame's fixed pose (the target the player must match).
(double, double, double) frameRushFramePose(FrameRushLevelResult r) =>
    frameRushPose(r, r.frameS);

double _angDiff(double a, double b) {
  var d = (a - b) % (2 * math.pi);
  if (d > math.pi) d -= 2 * math.pi;
  return d.abs();
}

/// True when the object at [s] is aligned with the frame within tolerance —
/// this is the exact win condition the screen uses on a tap.
bool frameRushIsAligned(FrameRushLevelResult r, double s) =>
    frameRushError(r, s) <= 1.0;

/// Normalized capture error at [s]. Measures the object's OUTLINE fit against
/// the frame: the centre offset plus how far the object's tips swing out from
/// its angle error (coupled by the object's length), divided by the capture
/// budget. `<= 1.0` means a capture; slightly above 1.0 is a near miss.
double frameRushError(FrameRushLevelResult r, double s) {
  final f = frameRushFramePose(r);
  final p = frameRushPose(r, s);
  final dx = p.$1 - f.$1, dy = p.$2 - f.$2;
  final posErr = math.sqrt(dx * dx + dy * dy);
  final angErr = _angDiff(p.$3, f.$3);
  final edgeDisp = posErr + frameRushTipDistance(r.objectType) * angErr;
  return edgeDisp / r.posTol;
}

/// 0..1 accuracy of a freeze at [s] (1 = dead-on the frame). Used for the
/// PERFECT / GREAT / GOOD rating and the near-miss feedback.
double frameRushAccuracy(FrameRushLevelResult r, double s) =>
    (1.0 - frameRushError(r, s)).clamp(0.0, 1.0);

// ---------------------------------------------------------------------------
// Build — deterministic from (level, diffIndex, salt).
// ---------------------------------------------------------------------------

int _seed(int level, int diffIndex, int salt) {
  int h = level * 2654435761 + diffIndex * 2246822519 + salt * 3266489917;
  h = ((h >> 16) ^ h) * 0x45d9f3b;
  h = ((h >> 16) ^ h) * 0x45d9f3b;
  h = (h >> 16) ^ h;
  return h.abs();
}

int _objectForLevel(int level, int diffIndex) =>
    (level - 1 + diffIndex * 2) % frameRushObjectCount;

List<double> _paramsFor(int pathType, int diffIndex, math.Random rng) {
  double rand(double lo, double hi) => lo + rng.nextDouble() * (hi - lo);
  final phiMax = const [0.35, 0.70, 1.00][diffIndex];
  final phi = rand(-phiMax, phiMax);
  switch (pathType) {
    case FrPath.ellipse:
      return [rand(0.50, 0.70), rand(0.42, 0.60), phi];
    case FrPath.bean:
      return [rand(0.55, 0.70), rand(0.42, 0.55), rand(0.10, 0.22), phi];
    case FrPath.figure8:
      return [rand(0.60, 0.72), rand(0.40, 0.55), phi];
    case FrPath.ramp:
      return [rand(0.60, 0.72), rand(0.42, 0.55), phi];
    default:
      return [0.6, 0.5, phi];
  }
}

FrameRushLevelResult _build(int level, int diffIndex, int salt) {
  final rng = math.Random(_seed(level, diffIndex, salt));
  final allowed = _allowedPaths(diffIndex);
  final pathType = allowed[rng.nextInt(allowed.length)];
  final params = _paramsFor(pathType, diffIndex, rng);
  final frameS = rng.nextDouble();
  return FrameRushLevelResult(
    level: level,
    diffIndex: diffIndex,
    objectType: _objectForLevel(level, diffIndex),
    pathType: pathType,
    params: params,
    loopSeconds: loopSecondsFor(level, diffIndex),
    posTol: posTolFor(level, diffIndex),
    frameS: frameS,
  );
}

/// Build a level for an explicit salt — used by the offline generator + tests.
FrameRushLevelResult generateFrameRushLevelWithSalt(
        int level, int diffIndex, int salt) =>
    _build(level, diffIndex, salt);

/// Build the on-device level: looks up the offline-verified salt and rebuilds
/// deterministically. No solver runs here. Past 10k the levels wrap (10001 ==
/// level 1) while the displayed counter keeps climbing.
FrameRushLevelResult generateFrameRushLevel(int level, int diffIndex) {
  final eff = (level - 1) % frameRushLevelsPerDifficulty + 1;
  return _build(eff, diffIndex, frameRushSaltFor(eff, diffIndex));
}

// ---------------------------------------------------------------------------
// Solver — counts distinct alignment windows in one loop by fine sampling.
// "Strictly solvable" == exactly one window (a single, unambiguous aim point).
// ---------------------------------------------------------------------------

const int _kSamples = 1440;

List<bool> _winMask(FrameRushLevelResult r) {
  final f = frameRushFramePose(r);
  final tip = frameRushTipDistance(r.objectType);
  final mask = List<bool>.filled(_kSamples, false);
  for (int i = 0; i < _kSamples; i++) {
    final p = frameRushPose(r, i / _kSamples);
    final dx = p.$1 - f.$1, dy = p.$2 - f.$2;
    final edgeDisp =
        math.sqrt(dx * dx + dy * dy) + tip * _angDiff(p.$3, f.$3);
    if (edgeDisp <= r.posTol) mask[i] = true;
  }
  return mask;
}

/// Number of distinct contiguous alignment windows per loop, capped at [cap].
int countFrameRushWindows(FrameRushLevelResult r, {int cap = 2}) {
  final mask = _winMask(r);
  int total = 0;
  for (final b in mask) {
    if (b) total++;
  }
  if (total == 0) return 0;
  if (total == _kSamples) return 1;
  int runs = 0;
  for (int i = 0; i < _kSamples; i++) {
    final prev = mask[(i - 1 + _kSamples) % _kSamples];
    if (mask[i] && !prev) {
      runs++;
      if (runs >= cap) return runs;
    }
  }
  return runs;
}

/// Duration (ms) of the alignment window that contains the frame — i.e. how
/// long the object stays "capturable" each loop.
double frameRushWindowMs(FrameRushLevelResult r) {
  final mask = _winMask(r);
  var fi = (r.frameS * _kSamples).round() % _kSamples;
  if (!mask[fi]) {
    int found = -1;
    for (int d = 1; d < _kSamples; d++) {
      if (mask[(fi + d) % _kSamples]) {
        found = (fi + d) % _kSamples;
        break;
      }
      if (mask[(fi - d + _kSamples) % _kSamples]) {
        found = (fi - d + _kSamples) % _kSamples;
        break;
      }
    }
    if (found < 0) return 0;
    fi = found;
  }
  int len = 1;
  int i = (fi + 1) % _kSamples;
  while (mask[i] && i != fi) {
    len++;
    i = (i + 1) % _kSamples;
  }
  i = (fi - 1 + _kSamples) % _kSamples;
  while (mask[i] && i != fi) {
    len++;
    i = (i - 1 + _kSamples) % _kSamples;
  }
  if (len > _kSamples) len = _kSamples;
  return len / _kSamples * r.loopSeconds * 1000.0;
}

/// A level is acceptable when it has exactly one window and that window's
/// duration is fair for the difficulty. Used by the offline generator.
bool frameRushIsFair(FrameRushLevelResult r) {
  if (countFrameRushWindows(r, cap: 2) != 1) return false;
  final ms = frameRushWindowMs(r);
  return ms >= frameRushMinWindowMs(r.diffIndex) &&
      ms <= frameRushMaxWindowMs(r.diffIndex);
}

/// Canonical signature for cross-level uniqueness.
String frameRushSignature(FrameRushLevelResult r) {
  final ps = r.params.map((v) => (v * 1000).round()).join(',');
  final fs = (r.frameS * 4000).round();
  final ls = (r.loopSeconds * 100).round();
  final pt = (r.posTol * 1000).round();
  return '${r.objectType}|${r.pathType}|$ps|$fs|$ls|$pt';
}
