import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
//  Relationship options — API values
// ─────────────────────────────────────────────
const _kRelationships = [
  'FAMILY',
  'FRIEND',
  'COLLEAGUE',
  'NEIGHBOR',
  'PARTNER',
  'OTHER',
];
const _kContactsCache = 'contacts_cache';

// ─────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────
class _Contact {
  final String id;
  String fullName, email, phone, relationship;
  bool autoNotify, instantSms, voiceCall;

  _Contact({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.relationship,
    this.autoNotify = true,
    this.instantSms = false,
    this.voiceCall = false,
  });

  String get initials {
    final parts =
        fullName.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory _Contact.fromJson(Map<String, dynamic> json) => _Contact(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        relationship: json['relationship'] as String,
        autoNotify: json['autoNotify'] as bool? ?? true,
        instantSms: json['instantSms'] as bool? ?? false,
        voiceCall: json['voiceCall'] as bool? ?? false,
      );
}

// ═════════════════════════════════════════════════════════════════════════════
//  ContactsScreen
// ═════════════════════════════════════════════════════════════════════════════
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  bool _showAdd = false;

  final List<_Contact> _contacts = [];
  bool _isLoading = false;
  String? _error;

  // Add-form controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedRel = '';
  bool _autoNotify = true;
  bool _instantSms = false;
  bool _voiceCall = false;
  _Contact? _editingContact;

  // ── Lifecycle ──────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Auth header ────────────────────────────
  Future<Map<String, String>> get _headers async {
    final token = await AuthService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Save contacts to local cache ───────────
  Future<void> _saveLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kContactsCache,
      jsonEncode(_contacts
          .map((c) => {
                'id': c.id,
                'fullName': c.fullName,
                'email': c.email,
                'phone': c.phone,
                'relationship': c.relationship,
                'autoNotify': c.autoNotify,
                'instantSms': c.instantSms,
                'voiceCall': c.voiceCall,
              })
          .toList()),
    );
  }

  // ── GET /emergency-contacts ────────────────
  Future<void> _loadContacts() async {
    // Step 1 — load local cache immediately (no spinner)
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kContactsCache);
    if (cached != null) {
      final list = jsonDecode(cached) as List<dynamic>;
      setState(() {
        _contacts
          ..clear()
          ..addAll(
              list.map((e) => _Contact.fromJson(e as Map<String, dynamic>)));
      });
    }

    // Step 2 — fetch from API and update
    // Only show spinner if cache was empty
    setState(() {
      _isLoading = cached == null;
      _error = null;
    });
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/emergency-contacts'),
        headers: await _headers,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body)['data'] as Map<String, dynamic>;
        final raw = data['contacts'] as List<dynamic>;
        setState(() {
          _contacts
            ..clear()
            ..addAll(
                raw.map((e) => _Contact.fromJson(e as Map<String, dynamic>)));
        });
        await _saveLocally();
      } else {
        // API failed — keep showing cached data, show error only if cache was empty
        if (cached == null) setState(() => _error = 'Failed to load contacts.');
      }
    } catch (e) {
      assert(() {
        debugPrint('Contacts load error: $e');
        return true;
      }());
      if (cached == null) {
        setState(() => _error = 'Network error. Please try again.');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── POST /emergency-contacts ───────────────
  Future<void> _saveContact() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _selectedRel.isEmpty) return;

    final phone = _formatPhone(_phoneCtrl.text.trim());

    if (_editingContact != null) {
      try {
        final res = await http.patch(
          Uri.parse(
              '${ApiConfig.baseUrl}/emergency-contacts/${_editingContact!.id}'),
          headers: await _headers,
          body: jsonEncode({
            'fullName': _nameCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'phone': phone,
            'relationship': _selectedRel,
            'autoNotify': _autoNotify,
            'instantSms': _instantSms,
            'voiceCall': _voiceCall,
          }),
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body)['data'] as Map<String, dynamic>;
          final updated =
              _Contact.fromJson(data['contact'] as Map<String, dynamic>);
          setState(() {
            final index = _contacts.indexWhere((c) => c.id == updated.id);
            if (index != -1) _contacts[index] = updated;

            _resetForm();
          });
          await _saveLocally();
        } else {
          _showSnack('Failed to update contact. Please try again.');
        }
      } catch (e) {
        assert(() {
          debugPrint('Contact update error: $e');
          return true;
        }());
        _showSnack('Network error. Please try again.');
      }
    } else {
      try {
        final res = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/emergency-contacts'),
          headers: await _headers,
          body: jsonEncode({
            'fullName': _nameCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'phone': phone,
            'relationship': _selectedRel,
            'autoNotify': _autoNotify,
            'instantSms': _instantSms,
            'voiceCall': _voiceCall,
          }),
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body)['data'] as Map<String, dynamic>;
          final contact =
              _Contact.fromJson(data['contact'] as Map<String, dynamic>);
          setState(() {
            _contacts.add(contact);
            _resetForm();
          });
          await _saveLocally();
        } else {
          _showSnack('Failed to add contact. Please try again.');
        }
      } catch (e) {
        assert(() {
          debugPrint('Contact save error: $e');
          return true;
        }());
        _showSnack('Network error. Please try again.');
      }
    }
  }

  void _resetForm() {
    _nameCtrl.clear();
    _emailCtrl.clear();
    _phoneCtrl.clear();
    _selectedRel = '';
    _autoNotify = true;
    _instantSms = false;
    _voiceCall = false;
    _editingContact = null;
    _showAdd = false;
  }

  String _formatPhone(String phone) {
    if (phone.startsWith('+2')) return phone;
    if (phone.startsWith('0')) return '+2$phone';
    return '+2$phone';
  }

  void _openEdit(_Contact contact) {
    setState(() {
      _editingContact = contact;
      _nameCtrl.text = contact.fullName;
      _emailCtrl.text = contact.email;
      _phoneCtrl.text = contact.phone;
      _selectedRel = contact.relationship;
      _autoNotify = contact.autoNotify;
      _instantSms = contact.instantSms;
      _voiceCall = contact.voiceCall;
      _showAdd = true;
    });
  }

  // ── PATCH /emergency-contacts/:id ─────────
  Future<void> _updateContact(_Contact contact) async {
    try {
      await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/emergency-contacts/${contact.id}'),
        headers: await _headers,
        body: jsonEncode({
          'relationship': contact.relationship,
          'autoNotify': contact.autoNotify,
          'instantSms': contact.instantSms,
          'voiceCall': contact.voiceCall,
        }),
      );
    } catch (e) {
      assert(() {
        debugPrint('Contact update error: $e');
        return true;
      }());
      _showSnack('Failed to update contact.');
    }
  }

  // ── DELETE /emergency-contacts/:id ────────
  Future<void> _confirmDelete(_Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Remove contact?',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Outfit')),
        content: Text(
          'Are you sure you want to remove "${contact.fullName}" from your emergency contacts?',
          style: const TextStyle(
              fontSize: 13, color: AppColors.textMuted, fontFamily: 'Outfit'),
        ),
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
    );

    if (confirmed != true) return;

    try {
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/emergency-contacts/${contact.id}'),
        headers: await _headers,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() => _contacts.removeWhere((c) => c.id == contact.id));
        await _saveLocally();
      } else {
        _showSnack('Failed to delete contact.');
      }
    } catch (e) {
      assert(() {
        debugPrint('Contact delete error: $e');
        return true;
      }());
      _showSnack('Network error. Please try again.');
    }
  }

  // ── Toggle autoNotify ──────────────────────
  Future<void> _toggleNotify(_Contact contact) async {
    setState(() => contact.autoNotify = !contact.autoNotify);
    await _saveLocally();
    _updateContact(contact);
  }

  // ── Snack helper ───────────────────────────
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Outfit')),
      backgroundColor: AppColors.card2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_showAdd) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _resetForm());
        },
        child: _AddContactView(
          nameCtrl: _nameCtrl,
          emailCtrl: _emailCtrl,
          phoneCtrl: _phoneCtrl,
          selectedRel: _selectedRel,
          autoNotify: _autoNotify,
          instantSms: _instantSms,
          voiceCall: _voiceCall,
          onRelChange: (v) => setState(() => _selectedRel = v),
          onAutoNotifyChange: (v) => setState(() => _autoNotify = v),
          onInstantSmsChange: (v) => setState(() => _instantSms = v),
          onVoiceCallChange: (v) => setState(() => _voiceCall = v),
          onSave: _saveContact,
          onBack: () => setState(() => _resetForm()),
        ),
      );
    }

    return Column(
      children: [
        // ── Top bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Row(
            children: const [
              Expanded(
                child: Text(
                  'Emergency contacts',
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

        // ── Body ──
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.blueLight))
              : _error != null && _contacts.isEmpty
                  ? _ErrorView(message: _error!, onRetry: _loadContacts)
                  : RefreshIndicator(
                      color: AppColors.blueLight,
                      backgroundColor: AppColors.card,
                      onRefresh: _loadContacts,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        children: [
                          PrimaryButton(
                            label: '+ Add New Contact',
                            onTap: () => setState(() => _showAdd = true),
                          ),
                          const SizedBox(height: 14),
                          InfoBanner(
                            text: '',
                            richSpans: [
                              TextSpan(
                                text: 'Contacts with ',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Outfit'),
                              ),
                              const TextSpan(
                                text: 'Auto-notify',
                                style: TextStyle(
                                    color: AppColors.blueLight,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Outfit'),
                              ),
                              TextSpan(
                                text:
                                    ' enabled will receive your location and crash details immediately if an accident is detected.',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Outfit'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Contact cards
                          ..._contacts.map(
                            (c) => Dismissible(
                              key: ValueKey(c.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.centerRight,
                                child: const Icon(Icons.delete_outline,
                                    color: AppColors.red, size: 22),
                              ),
                              confirmDismiss: (_) async {
                                return await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: AppColors.card2,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                        title: const Text('Remove contact?',
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                                fontFamily: 'Outfit')),
                                        content: Text(
                                          'Are you sure you want to remove "${c.fullName}"?',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textMuted,
                                              fontFamily: 'Outfit'),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel',
                                                style: TextStyle(
                                                    color: AppColors.textMuted,
                                                    fontFamily: 'Outfit')),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
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
                              },
                              onDismissed: (_) async {
                                final res = await http.delete(
                                  Uri.parse(
                                      '${ApiConfig.baseUrl}/emergency-contacts/${c.id}'),
                                  headers: await _headers,
                                );
                                if (res.statusCode == 200 ||
                                    res.statusCode == 201) {
                                  setState(() => _contacts
                                      .removeWhere((x) => x.id == c.id));
                                  _saveLocally();
                                } else {
                                  _showSnack('Failed to delete contact.');
                                  _loadContacts();
                                }
                              },
                              child: _ContactCard(
                                contact: c,
                                onToggle: () => _toggleNotify(c),
                                onDelete: () => _confirmDelete(c),
                                onEdit: () => _openEdit(c),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          Column(
                            children: const [
                              Icon(Icons.sensors,
                                  color: AppColors.textMuted, size: 24),
                              SizedBox(height: 6),
                              Text(
                                'Your hardware accident detector is currently\nconnected and active.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                    fontFamily: 'Outfit'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Contact Card
// ─────────────────────────────────────────────
class _ContactCard extends StatelessWidget {
  final _Contact contact;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ContactCard({
    required this.contact,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AvatarCircle(initials: contact.initials, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact.fullName,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFamily: 'Outfit')),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (contact.relationship.isNotEmpty) ...[
                          RelBadge(contact.relationship),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            contact.phone,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontFamily: 'Outfit'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          color: AppColors.blueLight, size: 17),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: AppColors.red, size: 17),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Auto-notify on accident',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFamily: 'Outfit')),
                  Text('Instant SMS and voice call',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'Outfit')),
                ],
              ),
              Switch(
                value: contact.autoNotify,
                onChanged: (_) => onToggle(),
                activeColor: Colors.white,
                activeTrackColor: AppColors.blue,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: AppColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Add Contact View
// ─────────────────────────────────────────────
class _AddContactView extends StatelessWidget {
  final TextEditingController nameCtrl, emailCtrl, phoneCtrl;
  final String selectedRel;
  final bool autoNotify, instantSms, voiceCall;
  final ValueChanged<String> onRelChange;
  final ValueChanged<bool> onAutoNotifyChange;
  final ValueChanged<bool> onInstantSmsChange;
  final ValueChanged<bool> onVoiceCallChange;
  final VoidCallback onSave, onBack;

  const _AddContactView({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.selectedRel,
    required this.autoNotify,
    required this.instantSms,
    required this.voiceCall,
    required this.onRelChange,
    required this.onAutoNotifyChange,
    required this.onInstantSmsChange,
    required this.onVoiceCallChange,
    required this.onSave,
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
                child: Text(
                  'Add Emergency Contact',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Outfit'),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(
                child: Column(
                  children: [
                    LabeledInput(
                        label: 'Full Name',
                        hint: 'John Doe',
                        controller: nameCtrl),
                    LabeledInput(
                        label: 'Email Address',
                        hint: 'john@example.com',
                        prefixIcon: Icons.mail_outline,
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress),
                    LabeledInput(
                        label: 'Phone Number',
                        hint: '+201 000 000 000',
                        prefixIcon: Icons.phone_outlined,
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone),
                    // Relationship dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('RELATIONSHIP',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 1.2,
                                fontFamily: 'Outfit')),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.card2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButton<String>(
                            value: selectedRel.isEmpty ? null : selectedRel,
                            hint: const Text('Select Relationship',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontFamily: 'Outfit')),
                            isExpanded: true,
                            dropdownColor: AppColors.card2,
                            underline: const SizedBox(),
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontFamily: 'Outfit'),
                            items: _kRelationships
                                .map((r) =>
                                    DropdownMenuItem(value: r, child: Text(r)))
                                .toList(),
                            onChanged: (v) => v != null ? onRelChange(v) : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Notification Settings',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Outfit')),
              const SizedBox(height: 12),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    // Auto-notify toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Auto-Notify on Accident',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      fontFamily: 'Outfit')),
                              Text(
                                  'Automatically share location if crash detected',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                      fontFamily: 'Outfit')),
                            ],
                          ),
                        ),
                        Switch(
                          value: autoNotify,
                          onChanged: onAutoNotifyChange,
                          activeColor: Colors.white,
                          activeTrackColor: AppColors.blue,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: AppColors.textMuted,
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    // Instant SMS toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Instant SMS Alert',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      fontFamily: 'Outfit')),
                              Text('Send text message on emergency trigger',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                      fontFamily: 'Outfit')),
                            ],
                          ),
                        ),
                        Switch(
                          value: instantSms,
                          onChanged: onInstantSmsChange,
                          activeColor: Colors.white,
                          activeTrackColor: AppColors.blue,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: AppColors.textMuted,
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    // Voice call toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Voice Call Alert',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      fontFamily: 'Outfit')),
                              Text('Automated call to this contact',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                      fontFamily: 'Outfit')),
                            ],
                          ),
                        ),
                        Switch(
                          value: voiceCall,
                          onChanged: onVoiceCallChange,
                          activeColor: Colors.white,
                          activeTrackColor: AppColors.blue,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Save Contact', onTap: onSave),
              const SizedBox(height: 12),
              SecondaryButton(label: 'Cancel', onTap: onBack),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Error view
// ─────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, color: AppColors.red, size: 40),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontFamily: 'Outfit')),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.blue.withOpacity(0.3)),
                ),
                child: const Text('Try Again',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blueLight,
                        fontFamily: 'Outfit')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
