import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// APP NOTIFICATION MODEL
// ═══════════════════════════════════════════════════════════════════════════════

/// Data model for a single notification item.
///
/// [type] must be one of: 'emergency' | 'system' | 'info'
///
/// Wire up your real API by replacing the mock block inside
/// [_AlertsScreenState._fetchNotifications] with an http.get() call and
/// decoding each JSON object with [AppNotification.fromJson].
///
/// Expected JSON shape:
/// ```json
/// {
///   "id":          "abc123",
///   "type":        "emergency",
///   "title":       "Critical alert",
///   "description": "Details here...",
///   "time":        "Just now",
///   "isNew":       true
/// }
/// ```
class AppNotification {
  final String id;
  final String type;        // 'emergency' | 'system' | 'info'
  final String title;
  final String description;
  final String time;
  final bool   isNew;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.time,
    this.isNew = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id:          json['id']          as String,
        type:        json['type']        as String,
        title:       json['title']       as String,
        description: json['description'] as String,
        time:        json['time']        as String,
        isNew:       json['isNew']       as bool? ?? false,
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALERTS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter    = 'All';
  bool   _isLoading = false;
  String? _error;

  /// Live notification list — populated by [_fetchNotifications].
  /// Starts empty; the UI shows a spinner while fetching.
  List<AppNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  // ── API entry point ────────────────────────────────────────────────────────
  /// ⚠️  Replace the MOCK BLOCK below with your real HTTP call, e.g.:
  ///
  /// ```dart
  /// final response = await http.get(
  ///   Uri.parse('https://your-api.com/notifications'),
  ///   headers: {'Authorization': 'Bearer $token'},
  /// );
  /// if (response.statusCode == 200) {
  ///   final List<dynamic> data = jsonDecode(response.body);
  ///   setState(() => _notifications =
  ///       data.map((e) => AppNotification.fromJson(e)).toList());
  /// } else {
  ///   setState(() => _error = 'Server error ${response.statusCode}');
  /// }
  /// ```
  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error     = null;
    });

    try {
      // ── MOCK: simulates network latency ───────────────────────────────────
      await Future.delayed(const Duration(milliseconds: 700));

      // Replace this list with data decoded from your API response.
      setState(() => _notifications = const [
            AppNotification(
              id: '1',
              type: 'emergency',
              title: 'Critical: New Emergency Request',
              description:
                  'High-priority medical transport requested at 124 King Fahd Rd.',
              time: 'Just now',
              isNew: true,
            ),
            AppNotification(
              id: '2',
              type: 'info',
              title: 'Alert: Road Closure',
              description:
                  'Major traffic delay on Highway 10 due to maintenance. Rerouting suggested.',
              time: '5m ago',
              isNew: true,
            ),
            AppNotification(
              id: '3',
              type: 'system',
              title: 'License expiring soon',
              description:
                  'Your driver license expires in 15 days. Please upload a renewed copy.',
              time: '2h ago',
            ),
            AppNotification(
              id: '4',
              type: 'system',
              title: 'Profile verification approved',
              description:
                  'Security check completed. Your profile verification is fully approved.',
              time: '4h ago',
            ),
            AppNotification(
              id: '5',
              type: 'system',
              title: 'App update available',
              description:
                  'Version 2.4.0 includes performance improvements and new safety features.',
              time: '8h ago',
            ),
          ]);
      // ── end mock block ─────────────────────────────────────────────────────
    } catch (e) {
      setState(() => _error = 'Could not load alerts. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Filtering ──────────────────────────────────────────────────────────────
  List<AppNotification> get _filtered {
    if (_filter == 'All') return _notifications;
    final key = _filter.toLowerCase(); // 'emergency' | 'system'
    return _notifications.where((n) => n.type == key).toList();
  }

  // ── Icon / colour helpers ──────────────────────────────────────────────────
  IconData _iconFor(String type) {
    switch (type) {
      case 'emergency': return Icons.emergency;
      case 'system':    return Icons.settings_outlined;
      default:          return Icons.warning_amber_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'emergency': return AppColors.red;
      case 'system':    return AppColors.blueLight;
      default:          return AppColors.yellow;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
          child: Row(
            children: const [
              Icon(Icons.arrow_back_ios,
                  color: AppColors.blueLight, size: 20),
              Expanded(
                child: Text('Notifications',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'Outfit')),
              ),
              SizedBox(width: 20),
            ],
          ),
        ),

        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: ['All', 'Emergency', 'System'].map((f) {
              final active = _filter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? AppColors.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              active ? AppColors.blue : AppColors.border),
                    ),
                    child: Text(f,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontFamily: 'Outfit')),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Body
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blueLight),
      );
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _fetchNotifications);
    }
    final items = _filtered;
    if (items.isEmpty) {
      return _EmptyView(onRefresh: _fetchNotifications);
    }
    return RefreshIndicator(
      color: AppColors.blueLight,
      onRefresh: _fetchNotifications,
      child: ListView.builder(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final n = items[index];
          return _NotificationCard(
            iconBg:      _colorFor(n.type).withOpacity(0.15),
            icon:        _iconFor(n.type),
            iconColor:   _colorFor(n.type),
            title:       n.title,
            description: n.description,
            time:        n.time,
            isNew:       n.isNew,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Notification card
// ─────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final Color  iconBg, iconColor;
  final IconData icon;
  final String title, description, time;
  final bool   isNew;

  const _NotificationCard({
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.description,
    required this.time,
    this.isNew = false,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon bubble
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontFamily: 'Outfit')),
                    ),
                    if (isNew) ...[
                      Text(time,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.blueLight,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Outfit')),
                      const SizedBox(width: 6),
                      StatusDot(color: AppColors.blueLight),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontFamily: 'Outfit')),
                if (!isNew) ...[
                  const SizedBox(height: 4),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'Outfit')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.card2,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.notifications_none_outlined,
                  color: AppColors.textMuted, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('No alerts',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Outfit')),
            const SizedBox(height: 6),
            const Text("You're all caught up!",
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontFamily: 'Outfit')),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.blue.withOpacity(0.3)),
                ),
                child: const Text('Refresh',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blueLight,
                        fontFamily: 'Outfit')),
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────
//  Error state
// ─────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.red.withOpacity(0.25)),
                ),
                child: const Icon(Icons.wifi_off_outlined,
                    color: AppColors.red, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('Something went wrong',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Outfit')),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontFamily: 'Outfit')),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.blue.withOpacity(0.3)),
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
