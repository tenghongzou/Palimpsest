import 'package:dio/dio.dart';

import '../l10n/l10n.dart';

/// Error codes from the API envelope (see shared/api-spec/openapi.yaml).
class ApiErrorCode {
  static const translationUnavailable = 50301;
}

/// The API's `code` of a failed request, if the server answered.
int? apiErrorCode(Object error) {
  if (error is! DioException) return null;
  final data = error.response?.data;
  if (data is Map && data['code'] is int) return data['code'] as int;
  return null;
}

int? httpStatus(Object error) => error is DioException ? error.response?.statusCode : null;

/// True when the request never reached the server (offline, timeout...).
bool isNetworkError(Object error) => error is DioException && error.response == null;

/// A short message in the UI language, suitable for a snackbar.
String describeError(Object error, AppLocalizations l) {
  if (error is! DioException) return l.errorGeneric;
  if (error.response == null) return l.errorNetwork;
  final status = error.response!.statusCode ?? 0;
  final data = error.response!.data;
  final message = data is Map ? data['message'] as String? : null;
  switch (status) {
    case 401:
      return l.errorUnauthorized;
    case 403:
      final code = data is Map ? data['code'] : null;
      return code == 40303 || code == 40301 && message == 'account is banned' ? l.errorBanned : l.errorForbidden;
    case 404:
      return l.errorNotFound;
    case 409:
      return message == null ? l.errorConflict : l.errorConflictDetail(message);
    case 413:
      return l.errorTooLarge;
    case 415:
      return l.errorUnsupportedImage;
    case 429:
      return l.errorRateLimited;
    case 503:
      return l.errorUnavailable;
  }
  if (status >= 500) return l.errorServer;
  // The server's own (English) message says what was wrong with the request.
  return message ?? l.errorRequestFailed(status);
}
