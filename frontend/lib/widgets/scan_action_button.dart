import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/colors.dart';
import '../core/responsive.dart';
import '../providers/pantry_provider.dart';
import '../screens/barcode_scanner_screen.dart';

class ScanActionButton extends ConsumerWidget {
  const ScanActionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final icon = isIOS ? CupertinoIcons.camera : Icons.camera_alt_rounded;

    return FloatingActionButton.extended(
      onPressed: () => _showScanSheet(context, ref),
      icon: Icon(icon),
      label: const Text('Scan Receipt'),
      backgroundColor: AppColors.accentOrange,
      foregroundColor: Colors.white,
    );
  }

  void _showScanSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isIOS = Theme.of(ctx).platform == TargetPlatform.iOS;
        final media = MediaQuery.of(ctx);
        final r = Responsive.of(ctx);
        final topRadius = r.isNarrow ? 24.0 : 32.0;
        return GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: Container(
            color: Colors.black.withOpacity(0.25),
            child: GestureDetector(
              onTap: () {},
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(topRadius),
                    topRight: Radius.circular(topRadius),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(
                        left: r.horizontalPadding,
                        right: r.horizontalPadding,
                        top: r.isNarrow ? 14 : 18,
                        bottom: media.viewInsets.bottom + (r.isNarrow ? 18 : 24),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.creamBackground.withOpacity(0.96),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(topRadius),
                          topRight: Radius.circular(topRadius),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          SizedBox(height: r.isNarrow ? 12 : 16),
                          Row(
                            children: [
                              Icon(
                                isIOS
                                    ? CupertinoIcons.square_stack_3d_down_right
                                    : Icons.kitchen_rounded,
                                color: AppColors.primaryTeal,
                                size: r.isNarrow ? 22 : 26,
                              ),
                              SizedBox(width: r.isNarrow ? 8 : 10),
                              Text(
                                'Add to your pantry',
                                style: r.titleStyle(ctx, fontSize: r.isNarrow ? 17 : 18).copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.charcoalText,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: r.isNarrow ? 2 : 4),
                          Text(
                            'Choose how you want to capture your groceries.',
                            style: r.bodySmallStyle(ctx).copyWith(
                              color: AppColors.charcoalText.withOpacity(0.8),
                            ),
                          ),
                          SizedBox(height: r.isNarrow ? 14 : 18),
                          _ScanOptionTile(
                            icon: isIOS
                                ? CupertinoIcons.camera_viewfinder
                                : Icons.receipt_long_rounded,
                            title: 'Scan Receipt',
                            subtitle:
                                'Fastest way to add many items at once.',
                            isPrimary: true,
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _openCameraAndScanReceipt(ctx, ref);
                            },
                          ),
                          SizedBox(height: r.isNarrow ? 8 : 10),
                          _ScanOptionTile(
                            icon: isIOS
                                ? CupertinoIcons.barcode_viewfinder
                                : Icons.qr_code_scanner_rounded,
                            title: 'Scan Barcode',
                            subtitle: 'Perfect for single packaged items.',
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _openBarcodeScanner(ctx, ref);
                            },
                          ),
                          SizedBox(height: r.isNarrow ? 8 : 10),
                          _ScanOptionTile(
                            icon: isIOS
                                ? CupertinoIcons.pencil
                                : Icons.edit_rounded,
                            title: 'Manually Add Item',
                            subtitle: 'For custom dishes or leftovers.',
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _showManualAddDialog(ctx, ref);
                            },
                          ),
                          SizedBox(height: r.isNarrow ? 8 : 10),
                          _ScanOptionTile(
                            icon: isIOS
                                ? CupertinoIcons.doc_text
                                : Icons.paste_rounded,
                            title: 'Paste receipt text',
                            subtitle: 'Already have OCR text from another app.',
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _showPasteOcrDialog(ctx, ref);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCameraAndScanReceipt(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final userId = ref.read(userIdProvider);
    final notifier = ref.read(pantryNotifierProvider(userId).notifier);

    // On web, camera is not implemented by image_picker; use gallery (file picker) instead.
    final source = kIsWeb ? ImageSource.gallery : ImageSource.camera;
    XFile? photo;
    try {
      photo = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );
    } on PlatformException catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Pick a receipt image from your device, or use "Paste receipt text".'
                : 'Could not open camera. Please allow camera access or use "Paste receipt text".',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    } catch (_) {
      // e.g. MissingPluginException on web when plugin has no implementation
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Use "Paste receipt text" to add items from receipt text, or run the app on a phone for camera scan.'
                : 'Could not open image picker. Try "Paste receipt text" or "Manually Add Item".',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }
    if (photo == null || !context.mounted) return;

    final bytes = await photo.readAsBytes();
    if (bytes.isEmpty || !context.mounted) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanning receipt…'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    await notifier.addItemsFromReceiptImageBytes(bytes);

    if (!context.mounted) return;
    final pantryState = ref.read(pantryNotifierProvider(userId));
    if (pantryState.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pantryState.errorMessage!),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt scanned. Items added to your pantry.'),
        ),
      );
    }
  }

  Future<void> _openBarcodeScanner(BuildContext context, WidgetRef ref) async {
    // Barcode scanner uses native camera; not fully supported on web (MissingPluginException).
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Barcode scan is available on iOS and Android. On web, use "Manually Add Item" or "Paste receipt text".',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute<String?>(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );
    if (!context.mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "$result" to your pantry.'),
        ),
      );
    } else {
      final userId = ref.read(userIdProvider);
      final pantryState = ref.read(pantryNotifierProvider(userId));
      if (pantryState.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pantryState.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}

class _ScanOptionTile extends StatelessWidget {
  const _ScanOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final radius = r.isNarrow ? 18.0 : 24.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.isNarrow ? 12 : 14,
            vertical: r.isNarrow ? 10 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isPrimary
                  ? [
                      AppColors.primaryTeal.withOpacity(0.18),
                      AppColors.primaryTeal.withOpacity(0.08),
                    ]
                  : [
                      AppColors.primaryTeal.withOpacity(0.12),
                      AppColors.primaryTeal.withOpacity(0.04),
                    ],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(r.isNarrow ? 8 : 10),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? AppColors.primaryTeal
                      : AppColors.primaryTeal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(r.isNarrow ? 14 : 18),
                ),
                child: Icon(
                  icon,
                  size: r.isNarrow ? 20 : 22,
                  color: isPrimary
                      ? Colors.white
                      : AppColors.primaryTeal,
                ),
              ),
              SizedBox(width: r.isNarrow ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: r.bodyStyle(context, fontSize: r.isNarrow ? 14 : 16).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoalText,
                      ),
                    ),
                    SizedBox(height: r.isNarrow ? 1 : 2),
                    Text(
                      subtitle,
                      style: r.bodySmallStyle(context).copyWith(
                        color: AppColors.charcoalText.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: r.isNarrow ? 4 : 6),
              Icon(
                isIOS ? CupertinoIcons.chevron_right : Icons.chevron_right_rounded,
                size: r.isNarrow ? 20 : 24,
                color: AppColors.charcoalText.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showPasteOcrDialog(BuildContext context, WidgetRef ref) async {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController();
  final userId = ref.read(userIdProvider);
  final notifier = ref.read(pantryNotifierProvider(userId).notifier);
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final r = Responsive.of(ctx);
      final inputDecoration = InputDecoration(
        labelStyle: TextStyle(color: AppColors.charcoalText.withOpacity(0.8)),
        hintStyle: TextStyle(color: AppColors.charcoalText.withOpacity(0.5)),
        filled: true,
        fillColor: AppColors.creamBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.isNarrow ? 14 : 16),
          borderSide: BorderSide(color: AppColors.primaryTeal.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.isNarrow ? 14 : 16),
          borderSide: BorderSide(color: AppColors.primaryTeal.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.isNarrow ? 14 : 16),
          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.isNarrow ? 14 : 16),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: r.isNarrow ? 14 : 16,
          vertical: r.isNarrow ? 12 : 14,
        ),
        alignLabelWithHint: true,
      );
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: r.isNarrow ? 380 : 420,
          ),
          decoration: BoxDecoration(
            color: AppColors.creamBackground,
            borderRadius: BorderRadius.circular(r.isNarrow ? 20 : 24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                r.horizontalPadding + 8,
                r.isNarrow ? 16 : 20,
                r.horizontalPadding + 8,
                r.isNarrow ? 18 : 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(r.isNarrow ? 8 : 10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(r.isNarrow ? 12 : 14),
                          ),
                          child: Icon(
                            isIOS ? CupertinoIcons.doc_text : Icons.receipt_long_rounded,
                            color: AppColors.primaryTeal,
                            size: r.isNarrow ? 24 : 28,
                          ),
                        ),
                        SizedBox(width: r.isNarrow ? 12 : 14),
                        Expanded(
                          child: Text(
                            'Paste receipt text',
                            style: r.titleStyle(ctx, fontSize: r.isNarrow ? 18 : 20).copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoalText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.isNarrow ? 6 : 8),
                    Text(
                      'Paste raw receipt or OCR text below. We\'ll extract items and add them to your pantry.',
                      style: r.bodySmallStyle(ctx).copyWith(
                        color: AppColors.charcoalText.withOpacity(0.7),
                      ),
                    ),
                    SizedBox(height: r.isNarrow ? 16 : 20),
                    TextFormField(
                      controller: controller,
                      maxLines: 6,
                      minLines: 4,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: inputDecoration.copyWith(
                        labelText: 'Receipt text',
                        hintText: 'Paste raw receipt text here…\n\n(e.g. from a scanner app or photo OCR)',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Paste some receipt text to continue';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: r.isNarrow ? 18 : 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.charcoalText.withOpacity(0.8),
                          ),
                          child: Text('Cancel', style: r.bodyStyle(ctx, fontSize: 14)),
                        ),
                        SizedBox(width: r.isNarrow ? 8 : 12),
                        FilledButton(
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              Navigator.of(ctx).pop(controller.text);
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: r.isNarrow ? 18 : 24,
                              vertical: r.isNarrow ? 10 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(r.isNarrow ? 12 : 14),
                            ),
                          ),
                          child: Text('Process receipt', style: r.bodyStyle(ctx, fontSize: 14).copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  if (result != null && result.trim().isNotEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing receipt…'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }

    await notifier.addItemsFromReceipt(result.trim());

    if (!context.mounted) return;
    final pantryState = ref.read(pantryNotifierProvider(userId));
    if (pantryState.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pantryState.errorMessage!),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt processed. Items added to your pantry.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

Future<void> _showManualAddDialog(BuildContext context, WidgetRef ref) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  final expiryHolder = <DateTime?>[null];

  final userId = ref.read(userIdProvider);
  final api = ref.read(pantryApiProvider);
  final notifier = ref.read(pantryNotifierProvider(userId).notifier);
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final r = Responsive.of(ctx);
          final selectedExpiry = expiryHolder[0];
          final inputDecoration = InputDecoration(
        labelStyle: TextStyle(color: AppColors.charcoalText.withOpacity(0.8)),
        hintStyle: TextStyle(color: AppColors.charcoalText.withOpacity(0.5)),
        filled: true,
        fillColor: AppColors.creamBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.isNarrow ? 14 : 16),
          borderSide: BorderSide(color: AppColors.primaryTeal.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.isNarrow ? 14 : 16),
          borderSide: BorderSide(color: AppColors.primaryTeal.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.isNarrow ? 14 : 16),
          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.isNarrow ? 14 : 16),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: r.isNarrow ? 14 : 16,
          vertical: r.isNarrow ? 12 : 14,
        ),
      );
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: AppColors.creamBackground,
            borderRadius: BorderRadius.circular(r.isNarrow ? 20 : 24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                r.horizontalPadding + 8,
                r.isNarrow ? 16 : 20,
                r.horizontalPadding + 8,
                r.isNarrow ? 18 : 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(r.isNarrow ? 8 : 10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(r.isNarrow ? 12 : 14),
                          ),
                          child: Icon(
                            isIOS ? CupertinoIcons.add_circled : Icons.add_circle_outline_rounded,
                            color: AppColors.primaryTeal,
                            size: r.isNarrow ? 24 : 28,
                          ),
                        ),
                        SizedBox(width: r.isNarrow ? 12 : 14),
                        Expanded(
                          child: Text(
                            'Add item to pantry',
                            style: r.titleStyle(ctx, fontSize: r.isNarrow ? 18 : 20).copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoalText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.isNarrow ? 18 : 24),
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: inputDecoration.copyWith(
                        labelText: 'Item name',
                        hintText: 'e.g. Milk, Eggs, Bread',
                        prefixIcon: Icon(
                          Icons.shopping_basket_outlined,
                          color: AppColors.primaryTeal.withOpacity(0.7),
                          size: r.isNarrow ? 20 : 22,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter an item name';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => FocusScope.of(ctx).nextFocus(),
                    ),
                    SizedBox(height: r.isNarrow ? 12 : 16),
                    TextFormField(
                      controller: categoryController,
                      textCapitalization: TextCapitalization.words,
                      decoration: inputDecoration.copyWith(
                        labelText: 'Category (optional)',
                        hintText: 'e.g. Dairy, Produce',
                        prefixIcon: Icon(
                          Icons.category_outlined,
                          color: AppColors.primaryTeal.withOpacity(0.5),
                          size: r.isNarrow ? 20 : 22,
                        ),
                      ),
                      onFieldSubmitted: (_) => FocusScope.of(ctx).nextFocus(),
                    ),
                    SizedBox(height: r.isNarrow ? 12 : 16),
                    // Expiry date & time (optional)
                    Padding(
                      padding: EdgeInsets.only(bottom: r.isNarrow ? 2 : 4),
                      child: Text(
                        'Expiry date & time (optional)',
                        style: r.labelStyle(ctx).copyWith(
                          color: AppColors.charcoalText.withOpacity(0.8),
                        ),
                      ),
                    ),
                    SizedBox(height: r.isNarrow ? 4 : 6),
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: selectedExpiry ?? now.add(const Duration(days: 7)),
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365 * 2)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppColors.primaryTeal,
                                  onPrimary: Colors.white,
                                  surface: AppColors.creamBackground,
                                  onSurface: AppColors.charcoalText,
                                ),
                              ),
                              child: child ?? const SizedBox.shrink(),
                            );
                          },
                        );
                        if (date == null || !ctx.mounted) return;
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: selectedExpiry != null
                              ? TimeOfDay.fromDateTime(selectedExpiry)
                              : const TimeOfDay(hour: 12, minute: 0),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppColors.primaryTeal,
                                  onPrimary: Colors.white,
                                  surface: AppColors.creamBackground,
                                  onSurface: AppColors.charcoalText,
                                ),
                              ),
                              child: child ?? const SizedBox.shrink(),
                            );
                          },
                        );
                        if (time == null || !ctx.mounted) return;
                        expiryHolder[0] = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                        setDialogState(() {});
                      },
                      borderRadius: BorderRadius.circular(r.isNarrow ? 14 : 16),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: r.isNarrow ? 14 : 16,
                          vertical: r.isNarrow ? 12 : 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.creamBackground,
                          borderRadius: BorderRadius.circular(r.isNarrow ? 14 : 16),
                          border: Border.all(
                            color: AppColors.primaryTeal.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: AppColors.primaryTeal.withOpacity(0.7),
                              size: r.isNarrow ? 20 : 22,
                            ),
                            SizedBox(width: r.isNarrow ? 10 : 12),
                            Expanded(
                              child: Text(
                                selectedExpiry != null
                                    ? '${DateFormat.yMMMd().format(selectedExpiry)}, ${DateFormat.jm().format(selectedExpiry)}'
                                    : 'Tap to set date and time',
                                style: r.bodyStyle(ctx).copyWith(
                                  color: selectedExpiry != null
                                      ? AppColors.charcoalText
                                      : AppColors.charcoalText.withOpacity(0.5),
                                ),
                              ),
                            ),
                            if (selectedExpiry != null)
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: r.isNarrow ? 18 : 20,
                                  color: AppColors.charcoalText.withOpacity(0.6),
                                ),
                                onPressed: () {
                                  expiryHolder[0] = null;
                                  setDialogState(() {});
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: r.isNarrow ? 22 : 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.charcoalText.withOpacity(0.8),
                          ),
                          child: Text('Cancel', style: r.bodyStyle(ctx, fontSize: 14)),
                        ),
                        SizedBox(width: r.isNarrow ? 8 : 12),
                        FilledButton(
                          onPressed: () {
                            if (formKey.currentState?.validate() ?? false) {
                              Navigator.of(ctx).pop(true);
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: r.isNarrow ? 18 : 24,
                              vertical: r.isNarrow ? 10 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(r.isNarrow ? 12 : 14),
                            ),
                          ),
                          child: Text('Add to pantry', style: r.bodyStyle(ctx, fontSize: 14).copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
        },
      );
    },
  );

  if (result != true) return;

  final name = nameController.text.trim();
  if (name.isEmpty) return;

  final category = categoryController.text.trim().isEmpty
      ? null
      : categoryController.text.trim();
  final expiry = expiryHolder[0];

  try {
    await api.createPantryItem(
      userId: userId,
      itemName: name,
      category: category,
      expiryDate: expiry,
    );
    await notifier.loadPantry();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "$name" to your pantry.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add item. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}



