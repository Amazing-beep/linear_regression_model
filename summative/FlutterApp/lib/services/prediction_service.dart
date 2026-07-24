import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/prediction_request.dart';
import '../models/prediction_response.dart';

/// Exception thrown when prediction service operations fail.
class PredictionException implements Exception {
  final String message;
  const PredictionException(this.message);

  @override
  String toString() => message;
}

/// Service class responsible for communicating with the FastAPI prediction endpoint.
class PredictionService {
  static const String defaultBaseUrl =
    'https://linear-regression-model-ln95.onrender.com';
  final http.Client _client;

  PredictionService({http.Client? client}) : _client = client ?? http.Client();

  /// Submits a prediction request to the API and returns the parsed [PredictionResponse].
  Future<PredictionResponse> predict(
    PredictionRequest request, {
    String? baseUrl,
  }) async {
    final String base = (baseUrl != null && baseUrl.trim().isNotEmpty)
        ? baseUrl.trim()
        : defaultBaseUrl;

    // Normalize URL to ensure correct path formatting
    final String cleanBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final Uri uri = Uri.parse('$cleanBase/predict');

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> jsonMap = jsonDecode(response.body);
          return PredictionResponse.fromJson(jsonMap);
        } catch (e) {
          throw const PredictionException(
            'Received invalid JSON response format from the server.',
          );
        }
      } else if (response.statusCode == 422) {
        try {
          final Map<String, dynamic> jsonMap = jsonDecode(response.body);
          final detail = jsonMap['detail'];
          throw PredictionException('Validation Error (422): $detail');
        } catch (e) {
          if (e is PredictionException) rethrow;
          throw const PredictionException(
            'Validation failed (422): Input values rejected by server schema.',
          );
        }
      } else if (response.statusCode >= 500) {
        throw PredictionException(
          'Server Error (${response.statusCode}): The backend server encountered an error.',
        );
      } else {
        throw PredictionException(
          'API Request failed with HTTP status ${response.statusCode}.',
        );
      }
    } on SocketException {
      throw const PredictionException(
        'No internet connection. Please check your network connectivity and try again.',
      );
    } on TimeoutException {
      throw const PredictionException(
        'Request timed out. The server took too long to respond.',
      );
    } on http.ClientException catch (e) {
      throw PredictionException('Network communication error: ${e.message}');
    } on FormatException {
      throw const PredictionException(
        'Invalid response format received from the API server.',
      );
    } catch (e) {
      if (e is PredictionException) rethrow;
      throw PredictionException(
        'An unexpected error occurred: ${e.toString()}',
      );
    }
  }
}
