import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/api_service.dart';

const _kContacts = 'emergency_contacts';

class _Contact {
  final int id;
  String name, rel, phone, initials;
  bool notify;

  _Contact({
    required this.id,
    required this.name,
    required this.rel,
    required this.phone,
    required this.initials,
    this.notify = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rel': rel,
        'phone': phone,
        'initials': initials,
        'notify': notify,
      };

  factory _Contact.fromJson(Map<String, dynamic> json) => _Contact(
        id: json['id'] as int,
        name: json['name'] as String,
        rel: json['rel'] as String,
        phone: json['phone'] as String,
        initials: json['initials'] as String,
        notify: json['notify'] as bool? ?? true,
      );
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  bool _showAdd = false;

  final List<_Contact> _contacts = [];

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedRel = '';

  // ── Lifecycle ──────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kContacts);
    if (saved != null) {
      final list = jsonDecode(saved) as List<dynamic>;
      setState(() {
        _contacts
          ..clear()
          ..addAll(
              list.map((e) => _Contact.fromJson(e as Map<String, dynamic>)));
      });
    }
  }

  // Fire-and-forget auto-save
  Future<void> _autoSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kContacts, jsonEncode(_contacts.map((c) => c.toJson()).toList()));

    // ── 2. Send to server ──────────────────────────────────────
    ApiService.saveContacts(
      _contacts.map((c) => c.toJson()).toList(),
    );
  }

  // ── Add contact ────────────────────────────
  void _addContact() {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) return;
    final name = _nameCtrl.text;
    final parts = name.split(' ').where((w) => w.isNotEmpty).toList();
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : parts[0][0].toUpperCase();

    setState(() {
      _contacts.add(_Contact(
        id: DateTime.now().millisecondsSinceEpoch,
        name: name,
        rel: _selectedRel,
        phone: _phoneCtrl.text,
        initials: initials,
      ));
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _selectedRel = '';
      _showAdd = false;
    });
    _autoSave();
  }

  // ── Delete contact ─────────────────────────
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
          'Are you sure you want to remove "${contact.name}" from your emergency contacts?',
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

    if (confirmed == true) {
      setState(() => _contacts.removeWhere((c) => c.id == contact.id));
      _autoSave();
    }
  }

  // ── Toggle notify ──────────────────────────
  void _toggleNotify(_Contact contact) {
    setState(() => contact.notify = !contact.notify);
    _autoSave();
  }

  // ── Build ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_showAdd) {
      return _AddContactView(
        nameCtrl: _nameCtrl,
        phoneCtrl: _phoneCtrl,
        selectedRel: _selectedRel,
        onRelChange: (v) => setState(() => _selectedRel = v),
        onSave: _addContact,
        onBack: () => setState(() => _showAdd = false),
      );
    }

    return Column(
      children: [
        // ── Top bar (no bell, no Save button) ──
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
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        color: AppColors.textSecondary, fontFamily: 'Outfit'),
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
                        color: AppColors.textSecondary, fontFamily: 'Outfit'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                borderRadius: BorderRadius.circular(14)),
                            title: const Text('Remove contact?',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'Outfit')),
                            content: Text(
                              'Are you sure you want to remove "${c.name}"?',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                  fontFamily: 'Outfit'),
                            ),
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
                  onDismissed: (_) {
                    setState(() => _contacts.removeWhere((x) => x.id == c.id));
                    _autoSave();
                  },
                  child: _ContactCard(
                    contact: c,
                    onToggle: () => _toggleNotify(c),
                    onDelete: () => _confirmDelete(c),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Column(
                children: const [
                  Icon(Icons.sensors, color: AppColors.textMuted, size: 24),
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

  const _ContactCard({
    required this.contact,
    required this.onToggle,
    required this.onDelete,
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
                    Text(contact.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFamily: 'Outfit')),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (contact.rel.isNotEmpty) ...[
                          RelBadge(contact.rel),
                          const SizedBox(width: 8),
                        ],
                        Text(contact.phone,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontFamily: 'Outfit')),
                      ],
                    ),
                  ],
                ),
              ),
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
                value: contact.notify,
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
//  Add Contact View (bell icon removed)
// ─────────────────────────────────────────────
class _AddContactView extends StatelessWidget {
  final TextEditingController nameCtrl, phoneCtrl;
  final String selectedRel;
  final ValueChanged<String> onRelChange;
  final VoidCallback onSave, onBack;

  const _AddContactView({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.selectedRel,
    required this.onRelChange,
    required this.onSave,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final rels = [
      'Father',
      'Mother',
      'Brother',
      'Sister',
      'Spouse',
      'Friend',
      'Colleague'
    ];
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
              const SizedBox(width: 40), // balance back arrow
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
                        label: 'Phone Number',
                        hint: '000 000 0000',
                        prefixIcon: Icons.phone_outlined,
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone),
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
                            items: rels
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
                  children: const [
                    ToggleRow(
                        label: 'Auto-Notify on Accident',
                        subtitle:
                            'Automatically share location if crash detected',
                        initial: true),
                    Divider(color: AppColors.border, height: 1),
                    ToggleRow(
                        label: 'Instant SMS Alert',
                        subtitle: 'Send text message on emergency trigger',
                        initial: true),
                    Divider(color: AppColors.border, height: 1),
                    ToggleRow(
                        label: 'Voice Call Alert',
                        subtitle: 'Automated call to this contact'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: '+ Add Contact', onTap: onSave),
              const SizedBox(height: 12),
              SecondaryButton(label: 'Cancel', onTap: onBack),
            ],
          ),
        ),
      ],
    );
  }
}
