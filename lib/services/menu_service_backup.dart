import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/menu_model.dart';

class MenuService {
  final String baseUrl;
  final String imageUploadUrl;

  MenuService({
    String? baseUrl,
    String? imageUploadUrl,
  })  : baseUrl = baseUrl ?? dotenv.env['BASE_URL'] ?? '',
        imageUploadUrl = imageUploadUrl ?? dotenv.env['IMAGE_UPLOAD_URL'] ?? '';

  // Konversi image ke WebP
  Future<File> convertToWebP(File imageFile, {int quality = 85}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basenameWithoutExtension(imageFile.path);
      final targetPath = '${tempDir.path}/$fileName.webp';

      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: quality,
        format: CompressFormat.webp,
        minWidth: 1920,
        minHeight: 1920,
      );

      if (result == null) {
        throw Exception('Gagal compress image');
      }

      return File(result.path);
    } catch (e) {
      throw Exception('Error converting to WebP: $e');
    }
  }

  // Upload image ke img.barajacoffee.com
  Future<String> uploadImage(File imageFile) async {
    File? webpFile;

    try {
      webpFile = await convertToWebP(imageFile, quality: 85);

      var request = http.MultipartRequest('POST', Uri.parse(imageUploadUrl));

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          webpFile.path,
          filename: path.basename(webpFile.path),
        ),
      );

      print('Uploading image to: $imageUploadUrl');
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      print('Upload Response Status: ${response.statusCode}');
      print('Upload Response Body: $responseData');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Cek apakah response adalah JSON
        if (responseData.trim().startsWith('{') || responseData.trim().startsWith('[')) {
          var jsonResponse = json.decode(responseData);

          String filename = '';
          if (jsonResponse is Map) {
            filename = jsonResponse['filename'] ??
                jsonResponse['url'] ??
                jsonResponse['path'] ??
                jsonResponse['image'] ??
                jsonResponse['file'] ?? '';
          } else if (jsonResponse is String) {
            filename = jsonResponse;
          }

          if (filename.isEmpty) {
            throw Exception('Response tidak mengandung URL/filename gambar');
          }

          if (await webpFile.exists()) {
            await webpFile.delete();
          }

          if (filename.startsWith('http')) {
            return filename;
          } else {
            return 'https://img.barajacoffee.com/$filename';
          }
        } else {
          String filename = responseData.trim();

          if (await webpFile.exists()) {
            await webpFile.delete();
          }

          if (filename.startsWith('http')) {
            return filename;
          } else {
            return 'https://img.barajacoffee.com/$filename';
          }
        }
      } else {
        throw Exception('Upload gagal: ${response.statusCode} - $responseData');
      }
    } catch (e) {
      if (webpFile != null && await webpFile.exists()) {
        await webpFile.delete();
      }
      throw Exception('Error upload image: $e');
    }
  }

  Future<List<dynamic>> fetchCategories() async {
    try {
      final url = '$baseUrl/api/menu/categories';
      print('Fetching categories from: $url');

      final response = await http.get(
        Uri.parse(url),
      ).timeout(Duration(seconds: 10));

      print('Categories Response Status: ${response.statusCode}');
      print('Categories Response Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Response body kosong');
        }

        var jsonResponse = json.decode(response.body);

        // Response format: {"success": true, "data": [...]}
        if (jsonResponse is Map) {
          if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
            return jsonResponse['data'] as List<dynamic>;
          } else if (jsonResponse.containsKey('data')) {
            return jsonResponse['data'] as List<dynamic>;
          } else if (jsonResponse.containsKey('categories')) {
            return jsonResponse['categories'] as List<dynamic>;
          } else {
            throw Exception('Format response tidak sesuai: missing data key');
          }
        } else if (jsonResponse is List) {
          return jsonResponse;
        } else {
          throw Exception('Format response tidak valid');
        }
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timeout - cek koneksi internet Anda');
    } on SocketException {
      throw Exception('Tidak ada koneksi internet');
    } on FormatException catch (e) {
      throw Exception('Error parsing JSON: $e');
    } catch (e) {
      print('Error fetching categories: $e');
      throw Exception('Error fetching categories: $e');
    }
  }

  Future<List<dynamic>> fetchOutlets() async {
    try {
      final url = '$baseUrl/api/outlet';
      print('Fetching outlets from: $url');

      final response = await http.get(
        Uri.parse(url),
      ).timeout(Duration(seconds: 10));

      print('Outlets Response Status: ${response.statusCode}');
      print('Outlets Response Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Response body kosong');
        }

        var jsonResponse = json.decode(response.body);

        // Response format: {"success": true, "data": [...]}
        if (jsonResponse is Map) {
          if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
            return jsonResponse['data'] as List<dynamic>;
          } else if (jsonResponse.containsKey('data')) {
            return jsonResponse['data'] as List<dynamic>;
          } else if (jsonResponse.containsKey('outlets')) {
            return jsonResponse['outlets'] as List<dynamic>;
          } else {
            throw Exception('Format response tidak sesuai: missing data key');
          }
        } else if (jsonResponse is List) {
          return jsonResponse;
        } else {
          throw Exception('Format response tidak valid');
        }
      } else {
        throw Exception('Failed to load outlets: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timeout - cek koneksi internet Anda');
    } on SocketException {
      throw Exception('Tidak ada koneksi internet');
    } on FormatException catch (e) {
      throw Exception('Error parsing JSON: $e');
    } catch (e) {
      print('Error fetching outlets: $e');
      throw Exception('Error fetching outlets: $e');
    }
  }

  Future<bool> createMenuItem(MenuItem menuItem) async {
    try {
      final url = '$baseUrl/api/menu/menu-items';
      print('Creating menu at: $url');
      print('Menu data: ${json.encode(menuItem.toJson())}');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(menuItem.toJson()),
      ).timeout(Duration(seconds: 15));

      print('Create Menu Response Status: ${response.statusCode}');
      print('Create Menu Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Failed to create menu: ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Request timeout - cek koneksi internet Anda');
    } on SocketException {
      throw Exception('Tidak ada koneksi internet');
    } on FormatException catch (e) {
      throw Exception('Error parsing JSON: $e');
    } catch (e) {
      print('Error creating menu: $e');
      throw Exception('Error creating menu: $e');
    }
  }
}