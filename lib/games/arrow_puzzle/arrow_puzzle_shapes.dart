import 'dart:math' as math;

/// Board outline shapes for Arrow Puzzle. A shape maps a (cols × rows) bounding
/// box to the set of cells that are "inside" — those cells get packed solid with
/// arrows, the rest is intentional negative space (not gaps).
///
/// Two kinds:
///  * geometric — defined by a math predicate over normalised coords (smooth at
///    any board size),
///  * iconic — defined by a small base bitmap, nearest-neighbour scaled to the
///    box (recognisable but pixel-art at low resolution).
///
/// `minTier` gates a shape to a difficulty floor (0 = easy+, 1 = medium+,
/// 2 = hard only) so the fancy shapes show up on harder, larger boards where
/// they read better.

int shapeCellKey(int c, int r) => c * 10000 + r;

typedef _Predicate = bool Function(double nx, double ny, int c, int r);

class ArrowShape {
  final String name;
  final int minTier;
  final Set<int> Function(int cols, int rows) _build;
  const ArrowShape(this.name, this.minTier, this._build);

  Set<int> cells(int cols, int rows) => _build(cols, rows);
}

Set<int> _fromPredicate(int cols, int rows, _Predicate inside) {
  final s = <int>{};
  for (int r = 0; r < rows; r++) {
    final ny = rows <= 1 ? 0.0 : (r / (rows - 1)) * 2 - 1; // -1..1
    for (int c = 0; c < cols; c++) {
      final nx = cols <= 1 ? 0.0 : (c / (cols - 1)) * 2 - 1; // -1..1
      if (inside(nx, ny, c, r)) s.add(shapeCellKey(c, r));
    }
  }
  return s;
}

/// Nearest-neighbour scale a base bitmap (`#` = inside) to the box.
Set<int> _fromBitmap(int cols, int rows, List<String> bmp) {
  final bh = bmp.length;
  final s = <int>{};
  for (int r = 0; r < rows; r++) {
    final row = bmp[(r * bh) ~/ rows];
    final bw = row.length;
    for (int c = 0; c < cols; c++) {
      if (row[(c * bw) ~/ cols] == '#') s.add(shapeCellKey(c, r));
    }
  }
  return s;
}

// --- bitmaps (iconic) ------------------------------------------------------

const _heart = [
  '..##.....##..',
  '.####...####.',
  '#############',
  '#############',
  '#############',
  '.###########.',
  '..#########..',
  '...#######...',
  '....#####....',
  '.....###.....',
  '......#......',
];

const _star4 = [
  '......#......',
  '.....###.....',
  '.....###.....',
  '#############',
  '.###########.',
  '..#########..',
  '.###########.',
  '#############',
  '.....###.....',
  '.....###.....',
  '......#......',
];

const _star5 = [
  '......#......',
  '......#......',
  '.....###.....',
  '#############',
  '.###########.',
  '..#########..',
  '...#######...',
  '...#######...',
  '..###...###..',
  '.###.....###.',
  '###.......###',
];

const _gem = [
  '.#########.',
  '###########',
  '###########',
  '.#########.',
  '..#######..',
  '...#####...',
  '....###....',
  '.....#.....',
];

const _shield = [
  '###########',
  '###########',
  '###########',
  '###########',
  '.#########.',
  '.#########.',
  '..#######..',
  '..#######..',
  '...#####...',
  '....###....',
  '.....#.....',
];

const _ghost = [
  '...#####...',
  '.#########.',
  '###########',
  '###########',
  '###########',
  '###########',
  '###########',
  '###########',
  '###########',
  '##.##.##.##',
];

const _tree = [
  '.....#.....',
  '....###....',
  '....###....',
  '...#####...',
  '..#######..',
  '..#######..',
  '.#########.',
  '###########',
  '.....#.....',
  '.....#.....',
];

const _crescent = [
  '...####....',
  '.######....',
  '######.....',
  '#####......',
  '#####......',
  '#####......',
  '#####......',
  '######.....',
  '.######....',
  '...####....',
];

// --- shape table -----------------------------------------------------------

const double _eps = 0.06;

final List<ArrowShape> arrowShapes = [
  // tier 0 — simple, filled (good arrow counts)
  ArrowShape('rectangle', 0, (c, r) => _fromPredicate(c, r, (nx, ny, _, __) => true)),
  ArrowShape('circle', 0,
      (c, r) => _fromPredicate(c, r, (nx, ny, _, __) => nx * nx + ny * ny <= 1 + _eps)),
  ArrowShape('diamond', 0,
      (c, r) => _fromPredicate(c, r, (nx, ny, _, __) => nx.abs() + ny.abs() <= 1 + _eps)),
  ArrowShape('octagon', 0, (c, r) => _fromPredicate(c, r,
      (nx, ny, _, __) => math.max(nx.abs(), ny.abs()) <= 1 && nx.abs() + ny.abs() <= 1.5)),
  ArrowShape('hexagon', 0, (c, r) => _fromPredicate(c, r, (nx, ny, _, __) {
        final lim = nx.abs() <= 0.5 ? 1.0 : 2 * (1 - nx.abs());
        return ny.abs() <= lim + _eps;
      })),
  ArrowShape('triangleUp', 0, (c, r) =>
      _fromPredicate(c, r, (nx, ny, _, __) => nx.abs() <= (ny + 1) / 2 + _eps)),
  ArrowShape('plus', 0, (c, r) =>
      _fromPredicate(c, r, (nx, ny, _, __) => nx.abs() <= 0.34 || ny.abs() <= 0.34)),

  // tier 1 — more geometric + simple icons
  ArrowShape('triangleDown', 1, (c, r) =>
      _fromPredicate(c, r, (nx, ny, _, __) => nx.abs() <= (1 - ny) / 2 + _eps)),
  ArrowShape('triangleRight', 1, (c, r) =>
      _fromPredicate(c, r, (nx, ny, _, __) => ny.abs() <= (1 - nx) / 2 + _eps)),
  ArrowShape('triangleLeft', 1, (c, r) =>
      _fromPredicate(c, r, (nx, ny, _, __) => ny.abs() <= (nx + 1) / 2 + _eps)),
  ArrowShape('hourglass', 1,
      (c, r) => _fromPredicate(c, r, (nx, ny, _, __) => nx.abs() <= ny.abs() + _eps)),
  ArrowShape('bowtie', 1,
      (c, r) => _fromPredicate(c, r, (nx, ny, _, __) => ny.abs() <= nx.abs() + _eps)),
  ArrowShape('trapezoid', 1, (c, r) => _fromPredicate(
      c, r, (nx, ny, _, __) => nx.abs() <= 0.6 + 0.4 * (ny + 1) / 2 + _eps)),
  ArrowShape('parallelogram', 1, (c, r) =>
      _fromPredicate(c, r, (nx, ny, _, __) => (nx - 0.4 * ny).abs() <= 0.72)),
  ArrowShape('house', 1, (c, r) => _fromPredicate(c, r, (nx, ny, _, __) {
        if (ny >= -0.2) return nx.abs() <= 1;
        return nx.abs() <= (ny + 1) / 0.8 + _eps;
      })),
  ArrowShape('cross', 1, (c, r) => _fromPredicate(c, r,
      (nx, ny, _, __) => nx.abs() <= 0.28 || (ny + 0.2).abs() <= 0.28)),
  ArrowShape('heart', 1, (c, r) => _fromBitmap(c, r, _heart)),
  ArrowShape('gem', 1, (c, r) => _fromBitmap(c, r, _gem)),
  ArrowShape('shield', 1, (c, r) => _fromBitmap(c, r, _shield)),

  // tier 2 — fancy, hard only (bigger boards hold the detail)
  ArrowShape('star4', 2, (c, r) => _fromBitmap(c, r, _star4)),
  ArrowShape('star5', 2, (c, r) => _fromBitmap(c, r, _star5)),
  ArrowShape('ghost', 2, (c, r) => _fromBitmap(c, r, _ghost)),
  ArrowShape('tree', 2, (c, r) => _fromBitmap(c, r, _tree)),
  ArrowShape('crescent', 2, (c, r) => _fromBitmap(c, r, _crescent)),
];

/// Shapes eligible for a difficulty tier (0=easy,1=medium,2=hard): every shape
/// whose [ArrowShape.minTier] is <= the tier.
List<ArrowShape> shapesForTier(int tier) =>
    arrowShapes.where((s) => s.minTier <= tier).toList(growable: false);
