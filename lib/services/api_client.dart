import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error HTTP del backend. La mayoría de las rutas de dominio (404/409/410
/// de sesión, cola, etc.) mandan `ProblemDetail` (RFC 7807) — [problemTitle]
/// y [detail] salen de ahí. El 401 de seguridad en cambio viaja SIN body
/// (`HttpStatusServerEntryPoint`): en ese caso ambos quedan `null` y solo
/// vale [statusCode].
class ApiException implements Exception {
  final int statusCode;
  final String? problemTitle;
  final String? detail;
  final Map<String, dynamic>? extra;

  const ApiException(
    this.statusCode, {
    this.problemTitle,
    this.detail,
    this.extra,
  });

  @override
  String toString() =>
      detail ?? problemTitle ?? 'Error del servidor ($statusCode)';
}

/// Cliente HTTP fino para el backend del MVP: arma la URL sobre [baseUrl],
/// agrega `Authorization: Bearer <token>` cuando hay uno disponible (vía
/// [tokenProvider], no un valor fijo — el token puede cambiar tras un
/// login), y traduce respuestas de error a [ApiException].
///
/// [baseUrl] es mutable a propósito: en Codespaces la URL pública cambia por
/// sesión y en dispositivos físicos nunca es `localhost` — el usuario la
/// configura desde la UI de sesión (ver `SessionProvider.setServerUrl`) sin
/// tener que reconstruir este cliente ni los servicios que lo usan.
class ApiClient {
  String baseUrl;
  final http.Client _http;
  String? Function()? tokenProvider;

  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.tokenProvider,
  }) : _http = httpClient ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedQuery = query?.map((k, v) => MapEntry(k, '$v'));
    return Uri.parse('$cleanBase$path').replace(
      queryParameters: (normalizedQuery == null || normalizedQuery.isEmpty)
          ? null
          : normalizedQuery,
    );
  }

  Map<String, String> _headers({bool jsonBody = false}) {
    final headers = <String, String>{};
    if (jsonBody) headers['Content-Type'] = 'application/json';
    final token = tokenProvider?.call();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final response = await _http.get(_uri(path, query), headers: _headers());
    return _decode(response);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    final response = await _http.post(
      _uri(path, query),
      headers: _headers(jsonBody: true),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path, {Map<String, dynamic>? query}) async {
    final response = await _http.delete(_uri(path, query), headers: _headers());
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    if (response.body.isEmpty) {
      throw ApiException(status);
    }
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        status,
        problemTitle: decoded['title'] as String?,
        detail: decoded['detail'] as String?,
        extra: decoded,
      );
    } on FormatException {
      // Errores de validación @Valid por fuera de ProblemDetail (formato
      // default de Spring), u otro body no-JSON: no hay campos que extraer.
      throw ApiException(status, detail: response.body);
    }
  }

  void close() => _http.close();
}
