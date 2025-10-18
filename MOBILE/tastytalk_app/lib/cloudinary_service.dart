import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  final String cloudName;
  final String uploadPreset; // unsigned upload preset

  CloudinaryService({required this.cloudName, required this.uploadPreset});

  Future<String> uploadImage(File file) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );
    final request =
        http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = uploadPreset
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = data['secure_url']?.toString();
      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception('Upload succeeded but secure_url missing');
      }
      return secureUrl;
    }

    throw Exception(
      'Cloudinary upload failed: ${response.statusCode} ${response.body}',
    );
  }
}
