import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/cart_item.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'benimmarketim.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Cart Table
    await db.execute('''
      CREATE TABLE cart_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        product_json TEXT NOT NULL
      )
    ''');

    // Favorites Table
    await db.execute('''
      CREATE TABLE favorites(
        product_id TEXT PRIMARY KEY,
        product_json TEXT NOT NULL
      )
    ''');
  }

  // --- Cart Operations ---

  Future<void> addToCart(CartItem item) async {
    final db = await database;

    // Check if item already exists
    final List<Map<String, dynamic>> maps = await db.query(
      'cart_items',
      where: 'product_id = ?',
      whereArgs: [item.product.id],
    );

    if (maps.isNotEmpty) {
      // Update quantity
      final currentQuantity = maps.first['quantity'] as int;
      await db.update(
        'cart_items',
        {'quantity': currentQuantity + item.quantity},
        where: 'product_id = ?',
        whereArgs: [item.product.id],
      );
    } else {
      // Insert new item
      await db.insert(
          'cart_items',
          {
            'product_id': item.product.id,
            'quantity': item.quantity,
            'product_json': jsonEncode(item.product.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> updateCartItemQuantity(String productId, int quantity) async {
    final db = await database;
    if (quantity <= 0) {
      await removeFromCart(productId);
    } else {
      await db.update(
        'cart_items',
        {'quantity': quantity},
        where: 'product_id = ?',
        whereArgs: [productId],
      );
    }
  }

  Future<void> saveCartItem(CartItem item) async {
    final db = await database;
    await db.update(
      'cart_items',
      {
        'quantity': item.quantity,
        'product_json': jsonEncode(item.product.toJson()),
      },
      where: 'product_id = ?',
      whereArgs: [item.product.id],
    );
  }

  Future<void> removeFromCart(String productId) async {
    final db = await database;
    await db.delete(
      'cart_items',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  Future<void> clearCart() async {
    final db = await database;
    await db.delete('cart_items');
  }

  Future<List<CartItem>> getCartItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cart_items');

    return List.generate(maps.length, (i) {
      final productJson = jsonDecode(maps[i]['product_json']);
      final product = Product.fromJson(productJson);
      return CartItem(product: product, quantity: maps[i]['quantity']);
    });
  }

  // --- Favorites Operations ---

  Future<void> addToFavorites(Product product) async {
    final db = await database;
    await db.insert(
        'favorites',
        {
          'product_id': product.id,
          'product_json': jsonEncode(product.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFromFavorites(String productId) async {
    final db = await database;
    await db.delete(
      'favorites',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  Future<bool> isFavorite(String productId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorites',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    return maps.isNotEmpty;
  }

  Future<List<Product>> getFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('favorites');

    return List.generate(maps.length, (i) {
      final productJson = jsonDecode(maps[i]['product_json']);
      return Product.fromJson(productJson);
    });
  }

  Future<void> clearFavorites() async {
    final db = await database;
    await db.delete('favorites');
  }
}
