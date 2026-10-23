import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/models/card_model.dart';
import '../services/gemini_service.dart';

/// Pesan interaksi tanya-jawab dalam sesi AI Advisor
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// Bottom Sheet Interaktif AI Penasihat Kartu (HoloBot)
class AiAdvisorSheet extends StatefulWidget {
  final CardModel card;
  final String? livePriceFormatted;

  const AiAdvisorSheet({
    super.key,
    required this.card,
    this.livePriceFormatted,
  });

  /// Helper untuk menampilkan sheet dengan konfigurasi optimal
  static Future<void> show(
    BuildContext context,
    CardModel card, {
    String? livePriceFormatted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AiAdvisorSheet(
        card: card,
        livePriceFormatted: livePriceFormatted,
      ),
    );
  }

  @override
  State<AiAdvisorSheet> createState() => _AiAdvisorSheetState();
}

class _AiAdvisorSheetState extends State<AiAdvisorSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  bool _isLoading = false;
  String? _errorMessage;

  // Pertanyaan siap pakai (Quick Prompts)
  static const List<String> _quickPrompts = [
    'Apakah harga pasar saat ini wajar?',
    'Layak disimpan untuk koleksi atau dijual?',
    'Jelaskan keistimewaan & kelangkaan kartu ini',
    'Tips perawatan & penyimpanan fisik kartu',
  ];

  @override
  void initState() {
    super.initState();
    // Sambutan awal dari HoloBot
    _messages.add(
      _ChatMessage(
        text: 'Halo Kolektor! Saya HoloBot, analis kartu Pokémon TCG Anda. '
            'Ada yang ingin Anda tanyakan seputar kartu ${widget.card.name}?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submitQuestion(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _inputController.clear();
    setState(() {
      _errorMessage = null;
      _messages.add(
        _ChatMessage(
          text: trimmed,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final answer = await GeminiService.askCardAdvisor(
        card: widget.card,
        question: trimmed,
        livePriceFormatted: widget.livePriceFormatted,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              text: answer,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.gold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HoloBot',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.card.name} · #${widget.card.localId ?? widget.card.id}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Disclaimer Wajib
          Container(
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surfaceHigh),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.info_outline,
                  color: AppColors.goldSoft,
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bukan penasihat keuangan. Estimasi AI berdasarkan data pasar TCGdex & kondisi katalog.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.goldSoft,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.surfaceHigh),

          // Chat Area
          Flexible(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildLoadingBubble();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Error Notification
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),

          // Quick Prompts Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickPrompts.map((prompt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(
                        prompt,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cyan,
                        ),
                      ),
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.surfaceHigh),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onPressed: _isLoading ? null : () => _submitQuestion(prompt),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Input Form Bebas
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    maxLength: 200,
                    style: const TextStyle(fontSize: 13, color: AppColors.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Tanyakan sesuatu tentang kartu ini...',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.surface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: AppColors.surfaceHigh),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: AppColors.surfaceHigh),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: AppColors.gold),
                      ),
                    ),
                    onSubmitted: _submitQuestion,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _isLoading
                      ? null
                      : () => _submitQuestion(_inputController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.surfaceHighest : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(message.isUser ? 14 : 2),
            bottomRight: Radius.circular(message.isUser ? 2 : 14),
          ),
          border: Border.all(
            color: message.isUser
                ? AppColors.gold.withValues(alpha: 0.3)
                : AppColors.surfaceHigh,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!message.isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.auto_awesome, color: AppColors.gold, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'HoloBot',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            _buildFormattedText(
              message.text,
              TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedText(String rawText, TextStyle baseStyle) {
    // Normalisasi bullet markdown dan header jika ada
    final normalized = rawText
        .replaceAll(RegExp(r'^[*-]\s+', multiLine: true), '• ')
        .replaceAll(RegExp(r'#+\s*'), '');

    final spans = <TextSpan>[];
    // Menangkap baik **kata** (bold) maupun *kata* (italic/emphasis)
    final regex = RegExp(r'(\*\*([^*]+)\*\*|\*([^*]+)\*)');
    int lastIndex = 0;

    for (final match in regex.allMatches(normalized)) {
      // Teks biasa sebelum tanda bintang
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: normalized.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }
      // Ambil isi teks tanpa tanda bintang (group 2 untuk **, group 3 untuk *)
      final content = match.group(2) ?? match.group(3) ?? '';
      spans.add(
        TextSpan(
          text: content,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      );
      lastIndex = match.end;
    }

    // Sisa teks setelah kecocokan terakhir
    if (lastIndex < normalized.length) {
      spans.add(
        TextSpan(
          text: normalized.substring(lastIndex),
          style: baseStyle,
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      style: baseStyle,
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(2),
            bottomRight: Radius.circular(14),
          ),
          border: Border.all(color: AppColors.surfaceHigh),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.gold,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'HoloBot sedang menganalisis...',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
