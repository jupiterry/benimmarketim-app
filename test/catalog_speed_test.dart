import 'package:benimmarketim_app/models/home_feed.dart';
import 'package:benimmarketim_app/services/image_url.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> product(String id, {bool hidden = false}) => {
      '_id': id,
      'name': 'Ürün $id',
      'price': 10,
      'category': 'atistirma',
      'isHidden': hidden,
      'createdAt': '2026-09-01T10:00:00Z',
      'updatedAt': '2026-09-01T10:00:00Z',
    };

void main() {
  group('optimizedImageUrl', () {
    const original =
        'https://res.cloudinary.com/demo/image/upload/v1741390148/products/a.png';

    test('Cloudinary adresine boyut ve WebP dönüşümü eklenir', () {
      expect(
        optimizedImageUrl(original, width: 400),
        'https://res.cloudinary.com/demo/image/upload/w_400,c_limit,f_webp,q_auto/v1741390148/products/a.png',
      );
    });

    test('zaten dönüşüm varsa dokunulmaz', () {
      const transformed =
          'https://res.cloudinary.com/demo/image/upload/w_300,c_fill/v1/a.png';
      expect(optimizedImageUrl(transformed, width: 400), transformed);
    });

    test('Cloudinary dışı ve boş adresler değişmez', () {
      expect(optimizedImageUrl('https://example.com/a.png', width: 400),
          'https://example.com/a.png');
      expect(optimizedImageUrl('', width: 400), '');
    });
  });

  group('HomeFeed', () {
    test('raflar okunur, gizli ürünler atlanır', () {
      final feed = HomeFeed.fromJson({
        'success': true,
        'shelves': {
          'deals': {
            'products': [product('d1'), product('d2', hidden: true)],
          },
          'forYou': {
            'strategy': 'personal',
            'products': [product('f1')],
          },
          'popular': {
            'products': [product('p1')],
          },
        },
      });
      expect(feed.deals.map((p) => p.id), ['d1']);
      expect(feed.forYou.map((p) => p.id), ['f1']);
      expect(feed.popular.map((p) => p.id), ['p1']);
      expect(feed.isPersonal, isTrue);
    });

    test('önbelleğe yazılan hal aynen geri okunur', () {
      final feed = HomeFeed.fromJson({
        'shelves': {
          'forYou': {
            'strategy': 'popular',
            'products': [product('f1')],
          },
        },
      });
      final restored = HomeFeed.fromJson(feed.toJson());
      expect(restored.forYou.single.id, 'f1');
      expect(restored.strategy, 'popular');
    });
  });
}
