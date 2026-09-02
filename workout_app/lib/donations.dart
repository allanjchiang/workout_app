import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'l10n/app_localizations.dart';

/// Product IDs for optional, no-reward "tip" purchases. These are
/// consumable (repeatable) so a user can support the app again on a future
/// update. They must be created with these exact identifiers as Consumable
/// in-app products in both App Store Connect and the Google Play Console
/// before real purchases will succeed; until then the sheet reports that
/// support options aren't available yet instead of erroring.
const List<String> kDonationProductIds = [
  'dev_donation_small',
  'dev_donation_medium',
  'dev_donation_large',
];

String _donationTierLabel(AppLocalizations l10n, String productId) {
  switch (productId) {
    case 'dev_donation_small':
      return l10n.get('donationTierSmall');
    case 'dev_donation_medium':
      return l10n.get('donationTierMedium');
    case 'dev_donation_large':
      return l10n.get('donationTierLarge');
    default:
      return productId;
  }
}

/// Opens the "support the developer" bottom sheet with a few fixed tip
/// tiers, priced and localized by the store. Purely voluntary — purchasing
/// doesn't unlock anything in the app.
Future<void> showDonationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _DonationSheet(),
  );
}

class _DonationSheet extends StatefulWidget {
  const _DonationSheet();

  @override
  State<_DonationSheet> createState() => _DonationSheetState();
}

class _DonationSheetState extends State<_DonationSheet> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _storeAvailable = false;
  bool _loading = true;
  String? _purchasingId;

  @override
  void initState() {
    super.initState();
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (_) {},
    );
    unawaited(_init());
  }

  Future<void> _init() async {
    final available = await _iap.isAvailable();
    if (!mounted) return;
    if (!available) {
      setState(() {
        _storeAvailable = false;
        _loading = false;
      });
      return;
    }
    final response = await _iap.queryProductDetails(
      kDonationProductIds.toSet(),
    );
    if (!mounted) return;
    final products = response.productDetails.toList()
      ..sort(
        (a, b) => kDonationProductIds
            .indexOf(a.id)
            .compareTo(kDonationProductIds.indexOf(b.id)),
      );
    setState(() {
      _storeAvailable = true;
      _products = products;
      _loading = false;
    });
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!kDonationProductIds.contains(purchase.productID)) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          if (mounted) {
            setState(() => _purchasingId = null);
            _showMessage(AppLocalizations.of(context)!.get('donationFailed'));
          }
          break;
        case PurchaseStatus.canceled:
          if (mounted) setState(() => _purchasingId = null);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (mounted) {
            setState(() => _purchasingId = null);
            _showMessage(
              AppLocalizations.of(context)!.get('donationThankYou'),
            );
            Navigator.of(context).maybePop();
          }
          break;
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  void _showMessage(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _buy(ProductDetails product) async {
    setState(() => _purchasingId = product.id);
    final param = PurchaseParam(productDetails: product);
    try {
      await _iap.buyConsumable(purchaseParam: param);
    } catch (_) {
      if (mounted) {
        setState(() => _purchasingId = null);
        _showMessage(AppLocalizations.of(context)!.get('donationFailed'));
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final mutedTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2A3A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l10n.get('supportDeveloper'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.get('supportDeveloperSubtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: mutedTextColor),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!_storeAvailable)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.get('donationUnavailable'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: mutedTextColor),
                ),
              )
            else if (_products.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.get('donationNoProducts'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: mutedTextColor),
                ),
              )
            else
              for (final product in _products) ...[
                _DonationTierButton(
                  label: _donationTierLabel(l10n, product.id),
                  price: product.price,
                  loading: _purchasingId == product.id,
                  enabled: _purchasingId == null,
                  color: colorScheme.primary,
                  onTap: () => _buy(product),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _DonationTierButton extends StatelessWidget {
  final String label;
  final String price;
  final bool loading;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _DonationTierButton({
    required this.label,
    required this.price,
    required this.loading,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: loading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
    );
  }
}
