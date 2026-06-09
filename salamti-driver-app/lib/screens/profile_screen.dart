import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

//  Public storage keys

const kVehicleId = 'vehicle_id';
const kVehicleMake = 'vehicle_make';
const kVehicleModel = 'vehicle_model';
const kVehicleColor = 'vehicle_color';
const kVehicleYear = 'vehicle_year';
const kVehiclePlate = 'vehicle_plate';
const kObuId = 'obu_id';
const kObuInstNumber = 'obu_inst_number';
const kObuSimNumber = 'obu_sim_number';

//  Underline-only InputDecoration helper
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

// PROFILE SCREEN
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _makerCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _instCtrl = TextEditingController();
  final _simCtrl = TextEditingController();
  String _year = '2026';

  final _years = List.generate(27, (i) => (2026 - i).toString());

  bool _isSaving = false;
  bool _isLoading = true;
  String? _vehicleId; // null = no vehicle yet

  bool get _canSave =>
      _makerCtrl.text.trim().isNotEmpty &&
      _modelCtrl.text.trim().isNotEmpty &&
      _colorCtrl.text.trim().isNotEmpty &&
      _plateCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _makerCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    _plateCtrl.dispose();
    _instCtrl.dispose();
    _simCtrl.dispose();
    super.dispose();
  }

  // Load locally then fetch vehicle from API if ID exists ──
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Step 1 — Load local data immediately, show UI instantly
    _year = prefs.getString(kVehicleYear) ?? '2026';
    _vehicleId = prefs.getString(kVehicleId);
    _instCtrl.text = prefs.getString(kObuInstNumber) ?? '';
    _simCtrl.text = prefs.getString(kObuSimNumber) ?? '';

    // Load local vehicle data
    _makerCtrl.text = prefs.getString(kVehicleMake) ?? '';
    _modelCtrl.text = prefs.getString(kVehicleModel) ?? '';
    _colorCtrl.text = prefs.getString(kVehicleColor) ?? '';
    _plateCtrl.text = prefs.getString(kVehiclePlate) ?? '';

    setState(() => _isLoading = false);

    // Step 2 — Fetch vehicle from API in background if ID exists
    if (_vehicleId != null) {
      try {
        final token = await AuthService.getAccessToken();
        final res = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/vehicles/$_vehicleId'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          final v =
              jsonDecode(res.body)['data']['vehicle'] as Map<String, dynamic>;
          final maker = v['maker'] as String? ?? '';
          final model = v['model'] as String? ?? '';
          final color = v['color'] as String? ?? '';
          final plate = v['licensePlate'] as String? ?? '';
          final year = (v['year'] as int?)?.toString() ?? '2026';

          // Update UI and cache with fresh data
          setState(() {
            _makerCtrl.text = maker;
            _modelCtrl.text = model;
            _colorCtrl.text = color;
            _plateCtrl.text = plate;
            _year = year;
          });

          // Update cache
          await Future.wait([
            prefs.setString(kVehicleMake, maker),
            prefs.setString(kVehicleModel, model),
            prefs.setString(kVehicleColor, color),
            prefs.setString(kVehicleYear, year),
            prefs.setString(kVehiclePlate, plate),
          ]);
        }
      } catch (e) {
        assert(() {
          debugPrint('Vehicle fetch error: $e');
          return true;
        }());
      }
    }
    // Fetch OBU from API in background using find-all, filtered by driverId
    try {
      final token = await AuthService.getAccessToken();
      final obuRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/obus'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (obuRes.statusCode == 200 || obuRes.statusCode == 201) {
        final obus = jsonDecode(obuRes.body)['data']['obus'] as List<dynamic>;
        final claimed = obus.firstWhere(
          (o) => o['driverId'] != null,
          orElse: () => null,
        );
        if (claimed != null) {
          final id = claimed['id'] as String;
          final inst = claimed['instNumber'] as String? ?? '';
          final sim = claimed['simCardNumber'] as String? ?? '';

          setState(() {
            _instCtrl.text = inst;
            _simCtrl.text = sim;
          });

          await Future.wait([
            prefs.setString(kObuId, id),
            prefs.setString(kObuInstNumber, inst),
            prefs.setString(kObuSimNumber, sim),
          ]);
        }
      }
    } catch (e) {
      assert(() {
        debugPrint('OBU fetch error: $e');
        return true;
      }());
    }
  }

  //  Save profile: vehicle → API, then cache locally. OBU claim if fields filled and not claimed yet.
  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();

    // Save vehicle to API
    try {
      final token = await AuthService.getAccessToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({
        'maker': _makerCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
        'color': _colorCtrl.text.trim(),
        'year': int.tryParse(_year) ?? 2026,
        'licensePlate': _plateCtrl.text.trim(),
      });

      http.Response res;
      if (_vehicleId == null) {
        // First time — POST
        res = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/vehicles'),
          headers: headers,
          body: body,
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          final v =
              jsonDecode(res.body)['data']['vehicle'] as Map<String, dynamic>;
          _vehicleId = v['id'] as String;
          await prefs.setString(kVehicleId, _vehicleId!);
        }
      } else {
        // Update — PATCH
        res = await http.patch(
          Uri.parse('${ApiConfig.baseUrl}/vehicles/$_vehicleId'),
          headers: headers,
          body: body,
        );
      }

      // Cache vehicle fields locally
      await Future.wait([
        prefs.setString(kVehicleMake, _makerCtrl.text.trim()),
        prefs.setString(kVehicleModel, _modelCtrl.text.trim()),
        prefs.setString(kVehicleColor, _colorCtrl.text.trim()),
        prefs.setString(kVehicleYear, _year),
        prefs.setString(kVehiclePlate, _plateCtrl.text.trim()),
      ]);
    } catch (vehicleError) {
      assert(() {
        debugPrint('Vehicle save error: $vehicleError');
        return true;
      }());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not save vehicle. Please try again.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
      setState(() => _isSaving = false);
      return;
    }

    // OBU claim, only if both fields are filled and not already claimed
    final inst = _instCtrl.text.trim();
    final sim = _simCtrl.text.trim();
    final existingObuId = prefs.getString(kObuId);
    String? newObuId;

    if (inst.isNotEmpty &&
        sim.isNotEmpty &&
        (existingObuId == null || existingObuId.isEmpty) &&
        _vehicleId != null) {
      try {
        final token = await AuthService.getAccessToken();
        final obuRes = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/obus/claim'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'instNumber': inst,
            'simCardNumber': sim,
          }),
        );

        if (obuRes.statusCode == 200 || obuRes.statusCode == 201) {
          final obu =
              jsonDecode(obuRes.body)['data']['obu'] as Map<String, dynamic>;
          newObuId = obu['id'] as String;
          await Future.wait([
            prefs.setString(kObuId, newObuId),
            prefs.setString(kObuInstNumber, inst),
            prefs.setString(kObuSimNumber, sim),
          ]);

          // Connect OBU to vehicle, the third endpoint, called in background after claiming
          if (_vehicleId != null && newObuId.isNotEmpty) {
            try {
              final connectRes = await http.patch(
                Uri.parse('${ApiConfig.baseUrl}/obus/$newObuId/connect'),
                headers: {
                  'Content-Type': 'application/json',
                  if (token != null) 'Authorization': 'Bearer $token',
                },
                body: jsonEncode({
                  'vehicleId': _vehicleId,
                }),
              );

              if (connectRes.statusCode != 200 &&
                  connectRes.statusCode != 201) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text(
                        'Connecting OBU and the car failed. Please try again.',
                        style: TextStyle(fontFamily: 'Outfit')),
                    backgroundColor: AppColors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ));
                }
                setState(() => _isSaving = false);
                return;
              }
            } catch (connectError) {
              assert(() {
                debugPrint('OBU connection error: $connectError');
                return true;
              }());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text(
                      'Connecting OBU and the car failed. Please try again.',
                      style: TextStyle(fontFamily: 'Outfit')),
                  backgroundColor: AppColors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
              }
              setState(() => _isSaving = false);
              return;
            }
          }
        } else {
          // ── Handle server rejecting the claim (e.g. 400 or 409) ──
          if (mounted) {
            String errorMsg = 'Failed to claim OBU device.';
            try {
              final responseData = jsonDecode(obuRes.body);
              if (responseData['message'] != null) {
                errorMsg = responseData['message'];
              }
            } catch (jsonError) {
              assert(() {
                debugPrint('OBU claim response parse error: $jsonError');
                return true;
              }());
            }

            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(errorMsg, style: const TextStyle(fontFamily: 'Outfit')),
              backgroundColor: AppColors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ));
          }
          setState(() => _isSaving = false);
          return;
        }
      } catch (networkError) {
        assert(() {
          debugPrint('OBU network error: $networkError');
          return true;
        }());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Network error saving OBU data.',
                style: TextStyle(fontFamily: 'Outfit')),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
        setState(() => _isSaving = false);
        return;
      }
    } else if (inst.isNotEmpty && sim.isNotEmpty) {
      // Already claimed — just update local cache
      await Future.wait([
        prefs.setString(kObuInstNumber, inst),
        prefs.setString(kObuSimNumber, sim),
      ]);
    } else if (inst.isNotEmpty &&
        sim.isNotEmpty &&
        (existingObuId == null || existingObuId.isEmpty) &&
        _vehicleId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Please save your car data before claiming an OBU device.',
              style: TextStyle(fontFamily: 'Outfit')),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
      setState(() => _isSaving = false);
      return;
    }

    // ── Final Success State ──
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Profile saved successfully',
                style: TextStyle(
                    fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: AppColors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blueLight),
      );
    }

    return Column(
      children: [
        // ── Top bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
          child: Row(
            children: const [
              Expanded(
                child: Text('Vehicles',
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
                          _makerCtrl.text.isEmpty
                              ? 'Your Vehicle'
                              : '${_makerCtrl.text} ${_modelCtrl.text}'.trim(),
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
                            label: 'MAKER',
                            controller: _makerCtrl,
                            hint: 'e.g. BMW',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _VehicleEditField(
                            label: 'MODEL',
                            controller: _modelCtrl,
                            hint: 'e.g. X5',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _VehicleEditField(
                            label: 'COLOR',
                            controller: _colorCtrl,
                            hint: 'e.g. Black',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                  menuMaxHeight: 300,
                                  //itemHeight: 40,
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
                      ],
                    ),
                    const SizedBox(height: 14),
                    _VehicleEditField(
                      label: 'LICENSE PLATE',
                      controller: _plateCtrl,
                      hint: 'e.g. EGY-9876',
                      blue: true,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InfoBanner(
                  text:
                      'Accurate vehicle information is critical. Emergency responders use this data to identify your car in high-stress scenarios.'),
              const SizedBox(height: 24),

              // ── OBU Device ──
              const SectionLabel('OBU Device'),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  children: [
                    _EditableInfoRow(
                      icon: Icons.router_outlined,
                      label: 'Instance Number',
                      controller: _instCtrl,
                      hint: 'INST-2026-000123',
                      onChanged: (_) => setState(() {}),
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    _EditableInfoRow(
                      icon: Icons.sim_card_outlined,
                      label: 'SIM Card Number',
                      controller: _simCtrl,
                      hint: '+201234567890',
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              InfoBanner(
                text: '',
                richSpans: [
                  const TextSpan(
                    text: 'Note: ',
                    style: TextStyle(
                        color: AppColors.blueLight,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Outfit'),
                  ),
                  const TextSpan(
                    text:
                        'OBU device can only be claimed once. Leave empty if already connected.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontFamily: 'Outfit'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

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
                        : const Text(' Save ',
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

//  Editable info row (OBU fields)
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
                color: AppColors.textMuted, fontFamily: 'Outfit', fontSize: 13),
          ),
        ),
      ],
    );
  }
}
