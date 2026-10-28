import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../auth/providers/auth_provider.dart';

class WhatsAppDialog extends ConsumerStatefulWidget {
  final String? initialPhone;
  final String? customTitle;
  final String? customExplanation;

  const WhatsAppDialog({
    super.key,
    this.initialPhone,
    this.customTitle,
    this.customExplanation,
  });

  /// Menampilkan dialog secara static
  static Future<String?> show(
    BuildContext context, {
    String? initialPhone,
    String? customTitle,
    String? customExplanation,
  }) {
    return showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (context) => WhatsAppDialog(
        initialPhone: initialPhone,
        customTitle: customTitle,
        customExplanation: customExplanation,
      ),
    );
  }

  @override
  ConsumerState<WhatsAppDialog> createState() => _WhatsAppDialogState();
}

class _WhatsAppDialogState extends ConsumerState<WhatsAppDialog> {
  late final TextEditingController _controller;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final rawText = _controller.text.trim();
    if (rawText.isEmpty) {
      // Menghapus nomor
      _savePhoneNumber(null);
      return;
    }

    final normalized = WhatsAppHelper.normalizePhoneId(rawText);
    if (normalized == null) {
      setState(() {
        _errorMessage =
            'Format nomor tidak valid. Gunakan nomor Indonesia (contoh: 081234567890).';
      });
      return;
    }

    _savePhoneNumber(normalized);
  }

  Future<void> _savePhoneNumber(String? phone) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final savedPhone =
          await ref.read(authProvider.notifier).updateWhatsapp(phone);

      if (!mounted) return;
      Navigator.of(context).pop(savedPhone ?? '');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.surfaceHigh, width: 1),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_android,
              color: AppColors.gold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.customTitle ?? 'Nomor WhatsApp',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.customExplanation ??
                  'Dipakai hanya agar pembeli dan penjual bisa berkoordinasi selama pesanan aktif. Tidak ditampilkan di listing.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
              ],
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Nomor WhatsApp',
                hintText: 'Contoh: 081234567890',
                prefixIcon: const Icon(Icons.chat_outlined, size: 20),
                errorText: _errorMessage,
                errorMaxLines: 2,
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _errorMessage = null);
                        },
                      )
                    : null,
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Format diterima: 08..., +628..., atau 628...',
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.outline,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.initialPhone != null &&
            widget.initialPhone!.trim().isNotEmpty)
          TextButton(
            onPressed: _isLoading ? null : () => _savePhoneNumber(null),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Hapus'),
          ),
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleSave,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.onGold,
            minimumSize: const Size(0, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.onGold),
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

