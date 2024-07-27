import 'dart:io';

import 'package:dio/dio.dart';

import 'package:icrypex_wallet_app/app/repositories/app_repository.dart';
import 'package:logger/logger.dart';

class AppInterceptors extends Interceptor {
  final Dio dio;
  final Logger logger;

  AppInterceptors(this.dio, this.logger);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    logger.d(
      'REQUEST[${options.method}] \n\nPATH: ${options.path}  \n\nHEADER: ${options.headers}  \n\nBODY: ${options.data}',
      time: DateTime.now(),
    );

    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Log response details
    logger.d(
      'RESPONSE[${response.statusCode}]  \n\nPATH: ${response.requestOptions.path}  \n\nBODY: ${response.data}',
      time: DateTime.now(),
    );

    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    const String errorMessage = 'Token refresh failed. No new token obtained.';

    // Önceden oluşturulmuş bir hata nesnesi
    final DioException error = DioException(
      requestOptions: err.requestOptions,
      response: Response(
        requestOptions: err.requestOptions,
        statusCode: HttpStatus.unauthorized,
        statusMessage: errorMessage,
        data: errorMessage,
      ),
    );

    // Eğer istek yolu auth, otp veya verify içeriyorsa logout işlemi yap
    if (['auth', 'otp', 'verify'].any((path) => err.requestOptions.path.contains(path))) {
      return handler.resolve(err.response!);
    }

    // Unauthorized veya Internal Server Error durumunda token yenilemeyi dene
    if (err.response?.statusCode == HttpStatus.unauthorized ||
        err.response?.statusCode == HttpStatus.internalServerError) {
      try {
        final String? response = await AppRepository().refreshToken();

        if (response?.isEmpty ?? true) {
          logger.d(errorMessage);
          return handler.reject(error);
        }

        final Map<String, String> headers = {'Authorization': 'Bearer $response'};
        final RequestOptions requestOption = err.requestOptions.copyWith(headers: headers);

        final Response refreshedResponse = await dio.fetch(requestOption)
          ..requestOptions = err.requestOptions;

        return handler.resolve(refreshedResponse);
      } catch (e) {
        logger.e('Error refreshing token: $e');
        return handler.reject(error);
      }
    }

    // Diğer durumlarda hata logla ve hatayı çözümle
    logger.e(
      'Non-unauthorized error[${err.response?.statusCode}] '
      '\n\nPATH: ${err.requestOptions.path} '
      '\n\nBODY: ${err.response?.data}',
      stackTrace: err.stackTrace,
      error: err.error,
    );

    return handler.resolve(err.response!);
  }
}
