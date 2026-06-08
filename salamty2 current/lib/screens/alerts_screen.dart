import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

// ─────────────────────────────────────────────
//  Storage keys
// ─────────────────────────────────────────────
const _kAlerts = 'alerts_cache';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['titleSnapshot'] as String,
        body: json['bodySnapshot'] as String,
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String get type {
    final t = title.toLowerCase();
    if (t.contains('emergency')) return 'emergency';
    return 'system';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Screen
// ═════════════════════════════════════════════════════════════════════════════
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final List<AppNotification> _notifications = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const _limit = 10;
  String? _error;

  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCachedAlerts();
    _fetchPage(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _fetchPage();
    }
  }

  // ── Load cached alerts for offline support ──
  Future<void> _loadCachedAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kAlerts);
      if (cached != null) {
        final list = (jsonDecode(cached) as List)
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() => _notifications.addAll(list));
        }
      }
    } catch (e) {
      assert(() {
        debugPrint('Alerts cache load error: $e');
        return true;
      }());
    }
  }

  // ── Cache alerts to SharedPreferences ──
  Future<void> _cacheAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = _notifications
          .map((n) => {
                'id': n.id,
                'titleSnapshot': n.title,
                'bodySnapshot': n.body,
                'isRead': n.isRead,
                'createdAt': n.createdAt.toIso8601String(),
              })
          .toList();
      await prefs.setString(_kAlerts, jsonEncode(json));
    } catch (e) {
      assert(() {
        debugPrint('Alerts cache save error: $e');
        return true;
      }());
    }
  }

  Future<void> _fetchPage({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _notifications.clear();
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final token = await AuthService.getAccessToken();
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/notifications/?page=$_page&limit=$_limit',
      );
      final res = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body)['data'] as Map<String, dynamic>;
        final pagination = data['pagination'] as Map<String, dynamic>;
        final raw = data['notifications'] as List<dynamic>;
        final fetched = raw
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList();
        final totalPages = pagination['pages'] as int;

        setState(() {
          _notifications.addAll(fetched);
          _hasMore = _page < totalPages;
          _page++;
        });

        // Cache the updated list
        await _cacheAlerts();
      } else {
        setState(
            () => _error = 'Server error ${res.statusCode}. Please try again.');
      }
    } catch (e) {
      assert(() {
        debugPrint('Alerts fetch error: $e');
        return true;
      }());
      if (_notifications.isEmpty) {
        setState(() => _error = 'Could not load alerts. Please try again.');
      }
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _markAsRead(AppNotification n) async {
    if (n.isRead) return;
    try {
      final token = await AuthService.getAccessToken();
      await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/notifications/${n.id}/read'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      setState(() {
        final index = _notifications.indexWhere((x) => x.id == n.id);
        if (index != -1) {
          _notifications[index] = AppNotification(
            id: n.id,
            title: n.title,
            body: n.body,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
      });

      // Cache the updated list
      await _cacheAlerts();
    } catch (e) {
      assert(() {
        debugPrint('Mark as read error: $e');
        return true;
      }());
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
          child: Row(
            children: const [
              Expanded(
                child: Text('Notifications',
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
    if (_error != null && _notifications.isEmpty) {
      return _ErrorView(
          message: _error!, onRetry: () => _fetchPage(reset: true));
    }
    if (_notifications.isEmpty) {
      return _EmptyView(onRefresh: () => _fetchPage(reset: true));
    }
    return RefreshIndicator(
      color: AppColors.blueLight,
      backgroundColor: AppColors.card,
      onRefresh: () => _fetchPage(reset: true),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _notifications.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.blueLight, strokeWidth: 2),
              ),
            );
          }
          final n = _notifications[i];
          return _NotificationCard(
            title: n.title,
            body: n.body,
            time: _formatTime(n.createdAt),
            isRead: n.isRead,
            onViewMore: () => _markAsRead(n),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Notification card
// ═════════════════════════════════════════════════════════════════════════════
class _NotificationCard extends StatefulWidget {
  final String title, body, time;
  final bool isRead;
  final VoidCallback onViewMore;

  const _NotificationCard({
    required this.title,
    required this.body,
    required this.time,
    required this.isRead,
    required this.onViewMore,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.isRead ? 0.85 : 1.0,
      child: Container(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(widget.title,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                fontFamily: 'Outfit')),
                      ),
                      if (!widget.isRead) ...[
                        const SizedBox(width: 6),
                        StatusDot(color: AppColors.blueLight),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    crossFadeState: _expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Text(
                      widget.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: 'Outfit'),
                    ),
                    secondChild: Text(
                      widget.body,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: 'Outfit'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.time,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontFamily: 'Outfit')),
                      GestureDetector(
                        onTap: () {
                          setState(() => _expanded = !_expanded);
                          if (!widget.isRead) widget.onViewMore();
                        },
                        child: Text(
                          _expanded ? 'View less' : 'View more',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: widget.isRead
                                  ? AppColors.textMuted
                                  : AppColors.blueLight,
                              fontFamily: 'Outfit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Empty state
// ═════════════════════════════════════════════════════════════════════════════
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.blue.withOpacity(0.3)),
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

// ═════════════════════════════════════════════════════════════════════════════
//  Error state
// ═════════════════════════════════════════════════════════════════════════════
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
                  border: Border.all(color: AppColors.red.withOpacity(0.25)),
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
