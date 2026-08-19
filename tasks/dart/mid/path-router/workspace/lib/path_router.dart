/// Path routing with parameters and wildcards.

/// A successful route lookup.
class RouteMatch<T> {
  final T handler;
  final Map<String, String> params;

  RouteMatch(this.handler, this.params);
}

/// Registers path patterns and resolves paths against them.
class Router<T> {
  void add(String pattern, T handler) => throw UnimplementedError();

  RouteMatch<T>? match(String path) => throw UnimplementedError();
}
