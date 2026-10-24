import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';
import '../../../core/services/location_service.dart';

/// Hasil pemilihan lokasi COD oleh penjual
class SelectedLocationResult {
  final double latitude;
  final double longitude;
  final String city;
  final String? locationName;

  const SelectedLocationResult({
    required this.latitude,
    required this.longitude,
    required this.city,
    this.locationName,
  });
}

/// Modal / Dialog Interaktif Pemilih Titik Lokasi COD pada Peta
class LocationPickerDialog extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final String initialCity;
  final String? initialLocationName;

  const LocationPickerDialog({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.initialCity,
    this.initialLocationName,
  });

  static Future<SelectedLocationResult?> show(
    BuildContext context, {
    required double initialLat,
    required double initialLng,
    required String initialCity,
    String? initialLocationName,
  }) {
    return showDialog<SelectedLocationResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LocationPickerDialog(
        initialLat: initialLat,
        initialLng: initialLng,
        initialCity: initialCity,
        initialLocationName: initialLocationName,
      ),
    );
  }

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final MapController _mapController = MapController();
  late TextEditingController _notesController;

  late LatLng _currentLocation;
  late String _selectedCity;
  bool _isLocatingGps = false;

  // Daftar kota acuan cepat
  static const Map<String, LatLng> _cityCoordinates = {
    'Yogyakarta': LatLng(-7.7956, 110.3695),
    'Jakarta Pusat': LatLng(-6.2088, 106.8456),
    'Jakarta Selatan': LatLng(-6.2615, 106.8106),
    'Bandung': LatLng(-6.9175, 107.6191),
    'Surabaya': LatLng(-7.2575, 112.7521),
    'Semarang': LatLng(-6.9932, 110.4203),
    'Malang': LatLng(-7.9666, 112.6326),
    'Denpasar': LatLng(-8.6705, 115.2126),
    'Medan': LatLng(3.5952, 98.6722),
    'Makassar': LatLng(-5.1477, 119.4327),
  };

  @override
  void initState() {
    super.initState();
    _currentLocation = LatLng(widget.initialLat, widget.initialLng);
    _selectedCity = widget.initialCity;
    _notesController = TextEditingController(text: widget.initialLocationName ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Lompat ke koordinat GPS perangkat saat ini
  Future<void> _jumpToCurrentGps() async {
    setState(() => _isLocatingGps = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        final newLoc = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _currentLocation = newLoc;
        });
        _mapController.move(newLoc, 16.0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi GPS berhasil ditemukan! ✨'),
            backgroundColor: AppColors.surfaceHighest,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        final explanation = await LocationService.getStatusExplanation();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(explanation),
            backgroundColor: AppColors.snackBarError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocatingGps = false);
    }
  }

  void _onCityChanged(String? newCity) {
    if (newCity == null) return;
    setState(() => _selectedCity = newCity);
    final target = _cityCoordinates[newCity];
    if (target != null) {
      setState(() => _currentLocation = target);
      _mapController.move(target, 14.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLowest,
        appBar: AppBar(
          title: const Text('Pilih Titik Lokasi COD'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  SelectedLocationResult(
                    latitude: _currentLocation.latitude,
                    longitude: _currentLocation.longitude,
                    city: _selectedCity,
                    locationName: _notesController.text.trim().isNotEmpty
                        ? _notesController.text.trim()
                        : null,
                  ),
                );
              },
              child: const Text(
                'SIMPAN',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Bar Navigasi Cepat Kota
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surface,
              child: Row(
                children: [
                  const Icon(Icons.location_city, color: AppColors.gold, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Lompat Kota: ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.surfaceHigh),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _cityCoordinates.containsKey(_selectedCity)
                              ? _selectedCity
                              : _cityCoordinates.keys.first,
                          isDense: true,
                          dropdownColor: AppColors.surface,
                          items: _cityCoordinates.keys.map((city) {
                            return DropdownMenuItem(
                              value: city,
                              child: Text(
                                city,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: _onCityChanged,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Area Peta Interaktif
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation,
                      initialZoom: 15.0,
                      minZoom: 3.0,
                      maxZoom: 18.0,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _currentLocation = point;
                        });
                        _mapController.move(point, _mapController.camera.zoom);
                      },
                      onPositionChanged: (camera, hasGesture) {
                        if (hasGesture) {
                          setState(() {
                            _currentLocation = camera.center;
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'id.ac.holodex',
                      ),
                    ],
                  ),

                  // Pin Penunjuk di Tengah Peta
                  IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLowest.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.gold,
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Geser peta ke titik COD',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Icon(
                              Icons.location_on,
                              size: 44,
                              color: AppColors.gold,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Tombol Melayang GPS Cepat
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.cyan,
                      tooltip: 'Gunakan Lokasi GPS Saya',
                      onPressed: _isLocatingGps ? null : _jumpToCurrentGps,
                      child: _isLocatingGps
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.cyan,
                              ),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ),
                ],
              ),
            ),

            // Form Keterangan Tempat COD di Bagian Bawah
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Koordinat Terkini
                    Row(
                      children: [
                        const Icon(Icons.pin_drop, size: 16, color: AppColors.cyan),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Koordinat: ${_currentLocation.latitude.toStringAsFixed(5)}, ${_currentLocation.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: AppColors.cyan,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Input Patokan Tempat COD
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Patokan Tempat / Lokasi COD',
                        hintText: 'Misal: Depan Kampus UPN, Indomaret Point, Lobi Mall...',
                        prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tombol Konfirmasi Pilihan
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 46),
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () {
                          Navigator.pop(
                            context,
                            SelectedLocationResult(
                              latitude: _currentLocation.latitude,
                              longitude: _currentLocation.longitude,
                              city: _selectedCity,
                              locationName: _notesController.text.trim().isNotEmpty
                                  ? _notesController.text.trim()
                                  : null,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text(
                          'Kunci Titik Lokasi Ini',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
