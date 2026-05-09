// lib/services/biometric_service.dart

import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String baseUrl = ApiConfig.baseUrl;

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

  Future<bool> enableBiometric(String email) async {
    try {
      print('🔐 Enabling biometric for: $email');

      final authenticated = await authenticateWithBiometrics();
      if (!authenticated) {
        print('❌ Authentication failed for enabling biometrics');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/biometric/enable'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      print('📥 Enable biometric response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('biometric_token_$email', token);
        await prefs.setBool('biometric_enabled_$email', true);

        print('✅ Biometric enabled for: $email');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error enabling biometric: $e');
      return false;
    }
  }

  Future<bool> disableBiometric(String email) async {
    try {
      print('🔓 Disabling biometric for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/api/biometric/disable'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
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

  Future<bool> isBiometricEnabledForUser(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/biometric/status/$email'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        final localToken = prefs.getString('biometric_token_$email');

        print('🔐 Biometric status for $email - Backend: ${data['biometricEnabled']}, Local token: ${localToken != null}');

        return data['biometricEnabled'] == true && localToken != null;
      }

      return false;
    } catch (e) {
      print('Error checking biometric status: $e');
      return false;
    }
  }

  // FIXED: Added alreadyAuthenticated parameter
  Future<Map<String, dynamic>?> biometricLogin(String email, {bool alreadyAuthenticated = false}) async {
    try {
      print('🔓 Biometric login for: $email');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('biometric_token_$email');

      if (token == null) {
        print('❌ No biometric token found for: $email');
        return null;
      }

      print('✅ Found biometric token');

      // ONLY authenticate if not already authenticated by caller
      if (!alreadyAuthenticated) {
        final authenticated = await authenticateWithBiometrics();
        if (!authenticated) {
          print('❌ Authentication failed');
          return null;
        }
      } else {
        print('✅ Using pre-authenticated session (skipping second prompt)');
      }

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

        final user = data['user'];
        if (user != null) {
          await _autoLoginToLMS(user['lmsUsername'], email);
        }

        return user;
      }

      print('❌ Backend rejected biometric login');
      return null;
    } catch (e) {
      print('Biometric login error: $e');
      return null;
    }
  }

  Future<void> _autoLoginToLMS(String lmsUsername, String email) async {
    try {
      print('🔄 Auto-logging into LMS for: $lmsUsername');

      final response = await http.post(
        Uri.parse('$baseUrl/api/lms/login'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': email,
        },
        body: jsonEncode({
          'username': lmsUsername,
          'password': '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ LMS auto-login successful');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('lms_session_$email', DateTime.now().toIso8601String());
        }
      }
    } catch (e) {
      print('LMS auto-login error: $e');
    }
  }

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