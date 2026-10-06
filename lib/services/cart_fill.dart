import '../models/product.dart';
import '../viewmodels/cart_viewmodel.dart';
import 'api_service.dart';
import 'app_logger.dart';

/// Sepete topluca eklenecek bir kalem (asistan önerisi, eski sipariş ya da
/// favori sepet satırı).
class CartFillItem {
  /// Ürün silinmişse veya eski kayıtlarda boş olabilir.
  final String? productId;
  final String name;
  final int quantity;

  const CartFillItem({
    required this.productId,
    required this.name,
    required this.quantity,
  });
}

class CartFillResult {
  final int added;
  final int skipped;

  const CartFillResult({required this.added, required this.skipped});
}

/// Kalemlerin güncel halini (fiyat, stok) sunucudan alıp sepete ekler.
/// Stokta olmayan ya da artık satılmayan ürünler atlanır; hata fırlatmaz.
Future<CartFillResult> addItemsToCart(
  CartViewModel cart,
  List<CartFillItem> items,
) async {
  final api = ApiService();
  var added = 0;
  var skipped = 0;

  for (final item in items) {
    final product = await _currentProduct(api, item);
    if (product == null || product.isOutOfStock || product.isHidden) {
      skipped++;
      continue;
    }
    final quantity = item.quantity < 1 ? 1 : (item.quantity > 20 ? 20 : item.quantity);
    cart.addQuantity(product, quantity);
    added++;
  }
  return CartFillResult(added: added, skipped: skipped);
}

Future<Product?> _currentProduct(ApiService api, CartFillItem item) async {
  try {
    final id = item.productId;
    if (id != null && id.isNotEmpty) return await api.getProductById(id);

    // Eski kayıtlarda ürün ID'si yoksa yalnızca adı birebir eşleşen ürün
    // kabul edilir; benzer adlı farklı bir ürün sepete girmez.
    final wanted = item.name.trim().toLowerCase();
    if (wanted.isEmpty) return null;
    final result = await api.searchProducts(query: item.name);
    for (final product in result.products) {
      if (product.name.trim().toLowerCase() == wanted) return product;
    }
    return null;
  } catch (e) {
    AppLogger.debug('Sepete ekleme: ürün alınamadı (${item.name}): $e');
    return null;
  }
}

/// Toplu ekleme sonucunu müşteriye anlatan kısa metin.
String cartFillMessage(CartFillResult result) => result.skipped == 0
    ? '${result.added} ürün sepete eklendi'
    : '${result.added} ürün sepete eklendi, ${result.skipped} ürün şu an satışta değil';
