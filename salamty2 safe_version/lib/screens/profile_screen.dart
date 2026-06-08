import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

// ─────────────────────────────────────────────
//  Public storage keys — also imported by
//  settings_screen.dart via:
//  import 'profile_screen.dart' show kProfileName, ...
// ─────────────────────────────────────────────
const kProfileName  = 'profile_name';
const kProfilePhone = 'profile_phone';
const kVehicleMake  = 'vehicle_make';
const kVehicleColor = 'vehicle_color';
const kVehicleYear  = 'vehicle_year';
const kVehiclePlate = 'vehicle_plate';

// ─────────────────────────────────────────────
//  Underline-only InputDecoration helper
//  Idle  → AppColors.border  (1.0 px)
//  Focus → AppColors.blueLight (1.5 px)
// ─────────────────────────────────────────────
InputDecoration _underlineDeco({
  required String hint,
  TextStyle? hintStyle,
}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: hintStyle ??
          const TextStyle(
              color: AppColors.textMuted, fontFamily: 'Outfit', fontSize: 14),
      filled: false,
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.border, width: 1.0),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.border, width: 1.0),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.blueLight, width: 1.5),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.only(bottom: 6),
    );

// ═══════════════════════════════════════════════════════════════════════════════
// PROFILE SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _makeCtrl  = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  String _year = '2026';

  final _years = List.generate(15, (i) => (2026 - i).toString());

  bool _isSaving = false;

  // All fields must be non-empty for Save to be enabled
  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().isNotEmpty &&
      _makeCtrl.text.trim().isNotEmpty &&
      _colorCtrl.text.trim().isNotEmpty &&
      _plateCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _makeCtrl.dispose();
    _colorCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text  = prefs.getString(kProfileName)  ?? '';
      _phoneCtrl.text = prefs.getString(kProfilePhone) ?? '';
      _makeCtrl.text  = prefs.getString(kVehicleMake)  ?? '';
      _colorCtrl.text = prefs.getString(kVehicleColor) ?? '';
      _plateCtrl.text = prefs.getString(kVehiclePlate) ?? '';
      _year           = prefs.getString(kVehicleYear)  ?? '2026';
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);

    // ── 1. Save locally ────────────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(kProfileName,  _nameCtrl.text.trim()),
      prefs.setString(kProfilePhone, _phoneCtrl.text.trim()),
      prefs.setString(kVehicleMake,  _makeCtrl.text.trim()),
      prefs.setString(kVehicleColor, _colorCtrl.text.trim()),
      prefs.setString(kVehicleYear,  _year),
      prefs.setString(kVehiclePlate, _plateCtrl.text.trim()),
    ]);

    // ── 2. Send to server ──────────────────────────────────────
    await ApiService.saveProfile({
      'name':  _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
    });
    await ApiService.saveVehicle({
      'make':  _makeCtrl.text.trim(),
      'color': _colorCtrl.text.trim(),
      'year':  _year,
      'plate': _plateCtrl.text.trim(),
    });

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Profile saved',
                  style: TextStyle(
                      fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: AppColors.blue,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String get _initials {
    final parts = _nameCtrl.text.trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Top bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
          child: Row(
            children: const [
              Icon(Icons.arrow_back_ios,
                  color: AppColors.blueLight, size: 20),
              Expanded(
                child: Text('Profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'Outfit')),
              ),
              SizedBox(width: 28),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── Avatar ──
              Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.blue, Color(0xFF0EA5E9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.blue, width: 3),
                        ),
                        child: Center(
                          child: Text(_initials,
                              style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  fontFamily: 'Outfit')),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.bg, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _nameCtrl.text.isEmpty ? 'Your Name' : _nameCtrl.text,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFamily: 'Outfit'),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.green.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check,
                                color: AppColors.green, size: 12),
                            SizedBox(width: 4),
                            Text('Verified Driver',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.green,
                                    fontFamily: 'Outfit')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('SafeID: 882-01',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              fontFamily: 'Outfit')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Personal Information ──
              const SectionLabel('Personal Information'),
              AppCard(
                child: Column(
                  children: [
                    _EditableInfoRow(
                      icon: Icons.person_outline,
                      label: 'Full Name',
                      controller: _nameCtrl,
                      hint: 'Enter your full name',
                      onChanged: (_) => setState(() {}),
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    _EditableInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Mobile Number',
                      controller: _phoneCtrl,
                      hint: '+201 000 000 000',
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // ── Vehicle ──
              const SectionLabel('My Registered Vehicle'),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Connected via OBD-|| Hardware',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontFamily: 'Outfit')),
                        const SizedBox(height: 4),
                        Text(
                          _makeCtrl.text.isEmpty
                              ? 'Your Vehicle'
                              : _makeCtrl.text,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontFamily: 'Outfit'),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Text('🚗',
                            style: TextStyle(
                                fontSize: 40,
                                color: Colors.white.withOpacity(0.35))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              AppCard(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _VehicleEditField(
                            label: 'MAKE & MODEL',
                            controller: _makeCtrl,
                            hint: 'e.g. BMW M4',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _VehicleEditField(
                            label: 'COLOR',
                            controller: _colorCtrl,
                            hint: 'e.g. Silver',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('YEAR',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                      letterSpacing: 0.8,
                                      fontFamily: 'Outfit')),
                              const SizedBox(height: 6),
                              Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                        color: AppColors.border, width: 1.0),
                                  ),
                                ),
                                child: DropdownButton<String>(
                                  value: _year,
                                  isExpanded: true,
                                  dropdownColor: AppColors.card2,
                                  underline: const SizedBox(),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      fontFamily: 'Outfit'),
                                  items: _years
                                      .map((y) => DropdownMenuItem(
                                          value: y, child: Text(y)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _year = v);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _VehicleEditField(
                            label: 'LICENSE PLATE',
                            controller: _plateCtrl,
                            hint: 'e.g. B-MC 442',
                            blue: true,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InfoBanner(
                  text:
                      'Accurate vehicle information is critical. Emergency responders use this data to identify your car in high-stress scenarios.'),
              const SizedBox(height: 24),

              // ── Validation hint ──
              if (!_canSave)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.info_outline,
                          size: 14, color: AppColors.textMuted),
                      SizedBox(width: 6),
                      Text('Please fill in all fields to save',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontFamily: 'Outfit')),
                    ],
                  ),
                ),

              // ── Save button ──
              GestureDetector(
                onTap: _canSave && !_isSaving ? _save : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: _canSave
                        ? AppColors.blue
                        : AppColors.blue.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('💾  Save Profile',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'Outfit')),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Editable info row (name / phone)
// ─────────────────────────────────────────────
class _EditableInfoRow extends StatelessWidget {
  final IconData icon;
  final String label, hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _EditableInfoRow({
    required this.icon,
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                        fontFamily: 'Outfit')),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFamily: 'Outfit'),
                  decoration: _underlineDeco(hint: hint),
                ),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined,
              color: AppColors.textSecondary, size: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Editable vehicle field
// ─────────────────────────────────────────────
class _VehicleEditField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final bool blue;
  final ValueChanged<String>? onChanged;

  const _VehicleEditField({
    required this.label,
    required this.controller,
    required this.hint,
    this.blue = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.8,
                fontFamily: 'Outfit')),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: blue ? AppColors.blueLight : AppColors.textPrimary,
              fontFamily: 'Outfit'),
          decoration: _underlineDeco(
            hint: hint,
            hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Outfit',
                fontSize: 13),
          ),
        ),
      ],
    );
  }
}
