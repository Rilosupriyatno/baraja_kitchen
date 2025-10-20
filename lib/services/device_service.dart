import 'dart:convert';
import 'package:baraja_bar/models/device.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class DeviceService {

  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

  // Get all devices
  Future<List<Device>> getDevices() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/devices'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Parse sebagai Map dulu, bukan langsung List
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // Ambil array dari key 'data'
        final List<dynamic> jsonData = jsonResponse['data'];

        return jsonData.map((json) => Device.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load devices: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching devices: $e');
    }
  }

  // Get device by ID
  Future<Device> getDeviceById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/devices/$id'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return Device.fromJson(jsonData);
      } else {
        throw Exception('Failed to load device: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching device: $e');
    }
  }

  // Get devices by outlet ID
  Future<List<Device>> getDevicesByOutlet(String outletId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/devices?outletId=$outletId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => Device.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load devices: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching devices: $e');
    }
  }

  // Get online devices only
  Future<List<Device>> getOnlineDevices() async {
    try {
      final devices = await getDevices();
      return devices.where((device) => device.isOnline).toList();
    } catch (e) {
      throw Exception('Error fetching online devices: $e');
    }
  }

  // Get active devices only
  Future<List<Device>> getActiveDevices() async {
    try {
      final devices = await getDevices();
      return devices.where((device) => device.isActive).toList();
    } catch (e) {
      throw Exception('Error fetching active devices: $e');
    }
  }
}