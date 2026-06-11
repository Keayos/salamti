import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/auth_service.dart';
import '../services/api_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  bool _showSOS = false;
  String? _obuId;
  bool? _obuActive;
  String? _obuStatus; // 'ACTIVE' | 'READY' | 'OUTDATED' | 'BROKEN' | null
  bool _obuLoading = false;
  bool _obuControlsLoading = false;
  bool _obuHealthLoading = false;
  Map<String, dynamic>? _obuHealth;
  LatLng? _obuLocation; // non-null = show OBU location on map
  bool _obuLocationLoading = false;
  String? _obuInstCached;
  String? _obuVersionCached;
  String? _obuSimCached;

  // ── Location state ─────────────────────────────────────────
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  bool _locationLoading = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initLocation();
    _loadObuData();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationError = 'Location services are disabled.';
        _locationLoading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationError = 'Location permission denied.';
          _locationLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationError =
            'Location permission is permanently denied. Please enable it in settings.';
        _locationLoading = false;
      });
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        final latLng = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _currentPosition = latLng;
          _locationLoading = false;
        });
        _mapController.move(latLng, 15);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Could not get location.';
          _locationLoading = false;
        });
      }
      return;
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position pos) {
      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentPosition = latLng);
      // Only follow user if not viewing OBU location
      if (_obuLocation == null) {
        _mapController.move(latLng, _mapController.camera.zoom);
      }
    });
  }

  // Centers map on user and clears OBU location
  // current location button fuction
  void _centerOnUser() {
    setState(() => _obuLocation = null);
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 15);
    }
  }

  Future<void> _loadObuId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _obuId = prefs.getString('obu_id');
      _obuInstCached = prefs.getString('obu_inst_number');
      _obuVersionCached = prefs.getString('obu_version');
      _obuSimCached = prefs.getString('obu_sim_number');
    });
    _obuStatus = prefs.getString('obu_status');
    _obuActive = _obuStatus == 'ACTIVE'
        ? true
        : _obuStatus == 'READY'
            ? false
            : null;
  }

  // ── Load all OBU data sequentially ──
  Future<void> _loadObuData() async {
    await _loadObuId();
    // After OBU ID is loaded, fetch status and health
    await Future.wait([
      _fetchObuStatus(),
      _checkObuHealth(),
    ]);
  }

  Future<void> _fetchObuStatus() async {
    if (_obuId == null) {
      setState(() {
        _obuActive = null;
        _obuStatus = null;
      });
      return;
    }
    setState(() => _obuControlsLoading = true);
    try {
      final token = await AuthService.getAccessToken();
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/obus/$_obuId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final obu = jsonDecode(res.body)['data']['obu'] as Map<String, dynamic>;
        final status = obu['status'] as String? ?? '';
        setState(() {
          _obuStatus = status;
          _obuActive = status == 'ACTIVE'
              ? true
              : status == 'READY'
                  ? false
                  : null;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('obu_status', status);
      } else {
        setState(() {
          _obuActive = null;
          _obuStatus = null;
        });
      }
    } catch (e) {
      assert(() {
        debugPrint('OBU status fetch error: $e');
        return true;
      }());
      setState(() {
        _obuActive = null;
        _obuStatus = null;
      });
    } finally {
      setState(() => _obuControlsLoading = false);
    }
  }

  Future<void> _toggleObu() async {
    if (_obuLoading) return;
    if (_obuId == null) return;
    setState(() => _obuLoading = true);
    final token = await AuthService.getAccessToken();
    final action = _obuStatus == 'ACTIVE' ? 'deactivate' : 'activate';
    try {
      final res = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/obus/$_obuId/$action'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final newStatus = _obuStatus == 'ACTIVE' ? 'READY' : 'ACTIVE';
        setState(() {
          _obuStatus = newStatus;
          _obuActive = newStatus == 'ACTIVE';
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('obu_status', newStatus);
      }
    } catch (e) {
      assert(() {
        debugPrint('OBU toggle error: $e');
        return true;
      }());
    } finally {
      setState(() => _obuLoading = false);
    }
  }

  Future<void> _checkObuHealth() async {
    if (_obuId == null || _obuHealthLoading) return;
    setState(() => _obuHealthLoading = true);
    try {
      final token = await AuthService.getAccessToken();
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/obus/$_obuId/health'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final health =
            jsonDecode(res.body)['data']['health'] as Map<String, dynamic>;
        setState(() {
          _obuHealth = health;
          _obuInstCached = health['inst'] as String? ?? _obuInstCached;
          _obuVersionCached = health['version'] as String? ?? _obuVersionCached;
          _obuSimCached = health['sim'] as String? ?? _obuSimCached;
        });
        final prefs = await SharedPreferences.getInstance();
        await Future.wait([
          if (_obuInstCached != null)
            prefs.setString('obu_inst_number', _obuInstCached!),
          if (_obuVersionCached != null)
            prefs.setString('obu_version', _obuVersionCached!),
          if (_obuSimCached != null)
            prefs.setString('obu_sim_number', _obuSimCached!),
        ]);
      } else {
        // No response — set status to '-'
        setState(() => _obuHealth = null);
      }
    } catch (e) {
      assert(() {
        debugPrint('OBU health check error: $e');
        return true;
      }());
      // On error — set status to '-'
      setState(() => _obuHealth = null);
    } finally {
      setState(() => _obuHealthLoading = false);
    }
  }

  Future<void> _requestLocationPermissionDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Enable Location',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'Outfit',
          ),
        ),
        content: const Text(
          'Location services are required to use this app. Would you like to enable them?',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontFamily: 'Outfit',
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Geolocator.openLocationSettings();
              final serviceEnabled =
                  await Geolocator.isLocationServiceEnabled();
              if (serviceEnabled) {
                _initLocation();
              }
            },
            child: const Text(
              'Enable',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.blue,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLocationRetry() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      _initLocation();
    } else {
      _requestLocationPermissionDialog();
    }
  }

  Future<void> _getObuLocation() async {
    if (_obuId == null || _obuLocationLoading) return;
    setState(() => _obuLocationLoading = true);
    try {
      final token = await AuthService.getAccessToken();
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/obus/$_obuId/location'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final loc =
            jsonDecode(res.body)['data']['location'] as Map<String, dynamic>;
        final lat = (loc['lat'] as num).toDouble();
        final lng = (loc['lng'] as num).toDouble();
        final obuLatLng = LatLng(lat, lng);
        setState(() => _obuLocation = obuLatLng);
        _mapController.move(obuLatLng, 15);
      }
    } catch (e) {
      assert(() {
        debugPrint('OBU location fetch error: $e');
        return true;
      }());
    } finally {
      setState(() => _obuLocationLoading = false);
    }
  }

  Future<void> _sendSos() async {
    final token = await AuthService.getAccessToken();
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/accidents/app-sos'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'lat': _currentPosition?.latitude ?? 0.0,
        'lng': _currentPosition?.longitude ?? 0.0,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('SOS failed: ${res.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              // ── Top banner ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      StatusDot(color: AppColors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Salamti App',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'Outfit')),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _centerOnUser,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.my_location,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text('Show Current Location',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      fontFamily: 'Outfit')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Map ──
              SizedBox(
                height: 280,
                child: _MapView(
                  pulseAnim: _pulseAnim,
                  mapController: _mapController,
                  currentPosition: _currentPosition,
                  obuLocation: _obuLocation,
                  locationLoading: _locationLoading,
                  locationError: _locationError,
                  onCenterOnUser: _centerOnUser,
                  onRetryLocation: _handleLocationRetry,
                ),
              ),

              // ── OBU Controls ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text('Control Your OBU',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: .5,
                                fontFamily: 'Outfit')),
                      ),
                      const SizedBox(height: 12),

                      // Activate / Deactivate button
                      GestureDetector(
                        onTap:
                            (_obuStatus == 'ACTIVE' || _obuStatus == 'READY') &&
                                    !_obuControlsLoading &&
                                    !_obuLoading
                                ? _toggleObu
                                : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _obuStatus == 'ACTIVE'
                                ? AppColors.red.withOpacity(0.15)
                                : _obuStatus == 'READY'
                                    ? AppColors.blue.withOpacity(0.15)
                                    : AppColors.textMuted.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _obuStatus == 'ACTIVE'
                                  ? AppColors.red.withOpacity(0.4)
                                  : _obuStatus == 'READY'
                                      ? AppColors.blue.withOpacity(0.4)
                                      : AppColors.textMuted.withOpacity(0.3),
                            ),
                          ),
                          child: Center(
                            child: _obuControlsLoading || _obuLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    _obuStatus == null
                                        ? 'Connect to OBU first'
                                        : _obuStatus == 'ACTIVE'
                                            ? 'Deactivate OBU'
                                            : _obuStatus == 'READY'
                                                ? 'Activate OBU'
                                                : _obuStatus == 'OUTDATED'
                                                    ? 'Outdated OBU version'
                                                    : _obuStatus == 'BROKEN'
                                                        ? 'OBU is broken'
                                                        : 'Connect to OBU first',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _obuStatus == 'ACTIVE'
                                            ? AppColors.red
                                            : _obuStatus == 'READY'
                                                ? AppColors.blueLight
                                                : AppColors.textMuted,
                                        fontFamily: 'Outfit'),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Refresh OBU button
                      // Refresh OBU button
                      GestureDetector(
                        onTap: _obuId == null
                            ? null
                            : () async {
                                await Future.wait([
                                  _checkObuHealth(),
                                  _fetchObuStatus(),
                                ]);
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _obuId == null
                                ? AppColors.textMuted.withOpacity(0.10)
                                : AppColors.blue.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _obuId == null
                                    ? AppColors.textMuted.withOpacity(0.3)
                                    : AppColors.blue.withOpacity(0.3)),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh,
                                    color: _obuId == null
                                        ? AppColors.textMuted
                                        : AppColors.blueLight,
                                    size: 16),
                                const SizedBox(width: 6),
                                Text('Refresh OBU',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _obuId == null
                                            ? AppColors.textMuted
                                            : AppColors.blueLight,
                                        fontFamily: 'Outfit')),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // OBU Health Status
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _obuHealthLoading
                              ? const _ObuHealthRowLoading(label: 'Status')
                              : _ObuHealthRow(
                                  label: 'Status',
                                  boldLabel: true,
                                  value: _obuHealth?['state'] == 1
                                      ? 'Safe'
                                      : _obuHealth?['state'] == 0
                                          ? 'Unsafe'
                                          : '—',
                                  valueColor: _obuHealth?['state'] == 1
                                      ? AppColors.green
                                      : _obuHealth?['state'] == 0
                                          ? AppColors.red
                                          : AppColors.textPrimary),
                          _ObuHealthRow(
                              label: 'Instance', value: _obuInstCached ?? '—'),
                          _ObuHealthRow(
                              label: 'Version',
                              value: _obuVersionCached ?? '—'),
                          _ObuHealthRow(
                              label: 'SIM Card', value: _obuSimCached ?? '—'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Get OBU Location button
                      GestureDetector(
                        onTap: _obuId == null || _obuLocationLoading
                            ? null
                            : _getObuLocation,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _obuId == null
                                ? AppColors.textMuted.withOpacity(0.10)
                                : AppColors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _obuId == null
                                    ? AppColors.textMuted.withOpacity(0.3)
                                    : AppColors.blue.withOpacity(0.4)),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _obuLocationLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.blueLight),
                                      )
                                    : Text('Get OBU Location',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _obuId == null
                                                ? AppColors.textMuted
                                                : AppColors.blueLight,
                                            fontFamily: 'Outfit')),
                                if (_obuLocation != null) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.location_on,
                                      color: AppColors.green, size: 16),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_obuLocation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: Text('Showing on map',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.green,
                                    fontFamily: 'Outfit')),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ], // ← closes Column's children
          ), // ← closes Column
        ), // ← closes SingleChildScrollView

        // ── SOS button (fixed) ──
        Positioned(
          bottom: 8,
          right: 14,
          child: _SOSButton(onTap: () => setState(() => _showSOS = true)),
        ),

        // ── SOS overlay ──
        if (_showSOS)
          _SOSDialog(
            onDismiss: () => setState(() => _showSOS = false),
            onConfirm: _sendSos,
          ),
      ],
    );
  }
}

//  Map view
class _MapView extends StatelessWidget {
  final Animation<double> pulseAnim;
  final MapController mapController;
  final LatLng? currentPosition;
  final LatLng? obuLocation;
  final bool locationLoading;
  final String? locationError;
  final VoidCallback onCenterOnUser;
  final VoidCallback onRetryLocation;

  const _MapView({
    required this.pulseAnim,
    required this.mapController,
    required this.currentPosition,
    required this.obuLocation,
    required this.locationLoading,
    required this.locationError,
    required this.onCenterOnUser,
    required this.onRetryLocation,
  });

  @override
  Widget build(BuildContext context) {
    final center =
        obuLocation ?? currentPosition ?? const LatLng(31.4368, 31.6670);

    return Stack(
      children: [
        // ── Map ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://maps.googleapis.com/maps/vt?lyrs=m&x={x}&y={y}&z={z}&key=AIzaSyCHCtjJnusRII2hnHUyLFR_3fLdcZ0zFr4',
                ),
              ],
            ),
          ),
        ),

        // ── User location dot (shown when not viewing OBU location) ──
        if (currentPosition != null && obuLocation == null)
          Positioned(
            left: 12,
            right: 12,
            top: 8,
            bottom: 8,
            child: Center(
              child: AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, __) => Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blueLight
                            .withOpacity(0.3 * pulseAnim.value),
                        blurRadius: 20 * pulseAnim.value,
                        spreadRadius: 6 * pulseAnim.value,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── OBU location dot (shown when viewing OBU location) ──
        if (obuLocation != null)
          Positioned(
            left: 12,
            right: 12,
            top: 8,
            bottom: 8,
            child: Center(
              child: AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, __) => Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppColors.green.withOpacity(0.3 * pulseAnim.value),
                        blurRadius: 20 * pulseAnim.value,
                        spreadRadius: 6 * pulseAnim.value,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── Loading spinner ──
        if (locationLoading)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.card.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: AppColors.blueLight, strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Getting your location...',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFamily: 'Outfit')),
                  ],
                ),
              ),
            ),
          ),

        // ── Error banner ──
        if (locationError != null)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_off,
                      color: AppColors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(locationError!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.red,
                            fontFamily: 'Outfit')),
                  ),
                  GestureDetector(
                    onTap: onRetryLocation,
                    child: const Text('Retry',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.red,
                            fontFamily: 'Outfit')),
                  ),
                ],
              ),
            ),
          ),

        // ── Map controls ──
        Positioned(
          left: 26,
          top: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapCtrlBtn(
                    icon: Icons.add,
                    onTap: () => mapController.move(
                      mapController.camera.center,
                      mapController.camera.zoom + 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MapCtrlBtn(
                    icon: Icons.remove,
                    onTap: () => mapController.move(
                      mapController.camera.center,
                      mapController.camera.zoom - 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

//  Map control button
class _MapCtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _MapCtrlBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.bg.withOpacity(0.85),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

//  SOS button
class _SOSButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SOSButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: AppColors.red,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: AppColors.red.withOpacity(0.2),
                blurRadius: 0,
                spreadRadius: 4),
            BoxShadow(
                color: AppColors.red.withOpacity(0.4),
                blurRadius: 16,
                spreadRadius: 2),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emergency, color: Colors.white, size: 22),
            Text('SOS',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit')),
          ],
        ),
      ),
    );
  }
}

class _SOSDialog extends StatefulWidget {
  final VoidCallback onDismiss;
  final Future<void> Function() onConfirm;
  const _SOSDialog({required this.onDismiss, required this.onConfirm});

  @override
  State<_SOSDialog> createState() => _SOSDialogState();
}

class _SOSDialogState extends State<_SOSDialog> {
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚨', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 10),
              const Text('Emergency SOS',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.red,
                      fontFamily: 'Outfit')),
              const SizedBox(height: 8),
              Text(
                _sent
                    ? 'Emergency alert sent successfully.'
                    : 'This will notify all emergency contacts and send your current location.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: _sent ? AppColors.green : AppColors.textSecondary,
                    fontFamily: 'Outfit',
                    height: 1.5),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.red,
                        fontFamily: 'Outfit')),
              ],
              const SizedBox(height: 24),
              if (!_sent)
                PrimaryButton(
                  label: _loading ? 'Sending...' : 'Send Emergency Alert',
                  color: AppColors.red,
                  onTap: _loading
                      ? null
                      : () async {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          try {
                            await widget.onConfirm();
                            setState(() {
                              _loading = false;
                              _sent = true;
                            });
                          } catch (e) {
                            setState(() {
                              _loading = false;
                              _error =
                                  'Failed to send alert. Please try again.';
                            });
                          }
                        },
                ),
              const SizedBox(height: 12),
              SecondaryButton(
                  label: _sent ? 'Close' : 'Cancel', onTap: widget.onDismiss),
            ],
          ),
        ),
      ),
    );
  }
}

//  OBU health table
class _ObuHealthRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool boldLabel;
  const _ObuHealthRow(
      {required this.label,
      required this.value,
      this.valueColor,
      this.boldLabel = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: boldLabel ? 14 : 13,
                  fontWeight: boldLabel ? FontWeight.w700 : FontWeight.normal,
                  color: boldLabel
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontFamily: 'Outfit')),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textPrimary,
                  fontFamily: 'Outfit')),
        ],
      ),
    );
  }
}

class _ObuHealthRowLoading extends StatelessWidget {
  final String label;
  const _ObuHealthRowLoading({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontFamily: 'Outfit')),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.blueLight),
          ),
        ],
      ),
    );
  }
}
