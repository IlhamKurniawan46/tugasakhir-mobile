import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/listing_model.dart';
import '../../../core/services/location_service.dart';
import 'marketplace_provider.dart';

class ListingWithDistance {
  final ListingModel listing;
  final double? distanceKm;

  const ListingWithDistance({
    required this.listing,
    this.distanceKm,
  });

  String get formattedDistance => distanceKm != null
      ? LocationService.formatDistance(distanceKm!)
      : 'Jarak tidak diketahui';
}

class MapState {
  final LatLng? userLocation;
  final bool isLoadingLocation;
  final String? locationErrorMessage;
  final double? selectedRadiusKm; // null = Semua
  final ListingModel? selectedListing;

  const MapState({
    this.userLocation,
    this.isLoadingLocation = false,
    this.locationErrorMessage,
    this.selectedRadiusKm,
    this.selectedListing,
  });

  MapState copyWith({
    LatLng? userLocation,
    bool? isLoadingLocation,
    String? locationErrorMessage,
    double? selectedRadiusKm,
    bool resetRadius = false,
    ListingModel? selectedListing,
    bool resetSelectedListing = false,
  }) =>
      MapState(
        userLocation: userLocation ?? this.userLocation,
        isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
        locationErrorMessage: locationErrorMessage,
        selectedRadiusKm: resetRadius
            ? null
            : (selectedRadiusKm ?? this.selectedRadiusKm),
        selectedListing: resetSelectedListing
            ? null
            : (selectedListing ?? this.selectedListing),
      );
}

class MapNotifier extends StateNotifier<MapState> {
  MapNotifier() : super(const MapState()) {
    initUserLocation();
  }

  /// Inisialisasi pengambilan lokasi pengguna secara live
  Future<void> initUserLocation() async {
    state = state.copyWith(isLoadingLocation: true, locationErrorMessage: null);
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        state = state.copyWith(
          userLocation: LatLng(position.latitude, position.longitude),
          isLoadingLocation: false,
          locationErrorMessage: null,
        );
      } else {
        // Gunakan lokasi default jika GPS tidak aktif / ditolak
        final explanation = await LocationService.getStatusExplanation();
        state = state.copyWith(
          userLocation: LocationService.defaultLocation,
          isLoadingLocation: false,
          locationErrorMessage: explanation,
        );
      }
    } catch (e) {
      state = state.copyWith(
        userLocation: LocationService.defaultLocation,
        isLoadingLocation: false,
        locationErrorMessage: 'Gagal mengambil GPS: $e',
      );
    }
  }

  void setRadius(double? radiusKm) {
    if (radiusKm == null) {
      state = state.copyWith(resetRadius: true);
    } else {
      state = state.copyWith(selectedRadiusKm: radiusKm);
    }
  }

  void selectListing(ListingModel? listing) {
    if (listing == null) {
      state = state.copyWith(resetSelectedListing: true);
    } else {
      state = state.copyWith(selectedListing: listing);
    }
  }
}

final mapStateProvider = StateNotifierProvider<MapNotifier, MapState>((ref) {
  return MapNotifier();
});

/// Provider yang menghitung jarak dan menyaring listing berdasarkan radius aktif
final mapListingsProvider = Provider<List<ListingWithDistance>>((ref) {
  final mapState = ref.watch(mapStateProvider);
  final marketplaceState = ref.watch(marketplaceProvider);
  final userLoc = mapState.userLocation;

  // 1. Ambil semua listing aktif yang memiliki koordinat
  final listingsWithCoords = marketplaceState.listings.where((l) {
    return l.isActive && l.lat != null && l.lng != null;
  }).toList();

  // 2. Hitung jarak untuk tiap listing
  final List<ListingWithDistance> items = [];
  for (final l in listingsWithCoords) {
    double? dist;
    if (userLoc != null && l.lat != null && l.lng != null) {
      dist = LocationService.calculateDistanceKm(
        startLatitude: userLoc.latitude,
        startLongitude: userLoc.longitude,
        endLatitude: l.lat!,
        endLongitude: l.lng!,
      );
    }

    // Filter radius jika dipilih
    if (mapState.selectedRadiusKm != null && dist != null) {
      if (dist <= mapState.selectedRadiusKm!) {
        items.add(ListingWithDistance(listing: l, distanceKm: dist));
      }
    } else {
      items.add(ListingWithDistance(listing: l, distanceKm: dist));
    }
  }

  // 3. Urutkan dari yang terdekat
  items.sort((a, b) {
    if (a.distanceKm == null && b.distanceKm == null) return 0;
    if (a.distanceKm == null) return 1;
    if (b.distanceKm == null) return -1;
    return a.distanceKm!.compareTo(b.distanceKm!);
  });

  return items;
});
