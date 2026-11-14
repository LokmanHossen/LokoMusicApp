import 'package:dio/dio.dart';

class Failure implements Exception {
  const Failure(this.message, {this.code});
  final String message;
  final int? code;

  factory Failure.from(Object error) {
    if (error is Failure) return error;
    if (error is DioException) {
      final code = error.response?.statusCode;
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const Failure('The request timed out. Check your connection and try again.');
        case DioExceptionType.connectionError:
          return const Failure('No internet connection.');
        default:
          break;
      }
      if (code == 401 || code == 403) {
        return Failure('Access denied. Check your AUDIUS_API_KEY.', code: code);
      }
      if (code == 404) return Failure('Not found.', code: code);
      if (code == 429) {
        return Failure('Too many requests. Please wait a moment.', code: code);
      }
      if (code != null && code >= 500) {
        return Failure('Audius is having trouble right now.', code: code);
      }
    }
    return const Failure('Something went wrong. Please try again.');
  }

  @override
  String toString() => message;
}
