import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../providers/search_provider.dart';

class FilterBottomSheet extends StatefulWidget {
  final SearchState currentState;
  final Function({
    String? setId,
    String? rarity,
    double? minPrice,
    double? maxPrice,
  }) onApply;
  final VoidCallback onReset;

  const FilterBottomSheet({
    super.key,
    required this.currentState,
    required this.onApply,
    required this.onReset,
  });

  static Future<void> show(
    BuildContext context, {
    required SearchState currentState,
    required Function({
      String? setId,
      String? rarity,
      double? minPrice,
      double? maxPrice,
    }) onApply,
    required VoidCallback onReset,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLow,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FilterBottomSheet(
        currentState: currentState,
        onApply: onApply,
        onReset: onReset,
      ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String? _selectedSetId;
  String? _selectedRarity;
  double? _minPrice;
  double? _maxPrice;

  // Presets harga IDR
  final List<Map<String, dynamic>> _pricePresets = const [
    {
      'label': 'Semua',
      'min': null,
      'max': null,
    },
    {
      'label': '< Rp 50.000',
      'min': null,
      'max': 50000.0,
    },
    {
      'label': 'Rp 50rb – 250rb',
      'min': 50000.0,
      'max': 250000.0,
    },
    {
      'label': 'Rp 250rb – 1 Jt',
      'min': 250000.0,
      'max': 1000000.0,
    },
    {
      'label': '> Rp 1.000.000',
      'min': 1000000.0,
      'max': null,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedSetId = widget.currentState.selectedSetId;
    _selectedRarity = widget.currentState.selectedRarity;
    _minPrice = widget.currentState.minPrice;
    _maxPrice = widget.currentState.maxPrice;
  }

  bool _isPresetSelected(double? min, double? max) {
    if (min == null && max == null) {
      return _minPrice == null && _maxPrice == null;
    }
    return _minPrice == min && _maxPrice == max;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune, color: AppColors.gold, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Filter Katalog',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedSetId = null;
                          _selectedRarity = null;
                          _minPrice = null;
                          _maxPrice = null;
                        });
                        widget.onReset();
                      },
                      child: const Text(
                        'Reset Semua',
                        style: TextStyle(
                          color: AppColors.goldSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.surfaceHigh, height: 1),

              // Filter Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // Section 1: Set / Seri
                    _buildSectionHeader('Set / Seri Kartu'),
                    const SizedBox(height: 10),
                    if (widget.currentState.availableSets.isEmpty)
                      const Text(
                        'Memuat data set...',
                        style: TextStyle(fontSize: 12, color: AppColors.outline),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.currentState.availableSets.map((set) {
                          final setId = set['id']!;
                          final setName = set['name']!;
                          final isSelected = _selectedSetId == setId;

                          return FilterChip(
                            label: Text(
                              setName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.onGold
                                    : AppColors.onSurface,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.gold,
                            backgroundColor: AppColors.surface,
                            checkmarkColor: AppColors.onGold,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.gold
                                  : AppColors.surfaceHigh,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            onSelected: (selected) {
                              setState(() {
                                _selectedSetId = selected ? setId : null;
                              });
                            },
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 24),

                    // Section 2: Kelangkaan / Rarity
                    _buildSectionHeader('Kelangkaan (Rarity)'),
                    const SizedBox(height: 10),
                    if (widget.currentState.availableRarities.isEmpty)
                      const Text(
                        'Memuat data kelangkaan...',
                        style: TextStyle(fontSize: 12, color: AppColors.outline),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.currentState.availableRarities.map((r) {
                          final isSelected = _selectedRarity == r;

                          return FilterChip(
                            label: Text(
                              r,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.onGold
                                    : AppColors.onSurface,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.gold,
                            backgroundColor: AppColors.surface,
                            checkmarkColor: AppColors.onGold,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.gold
                                  : AppColors.surfaceHigh,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            onSelected: (selected) {
                              setState(() {
                                _selectedRarity = selected ? r : null;
                              });
                            },
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 24),

                    // Section 3: Rentang Harga
                    _buildSectionHeader('Rentang Harga (IDR)'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _pricePresets.map((preset) {
                        final isSelected = _isPresetSelected(
                          preset['min'] as double?,
                          preset['max'] as double?,
                        );

                        return ChoiceChip(
                          label: Text(
                            preset['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.onGold
                                  : AppColors.onSurface,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.gold,
                          backgroundColor: AppColors.surface,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.gold
                                : AppColors.surfaceHigh,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _minPrice = preset['min'] as double?;
                                _maxPrice = preset['max'] as double?;
                              } else {
                                _minPrice = null;
                                _maxPrice = null;
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),

              // Bottom Apply Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLowest,
                  border: Border(
                    top: BorderSide(color: AppColors.surfaceHigh, width: 1),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.onGold,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        widget.onApply(
                          setId: _selectedSetId,
                          rarity: _selectedRarity,
                          minPrice: _minPrice,
                          maxPrice: _maxPrice,
                        );
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Terapkan Filter',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfaceVariant,
        letterSpacing: 0.3,
      ),
    );
  }
}
