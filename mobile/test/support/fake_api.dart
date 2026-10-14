import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// What a fake route answers.
class FakeResponse {
  final int status;
  final Object? body;
  final Map<String, List<String>> headers;

  /// How long the fake server takes to answer.
  final Duration delay;

  const FakeResponse(this.status, this.body, {this.headers = const {}, this.delay = Duration.zero});

  /// A success envelope `{code: 0, message: success, data}`.
  factory FakeResponse.ok(Object? data, {int status = 200, Duration delay = Duration.zero}) =>
      FakeResponse(status, {'code': 0, 'message': 'success', if (data != null) 'data': data}, delay: delay);

  factory FakeResponse.error(int status, int code, String message, {Map<String, List<String>> headers = const {}}) =>
      FakeResponse(status, {'code': code, 'message': message}, headers: headers);
}

/// A request the fake server received.
class FakeRequest {
  final String method;
  final String path;
  final Map<String, String> params;
  final Map<String, dynamic> query;
  final Object? body;
  final Map<String, dynamic> headers;

  const FakeRequest(this.method, this.path, this.params, this.query, this.body, this.headers);

  Map<String, dynamic> get json => (body as Map?)?.cast<String, dynamic>() ?? const {};
}

class _Route {
  final String method;
  final List<String> segments;
  final FakeResponse Function(FakeRequest) handler;

  _Route(this.method, String pattern, this.handler) : segments = _split(pattern);

  Map<String, String>? match(String method, String path) {
    if (method != this.method) return null;
    final parts = _split(path);
    if (parts.length != segments.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < parts.length; i++) {
      final s = segments[i];
      if (s.startsWith(':')) {
        params[s.substring(1)] = parts[i];
      } else if (s != parts[i]) {
        return null;
      }
    }
    return params;
  }

  static List<String> _split(String p) => p.split('/').where((s) => s.isNotEmpty).toList();
}

/// A Dio transport that answers from registered routes, so repositories and
/// pages run against a fake server without a network.
class FakeApi implements HttpClientAdapter {
  static const basePath = '/api/v1';

  final List<FakeRequest> requests = [];
  final List<_Route> _routes = [];

  /// When set, every request fails like a dropped connection.
  bool offline = false;

  /// Registers [handler] for [method] and [pattern] (e.g. `/novels/:id`);
  /// later registrations win.
  void on(String method, String pattern, FakeResponse Function(FakeRequest r) handler) {
    _routes.insert(0, _Route(method.toUpperCase(), pattern, handler));
  }

  Iterable<FakeRequest> calls(String method, String pathPrefix) =>
      requests.where((r) => r.method == method && r.path.startsWith(pathPrefix));

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (offline) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline (fake)');
    }
    var path = options.uri.path;
    if (path.startsWith(basePath)) path = path.substring(basePath.length);
    final method = options.method.toUpperCase();
    for (final route in _routes) {
      final params = route.match(method, path);
      if (params == null) continue;
      final request = FakeRequest(method, path, params, options.queryParameters, options.data, options.headers);
      requests.add(request);
      final response = route.handler(request);
      if (response.delay > Duration.zero) await Future<void>.delayed(response.delay);
      return ResponseBody.fromString(
        jsonEncode(response.body),
        response.status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          ...response.headers,
        },
      );
    }
    requests.add(FakeRequest(method, path, const {}, options.queryParameters, options.data, options.headers));
    return ResponseBody.fromString(
      jsonEncode({'code': 40401, 'message': 'no fake route for $method $path'}),
      404,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}
