import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/category.dart' as models;

class CategoryCard extends StatelessWidget {
  final models.Category category;
  final VoidCallback? onTap;

  const CategoryCard({
    super.key,
    required this.category,
    this.onTap,
  });

  IconData _getIconFromString(String? iconName) {
    switch (iconName) {
      case 'eco':
        return Icons.eco;
      case 'restaurant':
        return Icons.restaurant;
      case 'apple':
        return Icons.apple;
      case 'local_drink':
        return Icons.local_drink;
      case 'set_meal':
        return Icons.set_meal;
      case 'ice_cream':
        return Icons.icecream;
      case 'fastfood':
        return Icons.fastfood;
      case 'cookie':
        return Icons.cookie;
      case 'coffee':
        return Icons.coffee;
      case 'ramen_dining':
        return Icons.ramen_dining;
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'face':
        return Icons.face;
      case 'spa':
        return Icons.spa;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'coffee_maker':
        return Icons.coffee_maker;
      case 'savings':
        return Icons.savings;
      case 'breakfast_dining':
        return Icons.breakfast_dining;
      default:
        return Icons.category;
    }
  }

  Color _getColorFromIndex(int index) {
    final colors = [
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.blue,
      Colors.teal,
      Colors.purple,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getIconFromString(category.icon);
    final color = _getColorFromIndex(category.name.hashCode);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}