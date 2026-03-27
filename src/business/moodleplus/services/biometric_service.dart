// /lib/services/biometric_service.dart

import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// US-01-T-02: Biometrics Verification
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  static const String baseUrl = 'http://10.0.2.2:5000';

  // Check if biometric hardware is available
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final biometrics = await _localAuth.getAvailableBiometrics();

      print('🔍 Biometric check:');
      print('  - canCheckBiometrics: $isAvailable');
      print('  - isDeviceSupported: $isDeviceSupported');
      print('  - available biometrics: $biometrics');

      return isAvailable && isDeviceSupported && biometrics.isNotEmpty;
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      print('✅ Available biometrics: $biometrics');
      return biometrics;
    } catch (e) {
      print('Error getting biometrics: $e');
      return [];
    }
  }

  // Authenticate with biometrics or device PIN
  Future<bool> authenticateWithBiometrics() async {
    try {
      print('🔐 Starting authentication...');

      final isDeviceSupported = await _localAuth.isDeviceSupported();
      print('📱 Device supports biometrics: $isDeviceSupported');

      if (!isDeviceSupported) {
        print('❌ Device does not support biometric authentication');
        return false;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to continue',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      print('🔓 Authentication result: $authenticated');
      return authenticated;
    } catch (e) {
      print('❌ Authentication error: $e');
      return false;
    }
  }

  // Enable biometric for a user
  Future<bool> enableBiometric(String email) async {
    try {
      print('🔐 Enabling biometric for: $email');

      // First, authenticate to enable biometrics
      final authenticated = await authenticateWithBiometrics();
      if (!authenticated) {
        print('❌ Authentication failed for enabling biometrics');
        return false;
      }

      // Call backend to enable biometric
      final response = await http.post(
        Uri.parse('$baseUrl/api/biometric/enable'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];

        // Store token locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('biometric_token_$email', token);
        await prefs.setBool('biometric_enabled_$email', true);

        print('✅ Biometric enabled for: $email');
        return true;
      }

      print('❌ Backend returned error: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Error enabling biometric: $e');
      return false;
    }
  }

  // Disable biometric for a user
  Future<bool> disableBiometric(String email) async {
    try {
      print('🔓 Disabling biometric for: $email');

      // Call backend to disable biometric
      final response = await http.post(
        Uri.parse('$baseUrl/api/biometric/disable'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        // Remove local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('biometric_token_$email');
        await prefs.remove('biometric_enabled_$email');

        print('✅ Biometric disabled for: $email');
        return true;
      }

      return false;
    } catch (e) {
      print('Error disabling biometric: $e');
      return false;
    }
  }

  // Check if biometric is enabled for user
  Future<bool> isBiometricEnabledForUser(String email) async {
    try {
      // First check backend
      final response = await http.get(
        Uri.parse('$baseUrl/api/biometric/status/$email'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['biometricEnabled'] == true;
      }

      return false;
    } catch (e) {
      print('Error checking biometric status: $e');
      return false;
    }
  }

  // Perform biometric login
  Future<Map<String, dynamic>?> biometricLogin(String email) async {
    try {
      print('🔓 Biometric login for: $email');

      // Get stored token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('biometric_token_$email');

      if (token == null) {
        print('⚠️ No biometric token found for: $email');
        return null;
      }

      // Authenticate with biometrics
      final authenticated = await authenticateWithBiometrics();
      if (!authenticated) {
        print('❌ Authentication failed');
        return null;
      }

      // Call backend with token
      final response = await http.post(
        Uri.parse('$baseUrl/api/biometric/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'biometricToken': token,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Biometric login successful');
        return data['user'];
      }

      print('❌ Backend rejected biometric login');
      return null;
    } catch (e) {
      print('Biometric login error: $e');
      return null;
    }
  }

  // Get biometric type name for display
  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris Scan';
      default:
        return 'Biometric';
    }
  }
}