import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class BoosterPackArt extends StatefulWidget {
  final String? setId;
  final double currentAcceleration;
  final bool isOpening;
  final VoidCallback onTap;

  const BoosterPackArt({
    super.key,
    this.setId,
    required this.currentAcceleration,
    this.isOpening = false,
    required this.onTap,
  });

  @override
  State<BoosterPackArt> createState() => _BoosterPackArtState();
}

class _BoosterPackArtState extends State<BoosterPackArt>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70), // Frekuensi getaran cepat
    );
  }

  @override
  void didUpdateWidget(covariant BoosterPackArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mounted) return;

    if (widget.isOpening || widget.currentAcceleration > 3.0) {
      if (!_shakeController.isAnimating) {
        _shakeController.repeat(reverse: true);
      }
    } else {
      if (_shakeController.isAnimating && !widget.isOpening) {
        _shakeController.stop();
        _shakeController.reset();
      }
    }
  }

  @override
  void dispose() {
    _shakeController.stop();
    _shakeController.dispose();
    super.dispose();
  }

  // Mendapatkan warna gradien foil sesuai set booster pack
  List<Color> _getSetGradientColors() {
    switch (widget.setId) {
      case 'swsh3': // Darkness Ablaze
        return const [
          Color(0xFF8B0000),
          Color(0xFFFF4500),
          Color(0xFFFFD700),
          Color(0xFF8B0000),
        ];
      case 'swsh7': // Evolving Skies
        return const [
          Color(0xFF0F2027),
          Color(0xFF203A43),
          Color(0xFF2C5364),
          Color(0xFF00C9FF),
        ];
      case 'sv01': // Scarlet & Violet
        return const [
          Color(0xFF93291E),
          Color(0xFFED213A),
          Color(0xFF4A00E0),
          Color(0xFF8E2DE2),
        ];
      case 'sv05': // Temporal Forces
        return const [
          Color(0xFF00416A),
          Color(0xFF00B4DB),
          Color(0xFF00F260),
          Color(0xFF0575E6),
        ];
      default: // HoloDex Gold
        return const [
          Color(0xFF3A2800),
          Color(0xFFB8860B),
          Color(0xFFFFD700),
          Color(0xFF8B6508),
        ];
    }
  }

  String _getSetName() {
    switch (widget.setId) {
      case 'swsh3':
        return 'DARKNESS ABLAZE';
      case 'swsh7':
        return 'EVOLVING SKIES';
      case 'sv01':
        return 'SCARLET & VIOLET';
      case 'sv05':
        return 'TEMPORAL FORCES';
      default:
        return 'HOLODEX MASTER';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rasio booster pack standar (sekitar 1:1.6)
    const packWidth = 230.0;
    const packHeight = 360.0;
    final colors = _getSetGradientColors();

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        if (!_shakeController.isAnimating &&
            !widget.isOpening &&
            widget.currentAcceleration <= 3.0) {
          return child!;
        }

        // Intensitas getaran (0.0 sampai 1.0)
        final intensity = widget.isOpening
            ? 1.0
            : ((widget.currentAcceleration - 2.0) / 12.0).clamp(0.0, 1.0);

        // Gelombang sinus bolak-balik mulai dari 0.0
        final wave = sin(_shakeController.value * pi * 2);

        // Pergeseran horizontal kiri-kanan (hingga 16dp)
        final dx = wave * 16.0 * intensity;

        // Rotasi miring kiri-kanan (hingga ~6 derajat)
        final angle = wave * 0.1 * intensity;

        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: angle,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: packWidth,
          height: packHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: colors[1].withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // Garis gerigi segel atas (Crimped Edge Top)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildCrimpEdge(),
              ),

              // Garis gerigi segel bawah (Crimped Edge Bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildCrimpEdge(),
              ),

              // Efek kilau foil diagonal (Metallic Sheen)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: const Alignment(-0.8, -1.0),
                      end: const Alignment(0.8, 1.0),
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Konten Badge & Desain Pack
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header Logo Pokémon TCG
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.gold,
                              width: 1,
                            ),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.catching_pokemon,
                                    color: AppColors.gold, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'POKÉMON TCG',
                                  style: TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getSetName(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Ikon Pokeball Besar Tengah
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.35),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.catching_pokemon,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    // Bagian Bawah: Jumlah Kartu & Efek Sobek
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '5 ADDITIONAL GAME CARDS',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.vibration,
                                size: 14,
                                color: Colors.white
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.isOpening
                                    ? 'MEMBUKA...'
                                    : 'GOYANGKAN HP UNTUK BUKA',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.8,
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
        ),
      ),
    );
  }

  Widget _buildCrimpEdge() {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1),
          bottom:
              BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          24,
          (index) => Container(
            width: 3,
            color: Colors.black.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
