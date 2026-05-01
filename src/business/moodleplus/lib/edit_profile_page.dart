// US-03: Edit Profile Feature
// US-03-T-01: User Change Credentials

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onProfileUpdated;

  const EditProfilePage({
    super.key,
    required this.user,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {

  static const String baseUrl = ApiConfig.baseUrl;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // State variables
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _profilePictureBase64;
  File? _selectedImage;

  // Validation flags
  bool _isEmailValid = true;
  bool _doPasswordsMatch = true;
  bool _isNewPasswordValid = true;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user['name'] ?? '';
    _emailController.text = widget.user['email'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // US-03-T-01: User Change Credentials - Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);

        setState(() {
          _selectedImage = File(pickedFile.path);
          _profilePictureBase64 = base64String;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      _showSnackBar('Failed to pick image', Colors.red);
    }
  }

  // US-03-T-01: User Change Credentials - Show image picker dialog
  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Profile Picture'),
        content: const Text('Choose an option'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedImage = null;
                _profilePictureBase64 = null;
              });
              _showSnackBar('Profile picture removed', Colors.orange);
            },
            icon: const Icon(Icons.delete),
            label: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // US-03-T-01: User Change Credentials - Validate email format
  void _validateEmail(String email) {
    setState(() {
      _isEmailValid = email.contains('@') && email.isNotEmpty;
    });
  }

  // US-03-T-01: User Change Credentials - Validate password match
  void _validatePasswordMatch(String confirmPassword) {
    setState(() {
      _doPasswordsMatch = confirmPassword == _newPasswordController.text;
    });
  }

  // US-03-T-01: User Change Credentials - Validate new password length
  void _validateNewPassword(String password) {
    setState(() {
      _isNewPasswordValid = password.isEmpty || password.length >= 8;
    });
    _validatePasswordMatch(_confirmPasswordController.text);
  }

  // US-03-T-01: User Change Credentials - Update email
  Future<Map<String, dynamic>?> _updateEmail() async {
    if (_emailController.text == widget.user['email']) {
      return widget.user;
    }

    if (!_isEmailValid) {
      _showSnackBar('Please enter a valid email address', Colors.red);
      return null;
    }

    if (_currentPasswordController.text.isEmpty) {
      _showSnackBar(
        'Please enter your current password to update email',
        Colors.red,
      );
      return null;
    }

    try {
      print('Sending email update request...');
      print('Old email: ${widget.user['email']}');
      print('New email: ${_emailController.text}');

      final response = await http.put(
        Uri.parse('$baseUrl/api/user/email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.user['email'], // Current email
          'newEmail': _emailController.text.trim(), // New email
          'password':
              _currentPasswordController.text, // Current password for auth
        }),
      );

      final data = jsonDecode(response.body);
      print('Update email response status: ${response.statusCode}');
      print('Update email response body: ${response.body}');

      if (response.statusCode == 200) {
        _showSnackBar('Email updated successfully!', Colors.green);
        return data['user']; // Return the updated user data from server
      } else {
        _showSnackBar(data['error'] ?? 'Failed to update email', Colors.red);
        return null;
      }
    } catch (e) {
      print('Update email error: $e');
      _showSnackBar('Connection error: $e', Colors.red);
      return null;
    }
  }

  // US-03-T-01: User Change Credentials - Update app password
  Future<bool> _updateAppPassword() async {
    if (_newPasswordController.text.isEmpty) {
      return true; // No password change
    }

    if (!_isNewPasswordValid) {
      _showSnackBar('Password must be at least 8 characters', Colors.red);
      return false;
    }

    if (!_doPasswordsMatch) {
      _showSnackBar('New passwords do not match', Colors.red);
      return false;
    }

    if (_currentPasswordController.text.isEmpty) {
      _showSnackBar('Please enter your current password', Colors.red);
      return false;
    }

    try {
      print('Changing app password for: ${widget.user['email']}');
      print('New password length: ${_newPasswordController.text.length}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/user/change-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.user['email'],
          'currentPassword': _currentPasswordController.text,
          'newPassword': _newPasswordController.text,
        }),
      );

      final data = jsonDecode(response.body);
      print('Change password response: ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        _showSnackBar('App password updated successfully!', Colors.green);
        return true;
      } else {
        _showSnackBar(data['error'] ?? 'Failed to update password', Colors.red);
        return false;
      }
    } catch (e) {
      print('Update password error: $e');
      _showSnackBar('Connection error: $e', Colors.red);
      return false;
    }
  }

  // US-03-T-01: User Change Credentials - Update profile picture
  Future<bool> _updateProfilePicture() async {
    if (_profilePictureBase64 == null && _selectedImage == null) {
      return true; // No change
    }

    if (_currentPasswordController.text.isEmpty) {
      _showSnackBar(
        'Please enter your current password to update profile picture',
        Colors.red,
      );
      return false;
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/user/profile-picture'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.user['email'],
          'profilePicture': _profilePictureBase64,
          'password': _currentPasswordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showSnackBar('Profile picture updated!', Colors.green);
        return true;
      } else {
        _showSnackBar(
          data['error'] ?? 'Failed to update profile picture',
          Colors.red,
        );
        return false;
      }
    } catch (e) {
      print('Update profile picture error: $e');
      _showSnackBar('Connection error', Colors.red);
      return false;
    }
  }

  // US-03-T-02: User Credential Update - Save all changes
  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    Map<String, dynamic> updatedUserData = {
      'name': _nameController.text,
      'email': widget.user['email'], // Start with current email
      'lmsUsername': widget.user['lmsUsername'],
    };

    // Update email and get updated user data
    final emailResult = await _updateEmail();
    if (emailResult != null) {
      updatedUserData = emailResult; // Use the updated user data from server
    } else if (_emailController.text != widget.user['email']) {
      // Email update failed
      setState(() => _isLoading = false);
      return;
    }

    // Update app password
    final passwordSuccess = await _updateAppPassword();
    if (!passwordSuccess && _newPasswordController.text.isNotEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // Update profile picture
    final pictureSuccess = await _updateProfilePicture();
    if (!pictureSuccess && _profilePictureBase64 != null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = false);

    if (emailResult != null || (passwordSuccess && pictureSuccess)) {
      // Add profile picture to updated data if changed
      if (_profilePictureBase64 != null) {
        updatedUserData['profilePicture'] = _profilePictureBase64;
      }

      _showSuccessDialog(updatedUserData);
    } else {
      _showSnackBar(
        'Some changes could not be saved. Please try again.',
        Colors.red,
      );
    }
  }

  // US-03-T-02: Show success popup notification
  void _showSuccessDialog(Map<String, dynamic> updatedUserData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('Profile Updated!'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your profile has been successfully updated.'),
            SizedBox(height: 8),
            Text(
              '• Changes will take effect immediately',
              style: TextStyle(fontSize: 12),
            ),
            Text(
              '• You will need to use new credentials for future logins',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Pass the updated user data back to home page
              widget.onProfileUpdated(updatedUserData);
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9D2BD1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: const Color(0xFF9D2BD1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _saveChanges,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            tooltip: 'Save Changes',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // US-03: Profile Picture Section
            _buildProfilePictureSection(),
            const SizedBox(height: 24),

            // US-03: Personal Information Section
            _buildPersonalInfoSection(),
            const SizedBox(height: 24),

            // US-03: Change Password Section
            _buildChangePasswordSection(),
            const SizedBox(height: 24),

            // US-03-T-01: Authentication Section (Current Password Required)
            _buildAuthenticationSection(),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9D2BD1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save All Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Note: Current password is required to make any changes to your profile.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // US-03: Profile Picture Widget
  Widget _buildProfilePictureSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _showImagePickerDialog,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                    border: Border.all(
                      color: const Color(0xFF9D2BD1),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: _selectedImage != null
                        ? Image.file(_selectedImage!, fit: BoxFit.cover)
                        : _profilePictureBase64 != null
                        ? Image.memory(
                            base64Decode(_profilePictureBase64!),
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            Icons.camera_alt,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _showImagePickerDialog,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Change Photo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // US-03: Personal Information Section
  Widget _buildPersonalInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Name field (read-only or editable? keeping editable)
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
                hintText: 'Enter your full name',
              ),
            ),
            const SizedBox(height: 16),

            // Email field
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email_outlined),
                hintText: 'Enter your email',
                errorText: _isEmailValid
                    ? null
                    : 'Please include an "@" in the email',
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: _validateEmail,
            ),
            const SizedBox(height: 8),

            // LMS Username (read-only)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[50],
              ),
              child: Row(
                children: [
                  const Icon(Icons.school, color: Colors.grey, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LMS Username',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          widget.user['lmsUsername'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // US-03-T-01: Change Password Section
  Widget _buildChangePasswordSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Change Password',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Leave blank to keep current password',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // New Password
            TextField(
              controller: _newPasswordController,
              obscureText: !_isNewPasswordVisible,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isNewPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(
                      () => _isNewPasswordVisible = !_isNewPasswordVisible,
                    );
                  },
                ),
                errorText: _isNewPasswordValid
                    ? null
                    : 'Password must be at least 8 characters',
              ),
              onChanged: _validateNewPassword,
            ),
            const SizedBox(height: 16),

            // Confirm Password
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(
                      () => _isConfirmPasswordVisible =
                          !_isConfirmPasswordVisible,
                    );
                  },
                ),
                errorText: _doPasswordsMatch ? null : 'Passwords do not match',
              ),
              onChanged: _validatePasswordMatch,
            ),
          ],
        ),
      ),
    );
  }

  // US-03-T-01: Authentication Section - Current password required
  Widget _buildAuthenticationSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Authentication Required',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Please enter your current password to confirm changes',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _currentPasswordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _isPasswordVisible = !_isPasswordVisible);
                  },
                ),
                hintText: 'Required to save any changes',
                fillColor: Colors.white,
                filled: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
