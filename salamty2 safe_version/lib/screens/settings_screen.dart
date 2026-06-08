import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

// Import the public keys defined in profile_screen.dart
import 'profile_screen.dart' show kProfileName, kVehicleMake, kVehicleYear;

// ─────────────────────────────────────────────
//  Document upload storage keys
// ─────────────────────────────────────────────
const _kDocLicensePath = 'doc_license_path';
const _kDocIdPath = 'doc_id_path';
const _kDocPdfPath = 'doc_pdf_path';

// ─────────────────────────────────────────────
//  Upload file type enum
// ─────────────────────────────────────────────
enum _UploadFileType { image, pdf }

// ═══════════════════════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _subPage;
  bool _hwConnected = false;
  final _serialCtrl = TextEditingController();
  bool _deviceFound = false;
  String _profileName = '';
  String _vehicleMake = '';
  String _vehicleYear = '2026';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Reload name every time the user navigates back to this screen
  /// so it stays in sync with changes made on the Profile page.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(kProfileName) ?? '';
    setState(() {
      _profileName = name.trim().isEmpty ? 'Guest User' : name.trim();
      _vehicleMake = prefs.getString(kVehicleMake) ?? '';
      _vehicleYear = prefs.getString(kVehicleYear) ?? '2026';
    });
  }

  @override
  void dispose() {
    _serialCtrl.dispose();
    super.dispose();
  }

  String get _initials {
    final parts =
        _profileName.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _buildSubPage() {
    switch (_subPage) {
      case 'hardware':
        return _HardwareSubPage(
          ctrl: _serialCtrl,
          connected: _hwConnected,
          deviceFound: _deviceFound,
          onCheck: () {
            if (_serialCtrl.text.length >= 6) {
              setState(() => _deviceFound = true);
            }
          },
          onActivate: () => setState(() {
            _hwConnected = true;
            _subPage = null;
          }),
          onBack: () => setState(() {
            _subPage = null;
            _deviceFound = false;
          }),
        );
      case 'documents':
        return _DocumentsSubPage(onBack: () => setState(() => _subPage = null));
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_subPage != null) return _buildSubPage();

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
              // ── Profile summary ──
              AppCard(
                child: Row(
                  children: [
                    Stack(
                      children: [
                        AvatarCircle(initials: _initials, size: 52),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.bg, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_profileName,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'Outfit')),
                          const Text('Verified Driver • SafeID: 882-01',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontFamily: 'Outfit')),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined,
                        color: AppColors.textSecondary, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Hardware card ──
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.router_outlined,
                            color: AppColors.blueLight, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hardware Connection',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      fontFamily: 'Outfit')),
                              Text('OBD-II Smart Tracker v2.4',
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
                            color:
                                (_hwConnected ? AppColors.green : AppColors.red)
                                    .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: (_hwConnected
                                        ? AppColors.green
                                        : AppColors.red)
                                    .withOpacity(0.3)),
                          ),
                          child: Text(
                              _hwConnected ? '● Connected' : '● Disconnected',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _hwConnected
                                      ? AppColors.green
                                      : AppColors.red,
                                  fontFamily: 'Outfit')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_hwConnected)
                      GestureDetector(
                        onTap: () => setState(() => _subPage = 'hardware'),
                        child: const Text('Sync Now',
                            style: TextStyle(
                                color: AppColors.blueLight,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Outfit')),
                      )
                    else
                      PrimaryButton(
                        label: 'Connect Hardware Device',
                        onTap: () => setState(() => _subPage = 'hardware'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Account Settings — License & Documents only ──
              const SectionLabel('Account Settings'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SettingsRow(
                  icon: Icons.badge_outlined,
                  label: 'License & Documents',
                  subtitle: 'Upload your ID and license files',
                  onTap: () => setState(() => _subPage = 'documents'),
                ),
              ),
              const SizedBox(height: 12),

              // ── Safety & Privacy ──
              const SectionLabel('Safety & Privacy'),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: const [
                    ToggleRow(
                      label: 'Location Sharing',
                      subtitle: 'Share real-time status during trips',
                      initial: true,
                    ),
                    Divider(color: AppColors.border, height: 1),
                    ToggleRow(label: 'Public Profile'),
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
              SecondaryButton(label: '↪  Log Out'),
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

// ─── Hardware Sub-page ────────────────────────────────────────────────────────
class _HardwareSubPage extends StatelessWidget {
  final TextEditingController ctrl;
  final bool connected, deviceFound;
  final VoidCallback onCheck, onActivate, onBack;

  const _HardwareSubPage({
    required this.ctrl,
    required this.connected,
    required this.deviceFound,
    required this.onCheck,
    required this.onActivate,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: AppColors.blueLight, size: 20),
                onPressed: onBack,
              ),
              const Expanded(
                child: Text('Connect Hardware',
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
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (i) => Container(
                    width: i == 0 ? 28 : 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == 0 ? AppColors.blue : AppColors.textMuted,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Enter Serial Number',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'Outfit')),
              const SizedBox(height: 4),
              const Text('12-Digit Serial Number',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontFamily: 'Outfit')),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  letterSpacing: 2,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  hintText: 'GX1-000-000-X',
                  hintStyle:
                      TextStyle(color: AppColors.textMuted, letterSpacing: 1),
                  suffixIcon: Icon(Icons.qr_code_scanner,
                      color: AppColors.textSecondary),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 20),
              const Text('Device Preview',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Outfit')),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.card2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.blue.withOpacity(0.15),
                              blurRadius: 30)
                        ],
                      ),
                      child: const Icon(Icons.shield,
                          color: AppColors.blueLight, size: 44),
                    ),
                    const SizedBox(height: 12),
                    const Text('MODEL SELECTED',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blueLight,
                            letterSpacing: 1.5,
                            fontFamily: 'Outfit')),
                    const SizedBox(height: 4),
                    const Text('Guardian X-1',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFamily: 'Outfit')),
                  ],
                ),
              ),
              if (deviceFound) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.green.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: const [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.green,
                        child: Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Device Found',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.green,
                                  fontFamily: 'Outfit')),
                          Text('Ready to synchronize with your account.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Outfit')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: deviceFound ? '⚡  Activate Device' : 'Find Device',
                onTap: deviceFound ? onActivate : onCheck,
              ),
              if (deviceFound) ...[
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'By activating, you agree to the Device Safety Terms.',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFamily: 'Outfit'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Documents Sub-page ───────────────────────────────────────────────────────
class _DocumentsSubPage extends StatefulWidget {
  final VoidCallback onBack;
  const _DocumentsSubPage({required this.onBack});

  @override
  State<_DocumentsSubPage> createState() => _DocumentsSubPageState();
}

class _DocumentsSubPageState extends State<_DocumentsSubPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                child: Text('License & Documents',
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
            padding: const EdgeInsets.all(20),
            children: [
              InfoBanner(
                text: '',
                richSpans: [
                  const TextSpan(
                      text: 'Verification Required\n',
                      style: TextStyle(
                          color: AppColors.blueLight,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Outfit')),
                  const TextSpan(
                    text:
                        'Please provide clear photos of your official documents for account verification.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontFamily: 'Outfit'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Driver's License (image)
              _UploadSection(
                icon: Icons.badge_outlined,
                title: "Driver's License",
                uploadLabel: 'Upload License Image',
                uploadSub: 'Front and back of your card',
                fileType: _UploadFileType.image,
                prefKey: _kDocLicensePath,
              ),
              const SizedBox(height: 12),

              // National ID (image)
              _UploadSection(
                icon: Icons.person_outline,
                title: 'National ID Card',
                uploadLabel: 'Upload ID Card',
                uploadSub: 'High resolution PNG or JPG',
                fileType: _UploadFileType.image,
                prefKey: _kDocIdPath,
              ),
              const SizedBox(height: 20),

              // PDF documents
              Row(
                children: const [
                  Icon(Icons.description_outlined,
                      color: AppColors.blueLight, size: 18),
                  SizedBox(width: 8),
                  SectionLabel('Official Documents'),
                ],
              ),
              const SizedBox(height: 8),
              _UploadSection(
                icon: Icons.description_outlined,
                title: 'PDF Document',
                uploadLabel: 'Upload PDF File',
                uploadSub: 'Insurance, registration, etc.',
                fileType: _UploadFileType.pdf,
                prefKey: _kDocPdfPath,
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Submit for Verification'),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Upload section tile (StatefulWidget)
//
//  • fileType = image → opens gallery (PNG/JPG)
//  • fileType = pdf   → filters for .pdf only
//  • prefKey          → key used to persist path
//
//  Visual feedback:
//  • Icon turns green once a file is picked
//  • Bottom text shows the actual file name
// ─────────────────────────────────────────────
class _UploadSection extends StatefulWidget {
  final IconData icon;
  final String title, uploadLabel, uploadSub;
  final _UploadFileType fileType;
  final String prefKey;

  const _UploadSection({
    required this.icon,
    required this.title,
    required this.uploadLabel,
    required this.uploadSub,
    required this.fileType,
    required this.prefKey,
  });

  @override
  State<_UploadSection> createState() => _UploadSectionState();
}

class _UploadSectionState extends State<_UploadSection> {
  String? _pickedFileName;
  bool _isPicked = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPersistedPath();
  }

  Future<void> _loadPersistedPath() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(widget.prefKey);
    if (saved != null && saved.isNotEmpty) {
      if (mounted) {
        setState(() {
          _pickedFileName = saved.split('/').last;
          _isPicked = true;
        });
      }
    }
  }

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);
    try {
      FilePickerResult? result;

      if (widget.fileType == _UploadFileType.image) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: false,
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final path = file.path ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(widget.prefKey, path);

        setState(() {
          _pickedFileName = file.name;
          _isPicked = true;
        });
      }
    } catch (_) {
      // Silently ignore cancellations
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _isPicked ? AppColors.green : AppColors.blueLight;
    final iconBg = _isPicked
        ? AppColors.green.withOpacity(0.15)
        : AppColors.blue.withOpacity(0.15);
    final borderColor = _isPicked ? AppColors.green : AppColors.border;
    final bottomText =
        _isPicked ? (_pickedFileName ?? 'File selected') : 'Browse Files';
    final bottomStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: _isPicked ? AppColors.green : AppColors.blueLight,
      fontFamily: 'Outfit',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icon, color: AppColors.blueLight, size: 18),
            const SizedBox(width: 8),
            Text(widget.title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                    fontFamily: 'Outfit')),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isLoading ? null : _pickFile,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.card2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: AppColors.blueLight, strokeWidth: 2),
                    ),
                  )
                : Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: iconBg, shape: BoxShape.circle),
                        child: Icon(
                          _isPicked
                              ? Icons.check_circle_outline
                              : Icons.upload_outlined,
                          color: iconColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(widget.uploadLabel,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontFamily: 'Outfit')),
                      const SizedBox(height: 4),
                      Text(widget.uploadSub,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontFamily: 'Outfit')),
                      const SizedBox(height: 8),
                      Text(
                        bottomText,
                        style: bottomStyle,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
