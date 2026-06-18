import 'dart:math' as math;

import 'arrow_puzzle_seeds.g.dart';
import 'arrow_puzzle_shapes.dart';

class Pt {
  final double dx, dy;
  const Pt(this.dx, this.dy);
}

enum ArrowDir { up, down, left, right }

extension ArrowDirExt on ArrowDir {
  Pt get vec =>
      [const Pt(0, -1), const Pt(0, 1), const Pt(-1, 0), const Pt(1, 0)][
          index];
}

class ArrowData {
  final int id;
  final List<Pt> segments;
  final ArrowDir headDir;
  ArrowData({required this.id, required this.segments, required this.headDir});

  late final Pt head = segments.last;

  late final Set<int> cachedCells = () {
    final s = <int>{};
    for (final seg in segments) {
      s.add(seg.dx.round() * 10000 + seg.dy.round());
    }
    return s;
  }();

  bool isBlockedBy(ArrowData other) {
    final dir = headDir.vec;
    final h = head;
    final oc = other.cachedCells;
    for (int step = 1; step <= 20; step++) {
      final key = (h.dx + dir.dx * step).round() * 10000 +
          (h.dy + dir.dy * step).round();
      if (oc.contains(key)) return true;
    }
    return false;
  }
}

class ArrowLevelResult {
  final List<ArrowData> arrows;
  final Set<int> boardCells;
  final int gridCols;
  final int gridRows;
  final bool solvable;
  ArrowLevelResult({
    required this.arrows,
    required this.boardCells,
    required this.gridCols,
    required this.gridRows,
    required this.solvable,
  });
}

// ---------------------------------------------------------------------------
// Difficulty design
//
// Directional-unblock puzzle: an arrow flies off the board in its head
// direction unless another arrow sits in its path. "Solvable" = some removal
// order frees every arrow (multiple orders are fine — uniqueness NOT required).
// Knobs: board size (grows with level), removal DEPTH (chaining = the skill
// lever), and shape (visual variety only; fancy shapes gated to hard).
//
// Boards are sized so the largest tier fits the smallest supported device
// (320x568) at >= 24px cells — no zoom/pan needed anywhere.
// ---------------------------------------------------------------------------

class ArrowDiffSpec {
  final int colsMin, colsMax;
  final int rowsMin, rowsMax;
  final int lenMin, lenMax;
  final int depthMin, depthMax;
  final int stepLevels; // levels per +1 board growth
  const ArrowDiffSpec({
    required this.colsMin,
    required this.colsMax,
    required this.rowsMin,
    required this.rowsMax,
    required this.lenMin,
    required this.lenMax,
    required this.depthMin,
    required this.depthMax,
    required this.stepLevels,
  });
}

const List<ArrowDiffSpec> arrowSpecs = [
  // EASY — small boards, shallow chains, simple shapes.
  ArrowDiffSpec(
    colsMin: 6, colsMax: 8, rowsMin: 7, rowsMax: 9,
    lenMin: 2, lenMax: 6, depthMin: 1, depthMax: 4, stepLevels: 4,
  ),
  // MEDIUM — bigger boards, moderate chains.
  ArrowDiffSpec(
    colsMin: 8, colsMax: 10, rowsMin: 9, rowsMax: 12,
    lenMin: 2, lenMax: 8, depthMin: 3, depthMax: 8, stepLevels: 3,
  ),
  // HARD — largest boards (fit 320px at 24px), deep chains, fancy shapes.
  ArrowDiffSpec(
    colsMin: 9, colsMax: 12, rowsMin: 11, rowsMax: 13,
    lenMin: 2, lenMax: 11, depthMin: 5, depthMax: 999, stepLevels: 2,
  ),
];

ArrowDiffSpec arrowSpec(int diffIndex) => arrowSpecs[diffIndex];

/// Board bounding box for a level — grows from min to cap with level (wraps in
/// lockstep with [generateArrowLevel] so level 10001 == level 1).
(int, int) targetBox(int diffIndex, int level) {
  final s = arrowSpec(diffIndex);
  final eff = (level - 1) % arrowLevelsPerDifficulty + 1;
  final g = (eff - 1) ~/ s.stepLevels;
  return (math.min(s.colsMin + g, s.colsMax), math.min(s.rowsMin + g, s.rowsMax));
}

/// Deterministic, evenly-distributed shape for a level (same on all devices).
/// Picks from the tier-eligible pool so fancy shapes only appear on hard.
ArrowShape shapeForLevel(int diffIndex, int level) {
  final eff = (level - 1) % arrowLevelsPerDifficulty + 1;
  final pool = shapesForTier(diffIndex);
  int h = eff * 2654435761 + diffIndex * 40503 + 17;
  h = (h ^ (h >> 13)) & 0x7fffffff;
  return pool[h % pool.length];
}

// ---------------------------------------------------------------------------
// Board tiling — a leaf-first greedy path cover. Always starts a new arrow at
// the lowest-degree uncovered cell (a corner/extremity) and extends greedily,
// which avoids stranding cells, so any connected shape packs ~100% solid with no
// backtracking (fast + deterministic). Strays are merged; the rare unmergeable
// stray is caught by the coverage check and that salt is skipped offline.
// ---------------------------------------------------------------------------

int cellKey(int c, int r) => c * 10000 + r;

const _kCardinals = [
  [0, -1],
  [0, 1],
  [-1, 0],
  [1, 0],
];

ArrowDir _headDirFromPt(Pt last, Pt prev) {
  final ddx = (last.dx - prev.dx).round();
  final ddy = (last.dy - prev.dy).round();
  if (ddx == 1) return ArrowDir.right;
  if (ddx == -1) return ArrowDir.left;
  if (ddy == 1) return ArrowDir.down;
  return ArrowDir.up;
}

/// True if the head's exit ray (head, then onward in the head direction) passes
/// through any of the arrow's OWN cells — a curled arrow pointing back into
/// itself, which reads as self-blocked. Such orientations are avoided.
bool _segHeadHitsBody(List<int> seg) {
  final n = seg.length;
  final hc = seg[n - 1] ~/ 10000, hr = seg[n - 1] % 10000;
  final pc = seg[n - 2] ~/ 10000, pr = seg[n - 2] % 10000;
  final ddx = hc - pc, ddy = hr - pr;
  final own = seg.toSet();
  for (int step = 1; step <= 20; step++) {
    if (own.contains((hc + ddx * step) * 10000 + (hr + ddy * step))) return true;
  }
  return false;
}

bool arrowSelfBlocks(ArrowData a) =>
    _segHeadHitsBody([for (final p in a.segments) p.dx.round() * 10000 + p.dy.round()]);

List<ArrowData> _barCover(
    Set<int> cells, int minLen, int maxLen, math.Random rng) {
  final uncovered = Set<int>.from(cells);

  int udeg(int k) {
    final c = k ~/ 10000, r = k % 10000;
    int d = 0;
    for (final dd in _kCardinals) {
      if (uncovered.contains((c + dd[0]) * 10000 + (r + dd[1]))) d++;
    }
    return d;
  }

  final bars = <List<int>>[];
  while (uncovered.isNotEmpty) {
    final list = uncovered.toList()..shuffle(rng);
    int start = list.first, sd = udeg(start);
    for (final k in list) {
      final d = udeg(k);
      if (d < sd) {
        sd = d;
        start = k;
        if (d == 0) break;
      }
    }
    uncovered.remove(start);
    final target = minLen + rng.nextInt(maxLen - minLen + 1);

    // Grow a STRAIGHT bar through `start` along one axis. Straight bars make the
    // head direction the exact flight path: no bends ⇒ no self-block, and the
    // body never sweeps sideways into other arrows.
    List<int> buildBar(bool horizontal) {
      final sc = start ~/ 10000, sr = start % 10000;
      final bar = <int>[start];
      final dc = horizontal ? 1 : 0, dr = horizontal ? 0 : 1;
      int c = sc, r = sr;
      while (bar.length < target) {
        final nk = (c + dc) * 10000 + (r + dr);
        if (!uncovered.contains(nk)) break;
        bar.add(nk);
        c += dc;
        r += dr;
      }
      c = sc;
      r = sr;
      while (bar.length < target) {
        final nk = (c - dc) * 10000 + (r - dr);
        if (!uncovered.contains(nk)) break;
        bar.insert(0, nk);
        c -= dc;
        r -= dr;
      }
      return bar;
    }

    final horizFirst = rng.nextBool();
    var bar = buildBar(horizFirst);
    if (bar.length == 1) bar = buildBar(!horizFirst); // try the other axis
    for (final k in bar) {
      uncovered.remove(k);
    }
    bars.add(bar);
  }

  // Merge stray single cells onto a COLINEAR adjacent bar end (keeps bars
  // straight). Unmergeable strays leave the level <100% packed → rejected.
  bool merged = true;
  while (merged) {
    merged = false;
    for (int i = 0; i < bars.length; i++) {
      if (bars[i].length != 1) continue;
      final cell = bars[i][0];
      final c = cell ~/ 10000, r = cell % 10000;
      for (int j = 0; j < bars.length; j++) {
        if (j == i || bars[j].length < 2) continue;
        final other = bars[j];
        final horizontal = (other[0] % 10000) == (other[1] % 10000);
        final hc = other.last ~/ 10000, hr = other.last % 10000;
        final tc = other.first ~/ 10000, tr = other.first % 10000;
        if (horizontal && r == hr && c == hc + 1) {
          other.add(cell);
        } else if (horizontal && r == tr && c == tc - 1) {
          other.insert(0, cell);
        } else if (!horizontal && c == hc && r == hr + 1) {
          other.add(cell);
        } else if (!horizontal && c == tc && r == tr - 1) {
          other.insert(0, cell);
        } else {
          continue;
        }
        bars.removeAt(i);
        merged = true;
        break;
      }
      if (merged) break;
    }
  }

  final arrows = <ArrowData>[];
  int id = 0;
  for (var bar in bars) {
    if (bar.length < 2) continue; // unmergeable stray → coverage check rejects
    if (rng.nextBool()) bar = bar.reversed.toList(); // random head end
    final pts = [
      for (final ci in bar)
        Pt((ci ~/ 10000).toDouble(), (ci % 10000).toDouble())
    ];
    arrows.add(ArrowData(
      id: id++,
      segments: pts,
      headDir: _headDirFromPt(pts.last, pts[pts.length - 2]),
    ));
  }
  return arrows;
}

// ---------------------------------------------------------------------------
// Solver / difficulty metric
// ---------------------------------------------------------------------------

/// Greedy parallel elimination via Kahn layering: each layer frees every
/// currently-unblocked arrow at once. Returns the number of layers (the removal
/// DEPTH), or -1 if the level deadlocks (unsolvable). Blocker graph built once
/// (O(n²)) so deep boards stay cheap.
int removalDepth(List<ArrowData> arrows) {
  final n = arrows.length;
  if (n == 0) return 0;
  final indeg = List<int>.filled(n, 0);
  final blocks = List.generate(n, (_) => <int>[], growable: false);
  for (int i = 0; i < n; i++) {
    for (int j = 0; j < n; j++) {
      if (i == j) continue;
      if (arrows[i].isBlockedBy(arrows[j])) {
        indeg[i]++;
        blocks[j].add(i);
      }
    }
  }
  var frontier = <int>[];
  for (int i = 0; i < n; i++) {
    if (indeg[i] == 0) frontier.add(i);
  }
  int removed = 0, layers = 0;
  while (frontier.isNotEmpty) {
    final next = <int>[];
    for (final j in frontier) {
      removed++;
      for (final i in blocks[j]) {
        if (--indeg[i] == 0) next.add(i);
      }
    }
    layers++;
    frontier = next;
  }
  return removed == n ? layers : -1;
}

/// True if every shape cell is covered by exactly one arrow (no gaps inside the
/// shape) — arrows only occupy board cells, so equal counts ⇒ full cover.
bool fullyCovered(ArrowLevelResult r) {
  final covered = <int>{};
  for (final a in r.arrows) {
    covered.addAll(a.cachedCells);
  }
  return covered.length == r.boardCells.length;
}

/// Shippable iff fully packed, solvable, enough arrows, and inside the tier's
/// removal-depth band.
bool meetsArrowBand(ArrowLevelResult r, int diffIndex, int level) {
  final s = arrowSpec(diffIndex);
  if (r.arrows.length < 4) return false;
  if (!fullyCovered(r)) return false;
  for (final a in r.arrows) {
    if (arrowSelfBlocks(a)) return false; // no arrow may point into its own body
  }
  final d = removalDepth(r.arrows);
  if (d < 0) return false;
  return d >= s.depthMin && d <= s.depthMax;
}

String arrowSignature(ArrowLevelResult r) {
  final parts = r.arrows.map((a) {
    final segs =
        a.segments.map((p) => '${p.dx.round()},${p.dy.round()}').join(';');
    return '$segs|${a.headDir.index}';
  }).toList()
    ..sort();
  return '${r.gridCols}x${r.gridRows}:${parts.join('/')}';
}

// ---------------------------------------------------------------------------
// Build (pure deterministic function of level, diffIndex, salt)
// ---------------------------------------------------------------------------

int _seed(int level, int diffIndex, int salt) {
  int h = level * 1337 + diffIndex * 42 + salt * 9973;
  h = ((h >> 16) ^ h) * 0x45d9f3b;
  h = ((h >> 16) ^ h) * 0x45d9f3b;
  h = (h >> 16) ^ h;
  return h.abs();
}

ArrowLevelResult _build(int level, int diffIndex, int salt) {
  final s = arrowSpec(diffIndex);
  final rng = math.Random(_seed(level, diffIndex, salt));
  final (cols, rows) = targetBox(diffIndex, level);
  final shape = shapeForLevel(diffIndex, level);
  final boardCells = shape.cells(cols, rows);
  final arrows = _barCover(boardCells, s.lenMin, s.lenMax, rng);

  return ArrowLevelResult(
    arrows: arrows,
    boardCells: boardCells,
    gridCols: cols,
    gridRows: rows,
    // Offline-verified solvable for this (level, diffIndex, salt); on-device we
    // skip the solver. Verification uses removalDepth() directly.
    solvable: true,
  );
}

/// Build a level for an explicit salt — used by the offline generator and tests.
ArrowLevelResult generateArrowLevelWithSalt(int level, int diffIndex, int salt) =>
    _build(level, diffIndex, salt);

/// Build the on-device level: replays the offline-verified salt (packed,
/// solvable, in band, unique). The 10k puzzles per difficulty repeat forever —
/// level 10001 plays puzzle 1 — while the displayed counter keeps climbing.
ArrowLevelResult generateArrowLevel(int level, int diffIndex) {
  final effLevel = (level - 1) % arrowLevelsPerDifficulty + 1;
  return _build(effLevel, diffIndex, arrowSaltFor(effLevel, diffIndex));
}
