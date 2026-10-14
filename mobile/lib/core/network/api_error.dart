import 'package:dio/dio.dart';

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

/// A short Traditional Chinese message suitable for a snackbar.
String describeError(Object error) {
  if (error is! DioException) return '發生錯誤，請稍後再試';
  if (error.response == null) return '網路連線失敗，請檢查網路後再試';
  final status = error.response!.statusCode ?? 0;
  final data = error.response!.data;
  final message = data is Map ? data['message'] as String? : null;
  switch (status) {
    case 401:
      return '請先登入';
    case 403:
      return '沒有權限執行此操作';
    case 404:
      return '找不到內容';
    case 409:
      return message == null ? '資料衝突' : '資料衝突：$message';
    case 429:
      return '請求過於頻繁，請稍後再試';
    case 503:
      return '服務暫時無法使用，請稍後再試';
  }
  if (status >= 500) return '伺服器錯誤，請稍後再試';
  return message ?? '請求失敗（$status）';
}
