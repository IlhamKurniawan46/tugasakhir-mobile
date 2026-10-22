import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/database/local_db.dart';
import '../../../core/models/card_model.dart';
import '../../../core/services/marketplace_repository.dart';
import '../../../core/utils/price_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/collection_provider.dart';
import '../providers/marketplace_provider.dart';

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
  double _lat = -6.2088;
  double _lng = 106.8456;
  bool _isSubmitting = false;

  final Map<String, ({double lat, double lng})> _cities = {
    'Jakarta Pusat': (lat: -6.2088, lng: 106.8456),
    'Jakarta Selatan': (lat: -6.2615, lng: 106.8106),
    'Bandung': (lat: -6.9175, lng: 107.6191),
    'Surabaya': (lat: -7.2575, lng: 112.7521),
    'Yogyakarta': (lat: -7.7956, lng: 110.3695),
  };

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
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kartu Pokémon yang ingin dijual terlebih dahulu.'),
          backgroundColor: AppColors.error,
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
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await MarketplaceRepository.createListing(
        cardId: _selectedCard!.id,
        sellerId: user.id,
        priceIdr: price,
        condition: _condition,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        lat: _lat,
        lng: _lng,
      );

      // Refresh data marketplace
      await ref.read(marketplaceProvider.notifier).loadListings(forceRefresh: true);

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing kartu berhasil dipasang di Pasar!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat listing: $e'),
            backgroundColor: AppColors.error,
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

            // Lokasi Kota COD
            Text(
              'Lokasi Penjual (COD / Pengiriman)',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceHigh),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCity,
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  items: _cities.keys.map((city) {
                    return DropdownMenuItem(
                      value: city,
                      child: Text(city),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCity = val;
                        final coords = _cities[val]!;
                        _lat = coords.lat;
                        _lng = coords.lng;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Deskripsi / Catatan Penjual
            Text(
              'Deskripsi / Catatan Kondisi (Opsional)',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitListing,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Pasang Listing ke Pasar',
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
                            'Koleksi Anda masih kosong.\nBeli kartu di pasar atau deklarasikan kartu baru dari tab Katalog Dex.',
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
    return ListTile(
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
    );
  }
}
