import 'package:cloud_firestore/cloud_firestore.dart';

class ShopSettings {
  const ShopSettings({
    required this.enableWishlist,
    required this.maxCartItems,
    required this.maxCheckoutQuantityPerItem,
  });

  final bool enableWishlist;
  final int maxCartItems;
  final int maxCheckoutQuantityPerItem;

  factory ShopSettings.fromMap(Map<String, dynamic> data) {
    return ShopSettings(
      enableWishlist: data['enableWishlist'] is bool
          ? data['enableWishlist'] as bool
          : true,
      maxCartItems: _toSafeInt(data['maxCartItems'], fallback: 50),
      maxCheckoutQuantityPerItem: _toSafeInt(
        data['maxCheckoutQuantityPerItem'],
        fallback: 10,
      ),
    );
  }

  static int _toSafeInt(dynamic value, {required int fallback}) {
    final int parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? fallback;
    return parsed <= 0 ? fallback : parsed;
  }
}

class ShopSettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<ShopSettings> settingsStream() {
    return _firestore
        .collection('app_config')
        .doc('shop')
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
          return ShopSettings.fromMap(
            snapshot.data() ?? const <String, dynamic>{},
          );
        });
  }
}
