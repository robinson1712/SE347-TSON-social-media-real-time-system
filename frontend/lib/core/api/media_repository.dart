import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import 'dio_client.dart';

/// Shared by any feature that uploads a file to media-service
/// (post composer, profile avatar/cover).
class MediaRepository {
  final Dio _dio = DioClient.instance;

  Future<String> uploadBytes({
    required List<int> bytes,
    required String filename,
    required MediaPurpose purpose,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        'purpose': purpose.toJson(),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/media/upload',
        data: formData,
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return data['url'] as String;
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}

final mediaRepositoryProvider = Provider((ref) => MediaRepository());
