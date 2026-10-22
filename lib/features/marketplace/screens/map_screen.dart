import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';
import '../../../core/models/listing_model.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../shared/providers/currency_provider.dart';
import '../providers/map_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapStateProvider);
    final listingsWithDistance = ref.watch(mapListingsProvider);
    final selectedListing = mapState.selectedListing;
    final userLoc = mapState.userLocation ?? const LatLng(-6.1754, 106.8272);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Penjual Terdekat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Perbarui Lokasi GPS',
            onPressed: () =>
                ref.read(mapStateProvider.notifier).initUserLocation(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Peta OpenStreetMap dengan FlutterMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userLoc,
              initialZoom: 12.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onTap: (tapPosition, point) {
                // Deselect jika tap di luar marker
                ref.read(mapStateProvider.notifier).selectListing(null);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'id.ac.holodex',
              ),

              // Circle Layer untuk Radius jika aktif
              if (mapState.selectedRadiusKm != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: userLoc,
                      color: AppColors.gold.withAlpha(38),
                      borderColor: AppColors.gold,
                      borderStrokeWidth: 2,
                      useRadiusInMeter: true,
                      radius: mapState.selectedRadiusKm! * 1000,
                    ),
                  ],
                ),

              // Marker Layer (User & Listings Penjual)
              MarkerLayer(
                markers: [
                  // 1. Marker Lokasi Pengguna
                  Marker(
                    point: userLoc,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withAlpha(64),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. Marker Listing Penjual
                  ...listingsWithDistance.map((item) {
                    final listing = item.listing;
                    final point = LatLng(listing.lat!, listing.lng!);
                    final isSelected = selectedListing?.id == listing.id;

                    return Marker(
                      point: point,
                      width: isSelected ? 48 : 38,
                      height: isSelected ? 48 : 38,
                      child: GestureDetector(
                        onTap: () {
                          ref
                              .read(mapStateProvider.notifier)
                              .selectListing(listing);
                          _mapController.move(point, 14.0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.gold : Colors.black87,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isSelected ? Colors.black : AppColors.gold,
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.storefront,
                            size: isSelected ? 26 : 20,
                            color:
                                isSelected ? Colors.black : AppColors.gold,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Baris Chip Filter Radius di Bagian Atas
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface.withAlpha(230),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRadiusChip(null, 'Semua Jarak'),
                    const SizedBox(width: 6),
                    _buildRadiusChip(5, '5 km'),
                    const SizedBox(width: 6),
                    _buildRadiusChip(10, '10 km'),
                    const SizedBox(width: 6),
                    _buildRadiusChip(25, '25 km'),
                    const SizedBox(width: 6),
                    _buildRadiusChip(50, '50 km'),
                  ],
                ),
              ),
            ),
          ),

          // Floating Action Button "Lokasi Saya"
          Positioned(
            right: 16,
            bottom: selectedListing != null ? 180 : 24,
            child: FloatingActionButton.small(
              heroTag: 'map_my_location_btn',
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.gold,
              elevation: 4,
              onPressed: () {
                _mapController.move(userLoc, 14.0);
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // Banner Pesan GPS Jika Izin Ditolak
          if (mapState.locationErrorMessage != null)
            Positioned(
              bottom: selectedListing != null ? 180 : 24,
              left: 16,
              right: 76,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withAlpha(235),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.surfaceHigh),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.gold, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mapState.locationErrorMessage!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ),
                    if (mapState.locationErrorMessage!.contains('Pengaturan'))
                      InkWell(
                        onTap: () => LocationService.openSettings(),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text(
                            'Buka',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Kartu Info Listing Terpilih (Floating Bottom Card)
          if (selectedListing != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _buildListingBottomCard(
                context: context,
                listing: selectedListing,
                userLocation: userLoc,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRadiusChip(double? radiusKm, String label) {
    final mapState = ref.watch(mapStateProvider);
    final isSelected = mapState.selectedRadiusKm == radiusKm;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: AppColors.gold,
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppColors.onSurface,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 11,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(
        color: isSelected ? AppColors.gold : Colors.transparent,
      ),
      onSelected: (selected) {
        if (selected) {
          ref.read(mapStateProvider.notifier).setRadius(radiusKm);
        }
      },
    );
  }

  Widget _buildListingBottomCard({
    required BuildContext context,
    required ListingModel listing,
    required LatLng userLocation,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final selectedCurrency = ref.watch(currencyProvider);
    final card = listing.card;

    // Hitung jarak
    double? distanceKm;
    if (listing.lat != null && listing.lng != null) {
      distanceKm = LocationService.calculateDistanceKm(
        startLatitude: userLocation.latitude,
        startLongitude: userLocation.longitude,
        endLatitude: listing.lat!,
        endLongitude: listing.lng!,
      );
    }
    final distanceText = distanceKm != null
        ? LocationService.formatDistance(distanceKm)
        : null;

    // Hitung harga
    String displayPrice;
    if (selectedCurrency == AppCurrency.idr) {
      displayPrice = PriceFormatter.formatIdr(listing.priceIdr);
    } else {
      final converted = CurrencyService.convert(
        listing.priceIdr,
        from: 'IDR',
        to: selectedCurrency.code,
      );
      displayPrice = converted != null
          ? PriceFormatter.format(converted, selectedCurrency.code)
          : PriceFormatter.formatIdr(listing.priceIdr);
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail Gambar Kartu
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 50,
                    height: 70,
                    child: card?.lowResImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: card!.lowResImageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                Container(color: AppColors.surfaceHigh),
                          )
                        : Container(color: AppColors.surfaceHigh),
                  ),
                ),
                const SizedBox(width: 12),

                // Info Kartu & Penjual
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              card?.name ?? 'Kartu Pokémon',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              ref
                                  .read(mapStateProvider.notifier)
                                  .selectListing(null);
                            },
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${listing.sellerUsername ?? 'Penjual'} · ${listing.conditionLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 4,
                        spacing: 8,
                        children: [
                          Text(
                            displayPrice,
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          if (distanceText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.near_me,
                                    size: 10,
                                    color: AppColors.gold,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    distanceText,
                                    style: const TextStyle(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Tombol Lihat Detail Kartu
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text(
                  'Lihat Detail Kartu',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: () {
                  context.push(
                    '/marketplace/listing/${listing.id}',
                    extra: listing,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
