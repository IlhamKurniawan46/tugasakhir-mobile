import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/database/local_db.dart';
import '../../../core/models/card_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/marketplace_repository.dart';
import '../../../core/utils/price_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../ai/services/gemini_service.dart';
import '../../profile/providers/collection_provider.dart';
import '../../profile/widgets/whatsapp_dialog.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/location_picker_dialog.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  final CardModel? preselectedCard;

  const CreateListingScreen({
    super.key,
    this.preselectedCard,
  });

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();

  CardModel? _selectedCard;
  String _condition = 'near_mint';
  String _selectedCity = 'Jakarta Pusat';
  String? _locationName;
  double _lat = -6.2088;
  double _lng = 106.8456;
  bool _isSubmitting = false;
  bool _isGeneratingAiDesc = false;
  bool _isLocatingGps = false;

  Future<void> _openLocationPicker() async {
    final result = await LocationPickerDialog.show(
      context,
      initialLat: _lat,
      initialLng: _lng,
      initialCity: _selectedCity,
      initialLocationName: _locationName,
    );

    if (result != null && mounted) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
        _selectedCity = result.city;
        _locationName = result.locationName;
      });
    }
  }

  Future<void> _useCurrentGpsLocation() async {
    setState(() => _isLocatingGps = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Titik GPS berhasil dikunci sebagai lokasi COD!'),
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

  @override
  void initState() {
    super.initState();
    _selectedCard = widget.preselectedCard;
    if (_selectedCard?.priceIdr != null) {
      _priceController.text = _selectedCard!.priceIdr!.round().toString();
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _openCardPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CardPickerSheet(
        onCardSelected: (card) {
          setState(() {
            _selectedCard = card;
            if (_priceController.text.isEmpty && card.priceIdr != null) {
              _priceController.text = card.priceIdr!.round().toString();
            }
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _submitListing() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login terlebih dahulu.'),
          backgroundColor: AppColors.snackBarError,
        ),
      );
      return;
    }

    if (_selectedCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kartu Pokémon yang ingin dijual terlebih dahulu.'),
          backgroundColor: AppColors.snackBarError,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.replaceAll('.', '').trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harga tidak valid.'),
          backgroundColor: AppColors.snackBarError,
        ),
      );
      return;
    }

    // Pengecekan Just-in-Time: Penjual wajib memiliki nomor WhatsApp untuk koordinasi COD
    if (user.whatsappNumber == null || user.whatsappNumber!.trim().isEmpty) {
      final savedPhone = await WhatsAppDialog.show(
        context,
        customTitle: 'Nomor WhatsApp Penjual',
        customExplanation:
            'Nomor WhatsApp diperlukan agar pembeli dapat menghubungi kamu setelah memesan kartu untuk koordinasi COD.',
      );

      if (savedPhone == null || savedPhone.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Pembuatan listing dibatalkan: Nomor WhatsApp wajib diisi untuk koordinasi COD.'),
              backgroundColor: AppColors.surfaceHigh,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await MarketplaceRepository.createListing(
        cardId: _selectedCard!.id,
        sellerId: user.id,
        priceIdr: price,
        condition: _condition,
        description: (_locationName != null && _locationName!.isNotEmpty)
            ? (_descController.text.trim().isNotEmpty
                ? '📍 Patokan COD: $_locationName\n\n${_descController.text.trim()}'
                : '📍 Patokan COD: $_locationName')
            : (_descController.text.trim().isNotEmpty
                ? _descController.text.trim()
                : null),
        lat: _lat,
        lng: _lng,
      );

      // Refresh data marketplace
      await ref.read(marketplaceProvider.notifier).loadListings(forceRefresh: true);

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing kartu berhasil dipasang di Marketplace!'),
            backgroundColor: AppColors.snackBarSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final errorText = e is MarketplaceFailure ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorText),
            backgroundColor: AppColors.snackBarError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _generateAiDescription() async {
    if (_selectedCard == null || _isGeneratingAiDesc) return;

    setState(() => _isGeneratingAiDesc = true);

    final conditionLabels = {
      'mint': 'Mint (Sempurna)',
      'near_mint': 'Near Mint (Sangat Mulus)',
      'lightly_played': 'Lightly Played (Sedikit Bekas Main)',
      'moderately_played': 'Moderately Played (Ada Bekas Pakai)',
      'heavily_played': 'Heavily Played (Banyak Goresan / Rusak)',
    };
    final conditionLabel = conditionLabels[_condition] ?? _condition;

    try {
      final desc = await GeminiService.generateListingDescription(
        card: _selectedCard!,
        conditionLabel: conditionLabel,
      );

      if (mounted) {
        setState(() {
          _descController.text = desc;
          _isGeneratingAiDesc = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deskripsi otomatis berhasil dibuat dengan AI!'),
            backgroundColor: AppColors.surfaceHighest,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingAiDesc = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat deskripsi via AI: $e'),
            backgroundColor: AppColors.snackBarError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pasang Listing Kartu'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Pemilih Kartu
            Text(
              'Kartu Pokémon Fisik',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _openCardPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedCard != null
                        ? AppColors.gold.withAlpha(128)
                        : AppColors.surfaceHigh,
                  ),
                ),
                child: _selectedCard == null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: AppColors.gold),
                          SizedBox(width: 8),
                          Text(
                            'Pilih Kartu dari Koleksi / Katalog',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 50,
                              height: 70,
                              child: _selectedCard!.lowResImageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: _selectedCard!.lowResImageUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(color: AppColors.surfaceHigh),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedCard!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_selectedCard!.setName ?? _selectedCard!.setId ?? 'TCG'} · ${_selectedCard!.rarity ?? 'Kartu'}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                if (_selectedCard!.priceIdr != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Acuan Pasar: ${PriceFormatter.formatIdr(_selectedCard!.priceIdr)}',
                                    style: const TextStyle(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.swap_horiz,
                              color: AppColors.onSurfaceVariant),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Input Harga
            Text(
              'Harga Jual (IDR)',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                prefixText: 'Rp ',
                hintText: 'Contoh: 150000',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Harga jual wajib diisi';
                }
                final numVal = double.tryParse(val.trim());
                if (numVal == null || numVal <= 0) {
                  return 'Harga harus lebih besar dari Rp0';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Pilihan Kondisi Kartu
            Text(
              'Kondisi Fisik Kartu',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildConditionChoice('mint', 'Mint (Sempurna)'),
                _buildConditionChoice('near_mint', 'Near Mint (Mulus)'),
                _buildConditionChoice('excellent', 'Excellent (Bagus)'),
                _buildConditionChoice('good', 'Good (Terawat)'),
                _buildConditionChoice('poor', 'Poor (Ada Minus)'),
              ],
            ),
            const SizedBox(height: 20),

            // Lokasi Titik COD Penjual
            Text(
              'Titik Lokasi COD Penjual',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceHigh),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on, color: AppColors.gold, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedCity,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Koordinat: ${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppColors.cyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_locationName != null && _locationName!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.surfaceHigh),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_outlined, size: 14, color: AppColors.outline),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Patokan: $_locationName',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Tombol Aksi: Pilih di Peta & Pakai GPS
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.gold,
                            side: const BorderSide(color: AppColors.gold, width: 1),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: _openLocationPicker,
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: const Text(
                            'Pilih di Peta',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.cyan,
                            side: BorderSide(
                              color: AppColors.cyan.withValues(alpha: 0.7),
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: _isLocatingGps ? null : _useCurrentGpsLocation,
                          icon: _isLocatingGps
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.cyan,
                                  ),
                                )
                              : const Icon(Icons.my_location, size: 16),
                          label: const Text(
                            'Pakai GPS',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Deskripsi / Catatan Penjual
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Deskripsi / Catatan Kondisi',
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (_selectedCard != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: _isGeneratingAiDesc
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.gold,
                            ),
                          )
                        : const Icon(Icons.auto_awesome, size: 14, color: AppColors.gold),
                    label: Text(
                      _isGeneratingAiDesc ? 'Membuat...' : 'Tulis via AI',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                    onPressed: _isGeneratingAiDesc ? null : _generateAiDescription,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Misal: Sudah pakai toploader & double sleeve, no whitening di sudut belakang.',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Tombol Submit
            SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.onGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitListing,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onGold,
                        ),
                      )
                    : const Text(
                        'Pasang Listing ke Marketplace',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionChoice(String key, String label) {
    final isSelected = _condition == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: AppColors.gold,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppColors.onSurface,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.gold : AppColors.surfaceHigh,
        ),
      ),
      onSelected: (val) {
        if (val) setState(() => _condition = key);
      },
    );
  }
}

/// Modal Bottom Sheet untuk memilih kartu baik dari Koleksi Saya atau dari Katalog Dex
class _CardPickerSheet extends ConsumerStatefulWidget {
  final ValueChanged<CardModel> onCardSelected;

  const _CardPickerSheet({required this.onCardSelected});

  @override
  ConsumerState<_CardPickerSheet> createState() => _CardPickerSheetState();
}

class _CardPickerSheetState extends ConsumerState<_CardPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _catalogSearchController =
      TextEditingController();
  List<CardModel> _catalogSearchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchCatalog('');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _catalogSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchCatalog(String query) async {
    setState(() => _isSearching = true);
    try {
      final db = await LocalDb.instance;
      final clean = query.trim();
      final List<Map<String, dynamic>> rows;
      if (clean.isEmpty) {
        rows = await db.query(
          'cards',
          where: 'has_price = 1',
          orderBy: 'price_idr DESC NULLS LAST',
          limit: 30,
        );
      } else {
        rows = await db.query(
          'cards',
          where: 'name LIKE ? OR set_name LIKE ?',
          whereArgs: ['%$clean%', '%$clean%'],
          limit: 30,
        );
      }

      if (mounted) {
        setState(() {
          _catalogSearchResults =
              rows.map((r) => CardModel.fromMap(r)).toList();
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectionState = ref.watch(collectionProvider);
    final collectionCards = collectionState.items
        .map((e) => e.card)
        .whereType<CardModel>()
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pilih Kartu yang Dijual',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            tabs: const [
              Tab(text: 'Koleksi Saya (Jual Kembali)'),
              Tab(text: 'Katalog Dex (Kartu Baru)'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Koleksi Saya
                collectionCards.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Koleksi Anda masih kosong.\nBeli kartu di Marketplace atau deklarasikan kartu baru dari tab Katalog Dex.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: collectionCards.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: AppColors.surfaceHigh),
                        itemBuilder: (ctx, index) {
                          final card = collectionCards[index];
                          return _buildCardTile(card);
                        },
                      ),

                // Tab 2: Katalog Dex
                Column(
                  children: [
                    TextField(
                      controller: _catalogSearchController,
                      onChanged: _searchCatalog,
                      decoration: InputDecoration(
                        hintText: 'Cari nama kartu di katalog...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: AppColors.surfaceHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _isSearching
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.gold),
                            )
                          : _catalogSearchResults.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Tidak ada kartu ditemukan.',
                                    style: TextStyle(
                                        color: AppColors.onSurfaceVariant),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _catalogSearchResults.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(
                                          height: 1,
                                          color: AppColors.surfaceHigh),
                                  itemBuilder: (ctx, index) {
                                    final card =
                                        _catalogSearchResults[index];
                                    return _buildCardTile(card);
                                  },
                                ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTile(CardModel card) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 40,
          height: 56,
          child: card.lowResImageUrl != null
              ? CachedNetworkImage(
                  imageUrl: card.lowResImageUrl!,
                  fit: BoxFit.cover,
                )
              : Container(color: AppColors.surfaceHigh),
        ),
      ),
      title: Text(
        card.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        '${card.setName ?? card.setId ?? ''} · Acuan: ${PriceFormatter.formatIdr(card.priceIdr)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => widget.onCardSelected(card),
    ),
  );
}
}
