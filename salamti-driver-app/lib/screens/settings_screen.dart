import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'package:google_sign_in/google_sign_in.dart'; //Gmail log out
import 'package:http_parser/http_parser.dart';
import '../main.dart';
import 'package:geolocator/geolocator.dart';

//  Storage keys
const _kProfileImage = 'profile_image_url';
const _kProfileCache = 'settings_profile_cache';

// SETTINGS SCREEN
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _subPage;
  bool _isDisconnecting = false;
  String? _obuId;
  bool _locationEnabled = false;

  // Identity fields
  String _fullName = '';
  String _email = '';
  String _phone = '';
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkLocationStatus();
  }

  Future<void> _checkLocationStatus() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    if (mounted) {
      setState(() {
        _locationEnabled = enabled &&
            permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProfile();
    _checkLocationStatus();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kProfileCache);

    //1 — load from local cache immediately
    if (cached != null) {
      final map = jsonDecode(cached) as Map<String, dynamic>;
      setState(() {
        _fullName = map['fullName'] as String? ?? '';
        _email = map['email'] as String? ?? '';
        _phone = map['phone'] as String? ?? '';
        _imageUrl = prefs.getString(_kProfileImage);
        _obuId = prefs.getString('obu_id');
      });
    }

    //2 — fetch from API and update
    try {
      final token = await AuthService.getAccessToken();
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/my-profile'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final user =
            jsonDecode(res.body)['data']['user'] as Map<String, dynamic>;
        final fullName = user['fullName'] as String? ?? '';
        final email = user['email'] as String? ?? '';
        final phone = user['phone'] as String? ?? '';
        setState(() {
          _fullName = fullName;
          _email = email;
          _phone = phone;
          _obuId = prefs.getString('obu_id');
        });
        await prefs.setString(
            _kProfileCache,
            jsonEncode({
              'fullName': fullName,
              'email': email,
              'phone': phone,
            }));
        final imageUrl = user['image'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          await prefs.setString(_kProfileImage, imageUrl);
          setState(() => _imageUrl = imageUrl);
        }
      } else {
        assert(() {
          debugPrint(
              'Settings _loadProfile error: ${res.statusCode} - ${res.body}');
          return true;
        }());
      }
    } catch (e) {
      assert(() {
        debugPrint('Settings _loadProfile exception: $e');
        return true;
      }());
    }
  }

  Future<void> _disconnectObu() async {
    final prefs = await SharedPreferences.getInstance();
    final obuId = prefs.getString('obu_id');
    setState(() => _isDisconnecting = true);
    try {
      final token = await AuthService.getAccessToken();
      final res = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/obus/$obuId/disconnect'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if ((res.statusCode == 200 || res.statusCode == 201) && mounted) {
        setState(() => _obuId = null);
        await Future.wait([
          prefs.remove('obu_id'),
          prefs.remove('obu_name'),
          prefs.remove('obu_inst_number'),
          prefs.remove('obu_sim_number'),
        ]);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('OBU disconnected successfully.',
                style: TextStyle(fontFamily: 'Outfit')),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } else {
        assert(() {
          debugPrint('OBU disconnect error: ${res.statusCode} - ${res.body}');
          return true;
        }());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Failed to disconnect. Please try again.',
                style: TextStyle(fontFamily: 'Outfit')),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    } catch (e) {
      assert(() {
        debugPrint('OBU disconnect error: $e');
        return true;
      }());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to disconnect. Please try again.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isDisconnecting = false);
    }
  }

  Future<void> _logout() async {
    print('[Settings] _logout: Starting logout process');
    try {
      // 1. Terminate Google / Gmail session safely using the singleton instance
      final googleSignIn = GoogleSignIn.instance;
      try {
        await googleSignIn.signOut();
        await googleSignIn.disconnect();
        print('[Settings] _logout: Google session cleared');
      } catch (googleError) {
        print('[Settings] _logout: Google session clear failed: $googleError');
      }

      // 2. Call backend logout endpoint
      final token = await AuthService.getAccessToken();
      if (token != null) {
        print('[Settings] _logout: Calling backend logout endpoint');
        final res = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        print('[Settings] _logout: Backend response: ${res.statusCode}');
      } else {
        print('[Settings] _logout: No token available');
      }
    } catch (e) {
      print('[Settings] _logout exception: $e');
    }

    // 3. Clear local data
    print('[Settings] _logout: Clearing local storage');
    final prefs = await SharedPreferences.getInstance();
    // Read medical data before clearing
    final bloodType = prefs.getString('health_blood_type');
    final conditions = prefs.getString('health_conditions');
    final meds = prefs.getString('health_meds');
    final allergies = prefs.getString('health_allergies');

    await prefs.clear();

    // Restore medical data
    if (bloodType != null)
      await prefs.setString('health_blood_type', bloodType);
    if (conditions != null)
      await prefs.setString('health_conditions', conditions);
    if (meds != null) await prefs.setString('health_meds', meds);
    if (allergies != null) await prefs.setString('health_allergies', allergies);
    print('[Settings] _logout: Local storage cleared');

    // 4. Update the RootController state directly instead of using named routes
    print('[Settings] _logout: Redirecting to auth screen');
    rootControllerKey.currentState?.logOutAndRedirect();
  }

  String get _initials {
    final parts =
        _fullName.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _buildSubPage() {
    if (_subPage == 'documents') {
      return _ProfilePhotoSubPage(
        currentImageUrl: _imageUrl,
        onImageUploaded: (url) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kProfileImage, url);
          setState(() => _imageUrl = url);
        },
        onBack: () => setState(() => _subPage = null),
      );
    }
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    if (_subPage != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _subPage = null);
        },
        child: _buildSubPage(),
      );
    }

    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
          child: Row(
            children: const [
              Expanded(
                child: Text('Settings',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'Outfit')),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── Identity section ──
              const SectionLabel('Identity'),
              AppCard(
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _subPage = 'documents'),
                      child: _imageUrl != null && _imageUrl!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                _imageUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    AvatarCircle(initials: _initials, size: 80),
                              ),
                            )
                          : AvatarCircle(initials: _initials, size: 80),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fullName.isEmpty ? '—' : _fullName,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                fontFamily: 'Outfit'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.mail_outline,
                                  size: 15, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _email.isEmpty ? '—' : _email,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                      fontFamily: 'Outfit'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined,
                                  size: 15, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                _phone.isEmpty ? '—' : _phone,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Outfit'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Account Settings ──
              const SectionLabel('Account Settings'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SettingsRow(
                  icon: Icons.camera_alt_outlined,
                  label: 'Profile Photo',
                  subtitle: 'Upload or change your profile picture',
                  onTap: () => setState(() => _subPage = 'documents'),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: (_isDisconnecting || _obuId == null || _obuId!.isEmpty)
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.card2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            title: const Text('Disconnect OBU & Car?',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'Outfit')),
                            content: const Text(
                                'This will unlink your OBU device from your vehicle.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                    fontFamily: 'Outfit')),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontFamily: 'Outfit')),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Disconnect',
                                    style: TextStyle(
                                        color: AppColors.red,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Outfit')),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) _disconnectObu();
                      },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 194, 78, 78),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _isDisconnecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Disconnect OBU & Car',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'Outfit')),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Safety & Privacy ──
              const SectionLabel('Safety & Privacy'),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Location Sharing',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                        fontFamily: 'Outfit')),
                                Text('Share real-time status during trips',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                        fontFamily: 'Outfit')),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _locationEnabled
                                  ? AppColors.green.withOpacity(0.15)
                                  : AppColors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _locationEnabled ? 'On' : 'Off',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _locationEnabled
                                      ? AppColors.green
                                      : AppColors.red,
                                  fontFamily: 'Outfit'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    const ToggleRow(label: 'Public Profile'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Preferences ──
              const SectionLabel('Preferences'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SettingsRow(
                      icon: Icons.notifications_outlined,
                      label: 'Notification Preferences',
                      subtitle: 'Rides, speed alerts, updates',
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    SettingsRow(
                      icon: Icons.language_outlined,
                      label: 'App Language',
                      subtitle: 'English (US)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Support ──
              const SectionLabel('Support'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SettingsRow(icon: Icons.help_outline, label: 'Help Center'),
                    const Divider(color: AppColors.border, height: 1),
                    SettingsRow(
                      icon: Icons.info_outline,
                      label: 'App Version',
                      trailingText: 'v4.12.0 (Build 902)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SecondaryButton(label: ' Log Out ', onTap: _logout),
              const SizedBox(height: 12),
              const Center(
                child: Text('Salamati Driver System © 2026',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontFamily: 'Outfit')),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

// PROFILE PHOTO SUB-PAGE
class _ProfilePhotoSubPage extends StatefulWidget {
  final String? currentImageUrl;
  final ValueChanged<String> onImageUploaded;
  final VoidCallback onBack;

  const _ProfilePhotoSubPage({
    required this.currentImageUrl,
    required this.onImageUploaded,
    required this.onBack,
  });

  @override
  State<_ProfilePhotoSubPage> createState() => _ProfilePhotoSubPageState();
}

class _ProfilePhotoSubPageState extends State<_ProfilePhotoSubPage> {
  bool _isUploading = false;
  String? _imageUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.currentImageUrl;
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) {
      print('[Settings] _pickAndUpload: No file selected');
      return;
    }
    final file = result.files.first;
    if (file.path == null) {
      print('[Settings] _pickAndUpload: File path is null');
      return;
    }

    print('[Settings] _pickAndUpload: Starting upload for ${file.name}');
    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final token = await AuthService.getAccessToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/upload/profile-image'),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      final bytes = await file.xFile.readAsBytes();

      // Determine content type based on file extension
      final ext = file.extension?.toLowerCase() ?? 'jpg';
      final subtype = ext == 'jpg' ? 'jpeg' : ext;

      request.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: file.name,
        contentType: MediaType('image', subtype),
      ));
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200 || res.statusCode == 201) {
        try {
          final url = jsonDecode(res.body)['data']['image'] as String;
          setState(() => _imageUrl = url);
          widget.onImageUploaded(url);
        } catch (e) {
          assert(() {
            debugPrint('Settings _pickAndUpload parse error: $e');
            return true;
          }());
          setState(() => _error = 'Invalid server response. Please try again.');
        }
      } else {
        try {
          final errorBody = jsonDecode(res.body);
          final errorMsg = errorBody['data']?['message'] ??
              errorBody['message'] ??
              'Upload failed';
          setState(() => _error = errorMsg);
        } catch (_) {
          assert(() {
            debugPrint(
                'Settings _pickAndUpload error (${res.statusCode}): ${res.body}');
            return true;
          }());
          setState(() =>
              _error = 'Upload failed (${res.statusCode}). Please try again.');
        }
      }
    } catch (e) {
      assert(() {
        debugPrint('Settings _pickAndUpload exception: $e');
        return true;
      }());
      setState(() => _error = 'Network error. Please try again.');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteImage() async {
    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final token = await AuthService.getAccessToken();
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/upload/profile-image'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      assert(() {
        debugPrint('Delete response: ${res.statusCode} - ${res.body}');
        return true;
      }());

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() => _imageUrl = null);
        widget.onImageUploaded('');
      } else {
        try {
          final errorBody = jsonDecode(res.body);
          final errorMsg = errorBody['data']?['message'] ??
              errorBody['message'] ??
              'Delete failed';
          setState(() => _error = errorMsg);
        } catch (_) {
          setState(() =>
              _error = 'Delete failed (${res.statusCode}). Please try again.');
        }
      }
    } catch (e) {
      assert(() {
        debugPrint('Network/delete error: $e');
        return true;
      }());
      setState(() => _error = 'Network error. Please try again.');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: AppColors.blueLight, size: 20),
                onPressed: widget.onBack,
              ),
              const Expanded(
                child: Text('Profile Photo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'Outfit')),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 20),

              // Avatar preview
              Center(
                child: Stack(
                  children: [
                    _imageUrl != null && _imageUrl!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              _imageUrl!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _placeholderAvatar(),
                            ),
                          )
                        : _placeholderAvatar(),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bg, width: 2),
                        ),
                        child: _isUploading
                            ? const Padding(
                                padding: EdgeInsets.all(7),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.camera_alt,
                                color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Status text
              Center(
                child: Text(
                  _isUploading
                      ? 'Uploading...'
                      : _imageUrl != null && _imageUrl!.isNotEmpty
                          ? 'Profile photo set'
                          : 'No profile photo yet',
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontFamily: 'Outfit'),
                ),
              ),

              // Error
              if (_error != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.red, size: 14),
                    const SizedBox(width: 6),
                    Text(_error!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.red,
                            fontFamily: 'Outfit')),
                  ],
                ),
              ],

              const SizedBox(height: 32),
              PrimaryButton(
                label: _imageUrl != null && _imageUrl!.isNotEmpty
                    ? 'Change Photo'
                    : 'Upload Photo',
                onTap: _isUploading ? null : _pickAndUpload,
              ),
              if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'Delete Photo',
                  onTap: _isUploading ? null : _deleteImage,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholderAvatar() => Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.card2,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: const Icon(Icons.person_outline,
            color: AppColors.textMuted, size: 52),
      );
}
