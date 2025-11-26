/// Test script to simulate startup and detect potential issues
/// This script can be run to check for common startup problems

import 'dart:io';

void main() async {
  print('🔍 Startup Test Script');
  print('=' * 50);
  
  // Test 1: Check if required files exist
  print('\n1. Checking required files...');
  final requiredFiles = [
    'lib/main.dart',
    'ios/Runner/Info.plist',
    'ios/Runner/GoogleService-Info.plist',
    'assets/logo.png',
    'pubspec.yaml',
  ];
  
  for (final file in requiredFiles) {
    final exists = File(file).existsSync();
    print('${exists ? "✅" : "❌"} $file');
    if (!exists && file.contains('GoogleService-Info.plist')) {
      print('   ⚠️  Warning: Firebase config file missing - this may cause startup issues');
    }
  }
  
  // Test 2: Check pubspec.yaml for required dependencies
  print('\n2. Checking dependencies...');
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final requiredDeps = [
    'firebase_core',
    'provider',
    'go_router',
    'dio',
  ];
  
  for (final dep in requiredDeps) {
    final exists = pubspec.contains(dep);
    print('${exists ? "✅" : "❌"} $dep');
  }
  
  // Test 3: Check main.dart for error handling
  print('\n3. Checking error handling in main.dart...');
  final mainDart = File('lib/main.dart').readAsStringSync();
  
  final checks = {
    'WidgetsFlutterBinding.ensureInitialized()': mainDart.contains('WidgetsFlutterBinding.ensureInitialized'),
    'Firebase.initializeApp() with try-catch': mainDart.contains('try') && mainDart.contains('Firebase.initializeApp'),
    'FlutterError.onError handler': mainDart.contains('FlutterError.onError'),
    'ErrorWidget.builder': mainDart.contains('ErrorWidget.builder'),
    'Timeout for version check': mainDart.contains('.timeout'),
  };
  
  for (final entry in checks.entries) {
    print('${entry.value ? "✅" : "❌"} ${entry.key}');
  }
  
  // Test 4: Check Info.plist for ATS settings
  print('\n4. Checking Info.plist configuration...');
  final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
  
  final plistChecks = {
    'NSAppTransportSecurity': infoPlist.contains('NSAppTransportSecurity'),
    'NSExceptionDomains': infoPlist.contains('NSExceptionDomains'),
    'UILaunchStoryboardName': infoPlist.contains('UILaunchStoryboardName'),
  };
  
  for (final entry in plistChecks.entries) {
    print('${entry.value ? "✅" : "❌"} ${entry.key}');
  }
  
  // Test 5: Check router configuration
  print('\n5. Checking router configuration...');
  final router = File('lib/router/app_router.dart').readAsStringSync();
  
  final routerChecks = {
    'initialLocation': router.contains('initialLocation'),
    'errorBuilder': router.contains('errorBuilder'),
    'SplashScreen route': router.contains('SplashScreen'),
  };
  
  for (final entry in routerChecks.entries) {
    print('${entry.value ? "✅" : "❌"} ${entry.key}');
  }
  
  print('\n' + '=' * 50);
  print('✅ Test completed!');
  print('\n💡 Next steps:');
  print('1. Fix any ❌ items above');
  print('2. Run: flutter clean && flutter pub get');
  print('3. Build and test on Codemagic');
}

