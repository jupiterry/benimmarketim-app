import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../viewmodels/category_viewmodel.dart';
import '../services/theme_service.dart';
import 'package:go_router/go_router.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: InkWell(
          onTap: () => context.pop(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: Colors.black87,
            ),
          ),
        ),
        title: Text(
          'Kategoriler',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: const CategoryGrid(),
    );
  }
}

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryViewModel>(
      builder: (context, categoryViewModel, child) {
        if (categoryViewModel.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.successGreen),
            ),
          );
        }

        if (categoryViewModel.categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Kategori bulunamadı',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: categoryViewModel.categories.length,
          itemBuilder: (context, index) {
            final category = categoryViewModel.categories[index];
            return _buildCategoryCard(context, category, index);
          },
        );
      },
    );
  }

  Widget _buildCategoryCard(BuildContext context, dynamic category, int index) {
    // Modern pastel renk paleti
    final List<Color> colors = [
      const Color(0xFFE3F2FD), // Blue
      const Color(0xFFF3E5F5), // Purple
      const Color(0xFFE8F5E9), // Green
      const Color(0xFFFFF3E0), // Orange
      const Color(0xFFFFEBEE), // Red
      const Color(0xFFE0F7FA), // Cyan
      const Color(0xFFFFF8E1), // Amber
      const Color(0xFFFCE4EC), // Pink
    ];

    final List<Color> iconColors = [
      const Color(0xFF1565C0),
      const Color(0xFF7B1FA2),
      const Color(0xFF2E7D32),
      const Color(0xFFEF6C00),
      const Color(0xFFC62828),
      const Color(0xFF00838F),
      const Color(0xFFFF8F00),
      const Color(0xFFAD1457),
    ];

    final colorIndex = index % colors.length;
    final bgColor = colors[colorIndex];
    final iconColor = iconColors[colorIndex];

    return GestureDetector(
      onTap: () {
        context.push('/category-products', extra: category);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(
                _getCategoryIcon(category.name),
                color: iconColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                category.name,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'benim kahvem':
        return Icons.coffee_rounded;
      case 'yiyecekler':
        return Icons.restaurant_rounded;
      case 'kahvaltılık ürünler':
        return Icons.egg_alt_rounded;
      case 'temel gıda':
        return Icons.kitchen_rounded;
      case 'meyve & sebze':
        return Icons.apple_rounded;
      case 'süt & süt ürünleri':
        return Icons.water_drop_rounded;
      case 'beş para etmeyen ürünler':
        return Icons.money_off_rounded;
      case 'toz içecekler':
        return Icons.local_cafe_rounded;
      case 'cips & çerez':
        return Icons.cookie_rounded;
      case 'çay ve şekerler':
        return Icons.emoji_food_beverage_rounded;
      case 'atıştırmalıklar':
        return Icons.fastfood_rounded;
      case 'temizlik & hijyen':
        return Icons.cleaning_services_rounded;
      case 'kişisel bakım':
        return Icons.face_rounded;
      case 'makarna ve kuru bakliyat':
        return Icons.grain_rounded;
      case 'şarküteri & et ürünleri':
        return Icons.kebab_dining_rounded;
      case 'buz gibi içecekler':
        return Icons.ac_unit_rounded;
      case 'dondurulmuş gıdalar':
        return Icons.ac_unit_rounded;
      case 'baharatlar':
        return Icons.spa_rounded;
      case 'golf dondurmalar':
        return Icons.icecream_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}
