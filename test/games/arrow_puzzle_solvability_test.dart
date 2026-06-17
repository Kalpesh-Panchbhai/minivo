import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

enum _ArrowDir { up, down, left, right }

extension _ArrowDirX on _ArrowDir {
  Offset get vec => [const Offset(0, -1), const Offset(0, 1), const Offset(-1, 0), const Offset(1, 0)][index];
}

class _Arrow {
  final int id;
  final List<Offset> segments;
  final _ArrowDir headDir;
  _Arrow({required this.id, required this.segments, required this.headDir});

  Offset get head => segments.last;

  Set<int> get occupiedCells {
    final s = <int>{};
    for (final seg in segments) {
      s.add(seg.dx.round() * 10000 + seg.dy.round());
    }
    return s;
  }

  bool isBlockedBy(_Arrow other) {
    final dir = headDir.vec;
    final h = head;
    final otherCells = other.occupiedCells;
    for (int step = 1; step <= 20; step++) {
      final checkPt = Offset(h.dx + dir.dx * step, h.dy + dir.dy * step);
      final key = checkPt.dx.round() * 10000 + checkPt.dy.round();
      if (otherCells.contains(key)) return true;
    }
    return false;
  }

  bool canBeFree(List<_Arrow> allArrows) {
    for (final other in allArrows) {
      if (other.id == id) continue;
      if (isBlockedBy(other)) return false;
    }
    return true;
  }
}

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  int arrowCount(int level) {
    final base = [10, 14, 20][index];
    final perLevel = [2, 3, 4][index];
    final cap = [40, 50, 60][index];
    return base + ((level - 1) * perLevel).clamp(0, cap);
  }
  int get minArrowLen => [4, 3, 2][index];
  int get maxArrowLen => [7, 5, 4][index];
}

int _cellKey(int c, int r) => c * 10000 + r;

Set<int> _generateIrregularShape(math.Random rng, int gridCols, int gridRows, int nArrows, int minLen, int maxLen) {
  final avgLen = (minLen + maxLen) / 2;
  final totalCells = (nArrows * avgLen * 1.15).ceil();
  final centerC = gridCols ~/ 2;
  final centerR = gridRows ~/ 2;

  final cells = <int>{};
  final queue = <int>[_cellKey(centerC, centerR)];
  cells.add(queue.first);

  while (cells.length < totalCells && queue.isNotEmpty) {
    final idx = rng.nextInt(queue.length);
    final k = queue[idx];
    final c = k ~/ 10000;
    final r = k % 10000;
    final dirs = [
      [0, 1], [0, -1], [1, 0], [-1, 0],
    ]..shuffle(rng);
    bool added = false;
    for (final d in dirs) {
      final nc = c + d[0];
      final nr = r + d[1];
      if (nc < 0 || nc >= gridCols || nr < 0 || nr >= gridRows) continue;
      final nk = _cellKey(nc, nr);
      if (cells.contains(nk)) continue;
      cells.add(nk);
      queue.add(nk);
      added = true;
      break;
    }
    if (!added) queue.removeAt(idx);
  }
  return cells;
}

List<_Arrow> _fillBoardWithArrows(math.Random rng, Set<int> boardCells, _Difficulty diff) {
  final occupied = <int>{};
  final arrows = <_Arrow>[];
  int nextId = 0;
  final uncovered = Set<int>.from(boardCells);

  bool wouldLoop(List<Offset> path, Offset next) {
    for (int i = 0; i < path.length - 1; i++) {
      final dx = (next.dx - path[i].dx).abs();
      final dy = (next.dy - path[i].dy).abs();
      if ((dx + dy) <= 1) return true;
    }
    return false;
  }

  int attempts = 0;
  while (uncovered.isNotEmpty && attempts < 5000) {
    attempts++;
    final startKey = uncovered.elementAt(rng.nextInt(uncovered.length));
    final sc = startKey ~/ 10000;
    final sr = startKey % 10000;
    if (occupied.contains(startKey)) {
      uncovered.remove(startKey);
      continue;
    }

    final targetLen = diff.minArrowLen + rng.nextInt(diff.maxArrowLen - diff.minArrowLen + 1);
    final segments = <Offset>[Offset(sc.toDouble(), sr.toDouble())];
    final usedCells = <int>{startKey};

    for (int step = 1; step < targetLen; step++) {
      final cur = segments.last;
      final dirs = [
        const Offset(0, 1), const Offset(0, -1),
        const Offset(1, 0), const Offset(-1, 0),
      ]..shuffle(rng);
      bool found = false;
      for (final d in dirs) {
        final nx = cur.dx + d.dx;
        final ny = cur.dy + d.dy;
        final nk = _cellKey(nx.round(), ny.round());
        if (!boardCells.contains(nk)) continue;
        if (occupied.contains(nk) || usedCells.contains(nk)) continue;
        final next = Offset(nx, ny);
        if (wouldLoop(segments, next)) continue;
        segments.add(next);
        usedCells.add(nk);
        found = true;
        break;
      }
      if (!found) break;
    }

    if (segments.length < 2) continue;

    occupied.addAll(usedCells);

    final last = segments.last;
    final prev = segments[segments.length - 2];
    final ddx = (last.dx - prev.dx).round();
    final ddy = (last.dy - prev.dy).round();
    _ArrowDir headDir;
    if (ddx == 1) { headDir = _ArrowDir.right; }
    else if (ddx == -1) { headDir = _ArrowDir.left; }
    else if (ddy == 1) { headDir = _ArrowDir.down; }
    else { headDir = _ArrowDir.up; }

    final arrow = _Arrow(id: nextId++, segments: segments, headDir: headDir);
    arrows.add(arrow);
    for (final seg in segments) {
      uncovered.remove(_cellKey(seg.dx.round(), seg.dy.round()));
    }
  }

  return arrows;
}

void _validateNodiagonals(List<_Arrow> arrows) {
  for (int ai = 0; ai < arrows.length; ai++) {
    final a = arrows[ai];
    final clean = <Offset>[a.segments.first];
    for (int i = 1; i < a.segments.length; i++) {
      final prev = clean.last;
      final cur = a.segments[i];
      final dx = (cur.dx - prev.dx).round().abs();
      final dy = (cur.dy - prev.dy).round().abs();
      if ((dx == 1 && dy == 0) || (dx == 0 && dy == 1)) {
        clean.add(cur);
      }
    }
    if (clean.length < 2) {
      arrows.removeAt(ai);
      ai--;
      continue;
    }
    if (clean.length != a.segments.length) {
      final last = clean.last;
      final prev = clean[clean.length - 2];
      final ddx = (last.dx - prev.dx).round();
      final ddy = (last.dy - prev.dy).round();
      _ArrowDir hd;
      if (ddx == 1) { hd = _ArrowDir.right; }
      else if (ddx == -1) { hd = _ArrowDir.left; }
      else if (ddy == 1) { hd = _ArrowDir.down; }
      else { hd = _ArrowDir.up; }
      arrows[ai] = _Arrow(id: a.id, segments: clean, headDir: hd);
    }
  }
}

_ArrowDir _headDirFromSegments(List<Offset> segs) {
  final last = segs.last;
  final prev = segs[segs.length - 2];
  final ddx = (last.dx - prev.dx).round();
  final ddy = (last.dy - prev.dy).round();
  if (ddx == 1) return _ArrowDir.right;
  if (ddx == -1) return _ArrowDir.left;
  if (ddy == 1) return _ArrowDir.down;
  return _ArrowDir.up;
}

void _ensureSolvable(List<_Arrow> arrows, math.Random rng) {
  for (int pass = 0; pass < 200; pass++) {
    final remaining = List<int>.generate(arrows.length, (i) => i);
    bool progress = true;
    while (remaining.isNotEmpty && progress) {
      progress = false;
      for (final idx in List<int>.from(remaining)) {
        bool canFree = true;
        for (final otherIdx in remaining) {
          if (otherIdx == idx) continue;
          if (arrows[idx].isBlockedBy(arrows[otherIdx])) {
            canFree = false;
            break;
          }
        }
        if (canFree) {
          remaining.remove(idx);
          progress = true;
          break;
        }
      }
    }
    if (remaining.isEmpty) break;
    final stuck = remaining[rng.nextInt(remaining.length)];
    final a = arrows[stuck];
    final revSegs = a.segments.reversed.toList();
    arrows[stuck] = _Arrow(id: a.id, segments: revSegs, headDir: _headDirFromSegments(revSegs));
  }
}

bool _isSolvable(List<_Arrow> arrows) {
  final remaining = List<int>.generate(arrows.length, (i) => i);
  bool progress = true;
  while (remaining.isNotEmpty && progress) {
    progress = false;
    for (final idx in List<int>.from(remaining)) {
      bool canFree = true;
      for (final otherIdx in remaining) {
        if (otherIdx == idx) continue;
        if (arrows[idx].isBlockedBy(arrows[otherIdx])) {
          canFree = false;
          break;
        }
      }
      if (canFree) {
        remaining.remove(idx);
        progress = true;
        break;
      }
    }
  }
  return remaining.isEmpty;
}

bool generateAndCheck(int level, _Difficulty diff) {
  for (int attempt = 0; attempt < 20; attempt++) {
    final seed = level * 1337 + diff.index * 42 + attempt * 9973;
    final rng = math.Random(seed);
    final nArrows = diff.arrowCount(level);
    final avgLen = (diff.minArrowLen + diff.maxArrowLen) / 2;
    final gridSide = math.sqrt(nArrows * avgLen).ceil().clamp(6, 24);
    final gridCols = gridSide;
    final gridRows = (gridSide * 1.2).ceil().clamp(6, 28);

    final boardCells = _generateIrregularShape(rng, gridCols, gridRows, nArrows, diff.minArrowLen, diff.maxArrowLen);
    final arrows = _fillBoardWithArrows(rng, boardCells, diff);
    _validateNodiagonals(arrows);
    _ensureSolvable(arrows, rng);
    _validateNodiagonals(arrows);
    if (_isSolvable(arrows)) return true;
  }
  return false;
}

void main() {
  group('Arrow Puzzle solvability', () {
    for (final diff in _Difficulty.values) {
      test('all levels 1-100000 are solvable on ${diff.name}', () {
        final failures = <int>[];
        for (int level = 1; level <= 100000; level++) {
          if (!generateAndCheck(level, diff)) {
            failures.add(level);
          }
        }
        expect(failures, isEmpty, reason: 'Unsolvable ${diff.name} levels: $failures');
      }, timeout: const Timeout(Duration(minutes: 30)));
    }
  });
}
