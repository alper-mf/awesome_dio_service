// ignore_for_file: constant_identifier_names

library cp_dio_client;

import 'package:dio/dio.dart';
import 'package:icrypex_wallet_app/app/managers/dio_service/service/app_interceptors.dart';
import 'package:logger/logger.dart';

import 'service/mock_api_service.dart';

// Enum to define HTTP methods
enum DioHttpMethod { GET, POST, PUT, DELETE, PATCH, UPDATE }

// DioClient class for handling API requests
class DioClient {
  static DioClient? _instance; // Singleton instance of DioClient
  final String baseUrl; // Base URL of the API

  final Map<String, dynamic>? headerParam; // Token for authorization
  final MockApiService mockApiService = MockApiService(); // MockApiService for testing
  final Dio _dio; // Dio instance for making HTTP requests
  late final AppInterceptors _appInterceptors; // AppInterceptors for logging requests and responses

  //* Logger
  final logger = Logger(
    printer: PrettyPrinter(
      errorMethodCount: 8, // Number of method calls if stacktrace is provided
      lineLength: 120, // Width of the output
      colors: false, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
      printTime: true, // Should each log print contain a timestamp
    ),
    level: Level.all,
  ); // Logger for logging requests and responses

  // Singleton instance method for DioClient
  static DioClient instance({
    required String baseUrl,
    Map<String, dynamic>? headerParam,
  }) {
    _instance ??= DioClient._internal(
      baseUrl: baseUrl,
      headerParam: headerParam,
    );

    if (_instance == null) {
      throw Exception('DioClient instance not initialized');
    }

    return _instance!;
  }

  // Private constructor for DioClient
  DioClient._internal({required this.baseUrl, this.headerParam}) : _dio = Dio() {
    addInterceptors();
  }

  // Method to add interceptors for logging requests and responses
  void addInterceptors() {
    _dio.options = BaseOptions(
      baseUrl: Uri.https(baseUrl, '').toString(),
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: headerParam,
    );

    _appInterceptors = AppInterceptors(_dio, logger);

    _dio.interceptors.add(_appInterceptors);
  }

  // Helper method to create Dio Options with headers
  Options _options(Map<String, dynamic>? customHeaderParams) {
    Map<String, dynamic> headers = {};
    headers.addAll(customHeaderParams ?? {});
    headers.addAll(headerParam ?? {});

    return Options(headers: headers);
  }

  // Method to send HTTP requests based on the specified method
  Future<Response?> _sendRequest(
    DioHttpMethod method,
    String pathBody,
    Map<String, dynamic> bodyParam,
    Map<String, String>? customHeaderParams,
    Map<String, dynamic>? queryParams,
    bool? forceRefresh,
  ) async {
    var uri = Uri.https(baseUrl, (pathBody.isNotEmpty ? '/$pathBody' : ''), queryParams);
    try {
      Response response;
      switch (method) {
        case DioHttpMethod.GET:
          // Send GET request
          response = await _dio.getUri(uri, options: _options(customHeaderParams));
          break;
        case DioHttpMethod.POST:
          // Send POST request
          response = await _dio.postUri(uri, data: bodyParam, options: _options(customHeaderParams));
          break;
        case DioHttpMethod.DELETE:
          // Send DELETE request
          response = await _dio.deleteUri(uri, data: bodyParam, options: _options(customHeaderParams));
          break;
        case DioHttpMethod.PUT:
          // Send PUT request
          response = await _dio.putUri(uri, data: bodyParam, options: _options(customHeaderParams));
          break;
        case DioHttpMethod.PATCH:
          // Send PATCH request
          response = await _dio.patchUri(uri, data: bodyParam, options: _options(customHeaderParams));
          break;
        default:
          // Handle unsupported HTTP methods
          throw DioException(requestOptions: RequestOptions(path: pathBody), error: 'Method not found');
      }

      return response;
    } on DioException {
      rethrow;
    }
  }

  /// Public method to make HTTP requests
  Future<Response?> request(
    DioHttpMethod method,
    String path, {
    Map<String, dynamic> bodyParam = const {},
    Map<String, String>? headerParam,
    Map<String, dynamic>? queryParams,
  }) async {
    return await _sendRequest(method, path, bodyParam, headerParam, queryParams, null);
  }
}
