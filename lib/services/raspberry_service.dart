import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RaspberryService with ChangeNotifier {
  String? _raspberryIp;
  int _port = 8000;
  bool _isConnected = false;
  
  bool get isConnected => _isConnected;
  
  Future<void> connectToRaspberry(String ipAddress, [int? port]) async {
    try {
      if (port != null) {
        _port = port;
      }
      
      _raspberryIp = ipAddress;
      
      // Test connection
      final response = await http.get(
        Uri.parse('http://$_raspberryIp:$_port/test'),
      ).timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        _isConnected = true;
        
        // Save connection info
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('raspberryIp', ipAddress);
        await prefs.setInt('raspberryPort', _port);
        
        notifyListeners();
      } else {
        throw 'Connection failed: ${response.statusCode}';
      }
    } catch (e) {
      _isConnected = false;
      notifyListeners();
      throw 'Failed to connect to Raspberry Pi: $e';
    }
  }
  
  Future<void> loadSavedConnection() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedIp = prefs.getString('raspberryIp');
    int? savedPort = prefs.getInt('raspberryPort');
    
    if (savedIp != null) {
      try {
        await connectToRaspberry(savedIp, savedPort);
      } catch (e) {
        // Failed to connect with saved details
        _isConnected = false;
      }
    }
  }
  
  Future<Map<String, dynamic>> detectPlaqueAndDecay(Uint8List imageBytes) async {
    if (!_isConnected || _raspberryIp == null) {
      throw 'Not connected to Raspberry Pi';
    }
    
    try {
      var request = http.MultipartRequest(
        'POST',
         Uri.parse('http://$_raspberryIp:$_port/detect')
      );
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'camera_image.jpg',
        )
      );
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw 'Detection failed: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Failed to detect plaque and decay: $e';
    }
  }
  
  void disconnect() {
    _isConnected = false;
    notifyListeners();
  }
}