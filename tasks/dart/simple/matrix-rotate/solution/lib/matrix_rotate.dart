/// 90-degree rotations of rectangular matrices.

void _checkRectangular<T>(List<List<T>> matrix) {
  for (final row in matrix) {
    if (row.length != matrix[0].length) {
      throw ArgumentError('matrix must be rectangular');
    }
  }
}

/// Rotates [matrix] a quarter turn clockwise.
List<List<T>> rotateClockwise<T>(List<List<T>> matrix) {
  _checkRectangular(matrix);
  if (matrix.isEmpty) return [];
  final rows = matrix.length;
  final cols = matrix[0].length;
  return List.generate(
      cols, (i) => List.generate(rows, (j) => matrix[rows - 1 - j][i]));
}

/// Rotates [matrix] a quarter turn counter-clockwise.
List<List<T>> rotateCounterClockwise<T>(List<List<T>> matrix) {
  _checkRectangular(matrix);
  if (matrix.isEmpty) return [];
  final rows = matrix.length;
  final cols = matrix[0].length;
  return List.generate(
      cols, (i) => List.generate(rows, (j) => matrix[j][cols - 1 - i]));
}
