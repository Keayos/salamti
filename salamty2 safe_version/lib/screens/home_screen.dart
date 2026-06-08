import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

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

  // ── Location state ─────────────────────────────────────────
  final MapController _mapController = MapController();
  LatLng? _currentPosition; // null until first GPS fix
  bool _locationLoading = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the location dot
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Start listening to GPS
    _initLocation();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Location logic ─────────────────────────────────────────

  /// Checks permissions then starts a live position stream.
  Future<void> _initLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });

    // 1. Check if location services are enabled on the device
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationError = 'Location services are disabled.';
        _locationLoading = false;
      });
      return;
    }

    // 2. Check / request permission
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

    // 3. Get the first position immediately so the map snaps to
    //    the user's location right away without waiting for the stream.
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
        // Move the map camera to the user's location
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

    // 4. Listen for live position updates (updates as user moves)
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 metres of movement
      ),
    ).listen((Position pos) {
      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentPosition = latLng);
      // Smoothly follow the user as they move
      _mapController.move(latLng, _mapController.camera.zoom);
    });
  }

  /// Centers the map back on the user's position when
  /// the "my location" button is tapped.
  void _centerOnUser() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 15);
    }
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // ── Hardware banner ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    StatusDot(color: AppColors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hardware Connected',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'Outfit')),
                          Text('OBD-|| Smart Tracker v2.4 • Active',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Outfit')),
                        ],
                      ),
                    ),
                    _HardwareStat(icon: Icons.gps_fixed, label: 'GPS'),
                    SizedBox(width: 16),
                    _HardwareStat(
                        icon: Icons.battery_5_bar,
                        label: '88%',
                        color: AppColors.green),
                  ],
                ),
              ),
            ),

            // ── Map ──
            Expanded(
              child: _MapView(
                pulseAnim: _pulseAnim,
                mapController: _mapController,
                currentPosition: _currentPosition,
                locationLoading: _locationLoading,
                locationError: _locationError,
                onCenterOnUser: _centerOnUser,
                onRetryLocation: _initLocation,
              ),
            ),

            // ── Driving info ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.directions_car,
                              color: AppColors.blueLight, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DRIVING MODE ACTIVE',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1,
                                    fontFamily: 'Outfit')),
                            RichText(
                              text: const TextSpan(children: [
                                TextSpan(
                                    text: 'Current Speed ',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Outfit')),
                                TextSpan(
                                    text: '0 ',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                        fontFamily: 'Outfit')),
                                TextSpan(
                                    text: 'KM/H',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Outfit')),
                              ]),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('State',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                    letterSpacing: 0.8,
                                    fontFamily: 'Outfit')),
                            SizedBox(height: 2),
                            Text('SAFE',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.green,
                                    fontFamily: 'Outfit')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _SOSButton(
                        onTap: () => setState(() => _showSOS = true)),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── SOS overlay ──
        if (_showSOS)
          _SOSDialog(onDismiss: () => setState(() => _showSOS = false)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Map view — now receives real GPS state
// ─────────────────────────────────────────────
class _MapView extends StatelessWidget {
  final Animation<double> pulseAnim;
  final MapController mapController;
  final LatLng? currentPosition;
  final bool locationLoading;
  final String? locationError;
  final VoidCallback onCenterOnUser;
  final VoidCallback onRetryLocation;

  const _MapView({
    required this.pulseAnim,
    required this.mapController,
    required this.currentPosition,
    required this.locationLoading,
    required this.locationError,
    required this.onCenterOnUser,
    required this.onRetryLocation,
  });

  @override
  Widget build(BuildContext context) {
    // Default center — shown only until the first GPS fix arrives
    final center = currentPosition ?? const LatLng(31.4368, 31.6670);

    return Stack(
      children: [
        // ── The actual map ──
        FlutterMap(
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

        // ── Real location dot — only shown once we have a GPS fix ──
        if (currentPosition != null)
          Center(
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

        // ── Loading spinner — shown while waiting for first fix ──
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

        // ── Error banner — shown if permission denied / GPS off ──
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
          left: 14,
          top: 0,
          bottom: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(height: 8),
              // "My location" button — centers map on user
              _MapCtrlBtn(
                icon: Icons.my_location,
                color: AppColors.blue,
                onTap: onCenterOnUser,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Map control button — now has onTap
// ─────────────────────────────────────────────
class _MapCtrlBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const _MapCtrlBtn({required this.icon, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color ?? AppColors.bg.withOpacity(0.85),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Hardware stat chip (unchanged)
// ─────────────────────────────────────────────
class _HardwareStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HardwareStat({
    required this.icon,
    required this.label,
    this.color = AppColors.blueLight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: 'Outfit')),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  SOS button (unchanged)
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
//  SOS dialog (unchanged)
// ─────────────────────────────────────────────
class _SOSDialog extends StatelessWidget {
  final VoidCallback onDismiss;
  const _SOSDialog({required this.onDismiss});

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
              const Text(
                'This will notify all emergency contacts and send your current location.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontFamily: 'Outfit',
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                  label: 'Send Emergency Alert',
                  color: AppColors.red,
                  onTap: onDismiss),
              const SizedBox(height: 12),
              SecondaryButton(label: 'Cancel', onTap: onDismiss),
            ],
          ),
        ),
      ),
    );
  }
}
