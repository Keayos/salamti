import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/api_config.dart';

// ─────────────────────────────────────────────
//  Storage keys
// ─────────────────────────────────────────────
const _kBloodType = 'health_blood_type';
const _kConditions = 'health_conditions';
const _kMeds = 'health_meds';
const _kAllergies = 'health_allergies';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  String _bloodType = '';
  final _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  List<Map<String, String>> _conditions = [];
  List<Map<String, String>> _meds = [];
  List<Map<String, String>> _allergies = [];

  // ── Lifecycle ──────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bloodType = prefs.getString(_kBloodType) ?? '';

      final rawCond = prefs.getString(_kConditions);
      if (rawCond != null) {
        _conditions = (jsonDecode(rawCond) as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
      }

      final rawMeds = prefs.getString(_kMeds);
      if (rawMeds != null) {
        _meds = (jsonDecode(rawMeds) as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
      }

      final rawAllerg = prefs.getString(_kAllergies);
      if (rawAllerg != null) {
        _allergies = (jsonDecode(rawAllerg) as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
      }
    });
  }

  // Fire-and-forget auto-save — called silently after every mutation
  // Blood type map — UI label → API value
  static const _btMap = {
    'A+': 'A_PLUS',
    'A-': 'A_MINUS',
    'B+': 'B_PLUS',
    'B-': 'B_MINUS',
    'AB+': 'AB_PLUS',
    'AB-': 'AB_MINUS',
    'O+': 'O_PLUS',
    'O-': 'O_MINUS',
  };

  Future<void> _autoSave() async {
    // ── 1. Save everything locally ─────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBloodType, _bloodType);
    await prefs.setString(_kConditions, jsonEncode(_conditions));
    await prefs.setString(_kMeds, jsonEncode(_meds));
    await prefs.setString(_kAllergies, jsonEncode(_allergies));

    // ── 2. Send to API (meds are local only) ───────────────────
    final userId = await AuthService.getUserId();
    final token = await AuthService.getAccessToken();
    if (userId == null || token == null) return;

    try {
      await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/drivers/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (_bloodType.isNotEmpty)
            'bloodType': _btMap[_bloodType] ?? _bloodType,
          'medicalConditions': {
            'Chronic Conditions': _conditions
                .map((c) => {'name': c['name'], 'case': c['note'] ?? ''})
                .toList(),
            'Critical Allergies':
                _allergies.map((a) => a['name'] ?? '').toList(),
          },
        }),
      );
    } catch (e) {
      assert(() {
        debugPrint('Health auto-save API error: $e');
        return true;
      }());
    }
  }

  // ── Mutating helpers ───────────────────────
  void _setBloodType(String bt) {
    setState(() => _bloodType = bt);
    _autoSave();
  }

  void _addCondition(String name, String note) {
    setState(() => _conditions.add({'name': name, 'note': note}));
    _autoSave();
  }

  void _deleteCondition(int index) {
    setState(() => _conditions.removeAt(index));
    _autoSave();
  }

  void _addMedication(String name, String note) {
    setState(() => _meds.add({'name': name, 'note': note}));
    _autoSave();
  }

  void _deleteMed(int index) {
    setState(() => _meds.removeAt(index));
    _autoSave();
  }

  void _addAllergy(String name, String note) {
    setState(() => _allergies.add({'name': name, 'note': note}));
    _autoSave();
  }

  void _deleteAllergy(int index) {
    setState(() => _allergies.removeAt(index));
    _autoSave();
  }

  // ── Add dialog ─────────────────────────────
  void _showAddDialog({
    required String title,
    required String namePlaceholder,
    required String notePlaceholder,
    required void Function(String name, String note) onAdd,
  }) {
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'Outfit'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogField(controller: nameCtrl, hint: namePlaceholder),
            const SizedBox(height: 10),
            _DialogField(controller: noteCtrl, hint: notePlaceholder),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(
                    color: AppColors.textMuted, fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final note = noteCtrl.text.trim();
              if (name.isNotEmpty) {
                onAdd(name, note);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add',
                style: TextStyle(
                    color: AppColors.blueLight,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit')),
          ),
        ],
      ),
    );
  }

  // ── Add condition dialog — dropdown + optional custom name ──
  void _showAddConditionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddConditionDialog(
        onAdd: (name, note) {
          _addCondition(name, note);
        },
      ),
    );
  }

  // ── Add allergy dialog — dropdown + optional custom name ──
  void _showAddAllergyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddAllergyDialog(
        onAdd: (name, note) {
          _addAllergy(name, note);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Top bar (no Save button) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
          child: Row(
            children: const [
              Expanded(
                child: Text(
                  'Medical History',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Outfit'),
                ),
              ),
            ],
          ),
        ),

        // ── Scrollable body ──
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Important banner
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.blueLight, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                              fontSize: 13, height: 1.5, fontFamily: 'Outfit'),
                          children: [
                            TextSpan(
                              text: 'IMPORTANT: ',
                              style: TextStyle(
                                  color: AppColors.blueLight,
                                  fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                              text:
                                  'This info is shared with paramedics and emergency services automatically during detected collisions.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Blood Type ──
              AppCard(
                child: Column(
                  children: [
                    const SectionLabel('Blood Type'),
                    const Text('🩸', style: TextStyle(fontSize: 30)),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.8,
                      children: _bloodTypes.map((bt) {
                        final sel = bt == _bloodType;
                        return GestureDetector(
                          onTap: () => _setBloodType(bt),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.blue : AppColors.card2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      sel ? AppColors.blue : AppColors.border),
                            ),
                            child: Center(
                              child: Text(
                                bt,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: sel
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontFamily: 'Outfit'),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // ── Chronic Conditions ──
              _MedSection(
                icon: '🦠',
                title: 'Chronic Conditions',
                items: _conditions,
                onAdd: _showAddConditionDialog,
                onDelete: _deleteCondition,
              ),

              // ── Current Medications ──
              _MedSection(
                icon: '💊',
                title: 'Current Medications',
                items: _meds,
                onAdd: () => _showAddDialog(
                  title: 'Add Medication',
                  namePlaceholder: 'Medication name',
                  notePlaceholder:
                      'Dosage & frequency (e.g. 10mg • Once Daily)',
                  onAdd: _addMedication,
                ),
                onDelete: _deleteMed,
                iconColor: AppColors.blueLight,
              ),

              // ── Allergies ──
              _MedSection(
                icon: '⚠️',
                title: 'Allergies & Reactions',
                items: _allergies,
                onAdd: _showAddAllergyDialog,
                onDelete: _deleteAllergy,
                iconColor: AppColors.red,
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.textMuted),
                  Icon(Icons.lock_outline,
                      size: 14, color: AppColors.textMuted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Data is encrypted and only transmitted to emergency services via the Hardware Link during a confirmed accident.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'Outfit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Reusable dialog text field
// ─────────────────────────────────────────────
class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _DialogField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(
          color: AppColors.textPrimary, fontFamily: 'Outfit', fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: AppColors.textMuted, fontFamily: 'Outfit', fontSize: 13),
        filled: true,
        fillColor: AppColors.card2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.blueLight),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Generic editable section (conditions / meds / allergies)
// ─────────────────────────────────────────────
class _MedSection extends StatelessWidget {
  final String icon, title;
  final List<Map<String, String>> items;
  final Color iconColor;
  final VoidCallback onAdd;
  final void Function(int index) onDelete;

  const _MedSection({
    required this.icon,
    required this.title,
    required this.items,
    required this.onAdd,
    required this.onDelete,
    this.iconColor = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'Outfit')),
              ],
            ),
            GestureDetector(
              onTap: onAdd,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text('+',
                    style: TextStyle(
                        fontSize: 24,
                        color: AppColors.blueLight,
                        fontWeight: FontWeight.w300)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return Dismissible(
            key: ValueKey('${title}_${item['name']}_$index'),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.centerRight,
              child: const Icon(Icons.delete_outline,
                  color: AppColors.red, size: 20),
            ),
            confirmDismiss: (_) async =>
                await _confirmDelete(context, item['name'] ?? ''),
            onDismissed: (_) => onDelete(index),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.card2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['name']!,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                fontFamily: 'Outfit')),
                        if ((item['note'] ?? '').isNotEmpty)
                          Text(item['note']!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontFamily: 'Outfit')),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      if (await _confirmDelete(context, item['name'] ?? '')) {
                        onDelete(index);
                      }
                    },
                    child: const Icon(Icons.delete_outline,
                        color: AppColors.red, size: 16),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.card2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text('Remove item?',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Outfit')),
            content: Text('Are you sure you want to remove "$name"?',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontFamily: 'Outfit')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: AppColors.textMuted, fontFamily: 'Outfit')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove',
                    style: TextStyle(
                        color: AppColors.red,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Outfit')),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ─────────────────────────────────────────────
//  Add Condition Dialog
//  Shows a dropdown of preset conditions.
//  If "Other" is selected, reveals a text field.
// ─────────────────────────────────────────────
class _AddConditionDialog extends StatefulWidget {
  final void Function(String name, String note) onAdd;
  const _AddConditionDialog({required this.onAdd});

  @override
  State<_AddConditionDialog> createState() => _AddConditionDialogState();
}

class _AddConditionDialogState extends State<_AddConditionDialog> {
  static const _presetConditions = [
    'Hypertension',
    'Diabetes',
    'Asthma',
    'Obesity',
    'COPD',
    'Kidney Disease',
    'Osteoporosis',
    'Arthritis',
    'Other',
  ];

  String? _selected;
  final _customNameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool get _isOther => _selected == 'Other';

  @override
  void dispose() {
    _customNameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Add Chronic Condition',
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'Outfit'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Condition dropdown ──
            const Text('CONDITION',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.8,
                    fontFamily: 'Outfit')),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButton<String>(
                value: _selected,
                isExpanded: true,
                dropdownColor: AppColors.card,
                underline: const SizedBox(),
                hint: const Text('Select a condition',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontFamily: 'Outfit',
                        fontSize: 14)),
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Outfit',
                    fontSize: 14),
                items: _presetConditions
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selected = v),
              ),
            ),

            // ── Custom name field — only shown when "Other" is selected ──
            if (_isOther) ...[
              const SizedBox(height: 12),
              const Text('CONDITION NAME',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.8,
                      fontFamily: 'Outfit')),
              const SizedBox(height: 6),
              _DialogField(
                  controller: _customNameCtrl, hint: 'Enter condition name'),
            ],

            // ── Notes field ──
            const SizedBox(height: 12),
            const Text('NOTES',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.8,
                    fontFamily: 'Outfit')),
            const SizedBox(height: 6),
            _DialogField(
                controller: _noteCtrl, hint: 'Notes (e.g. Diagnosed 2020)'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style:
                  TextStyle(color: AppColors.textMuted, fontFamily: 'Outfit')),
        ),
        TextButton(
          onPressed: () {
            // Determine final name
            final name =
                _isOther ? _customNameCtrl.text.trim() : (_selected ?? '');

            if (name.isEmpty) return; // don't add if nothing chosen/typed

            widget.onAdd(name, _noteCtrl.text.trim());
            Navigator.pop(context);
          },
          child: const Text('Add',
              style: TextStyle(
                  color: AppColors.blueLight,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Outfit')),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Add Allergy Dialog
//  Shows a dropdown of preset allergies.
//  If "Other" is selected, reveals a text field.
// ─────────────────────────────────────────────
class _AddAllergyDialog extends StatefulWidget {
  final void Function(String name, String note) onAdd;
  const _AddAllergyDialog({required this.onAdd});

  @override
  State<_AddAllergyDialog> createState() => _AddAllergyDialogState();
}

class _AddAllergyDialogState extends State<_AddAllergyDialog> {
  static const _presetAllergies = [
    'Peanuts',
    'Fish',
    'Lactose Intolerance',
    'Penicillin',
    'Sulfa Drugs',
    'Aspirin',
    'Ibuprofen',
    'Carbamazepine',
    'Phenytoin',
    'Other',
  ];

  String? _selected;
  final _customNameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool get _isOther => _selected == 'Other';

  @override
  void dispose() {
    _customNameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Add Allergy & Reaction',
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'Outfit'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Allergy dropdown ──
            const Text('ALLERGY',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.8,
                    fontFamily: 'Outfit')),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButton<String>(
                value: _selected,
                isExpanded: true,
                dropdownColor: AppColors.card,
                underline: const SizedBox(),
                hint: const Text('Select an allergy',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontFamily: 'Outfit',
                        fontSize: 14)),
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Outfit',
                    fontSize: 14),
                items: _presetAllergies
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (v) => setState(() => _selected = v),
              ),
            ),

            // ── Custom name field — only shown when "Other" is selected ──
            if (_isOther) ...[
              const SizedBox(height: 12),
              const Text('ALLERGY NAME',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.8,
                      fontFamily: 'Outfit')),
              const SizedBox(height: 6),
              _DialogField(
                  controller: _customNameCtrl, hint: 'Enter allergy name'),
            ],

            // ── Notes field ──
            const SizedBox(height: 12),
            const Text('SYMPTOMS & EFFECTS',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.8,
                    fontFamily: 'Outfit')),
            const SizedBox(height: 6),
            _DialogField(
                controller: _noteCtrl,
                hint: 'Symptoms & effects (e.g. Fever, Rash)'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style:
                  TextStyle(color: AppColors.textMuted, fontFamily: 'Outfit')),
        ),
        TextButton(
          onPressed: () {
            final name =
                _isOther ? _customNameCtrl.text.trim() : (_selected ?? '');

            if (name.isEmpty) return;

            widget.onAdd(name, _noteCtrl.text.trim());
            Navigator.pop(context);
          },
          child: const Text('Add',
              style: TextStyle(
                  color: AppColors.blueLight,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Outfit')),
        ),
      ],
    );
  }
}
