#!/usr/bin/env python3
"""
iOS App Icon Alpha Channel Remover
Bu script, PNG dosyasındaki alfa kanalını kaldırır ve opak bir arka plan ekler.
"""

import sys
from PIL import Image
import os

def remove_alpha_channel(input_path, output_path=None, background_color=(255, 255, 255)):
    """
    PNG dosyasındaki alfa kanalını kaldırır ve opak arka plan ekler.
    
    Args:
        input_path: Giriş PNG dosyası yolu
        output_path: Çıkış PNG dosyası yolu (None ise giriş dosyasının üzerine yazar)
        background_color: Arka plan rengi (RGB tuple, varsayılan: beyaz)
    """
    if output_path is None:
        output_path = input_path
    
    try:
        # Görüntüyü aç
        img = Image.open(input_path)
        
        # RGBA modundaysa RGB'ye dönüştür
        if img.mode == 'RGBA':
            # Yeni bir RGB görüntü oluştur
            rgb_img = Image.new('RGB', img.size, background_color)
            # Orijinal görüntüyü arka plan üzerine yapıştır
            rgb_img.paste(img, mask=img.split()[3])  # Alpha kanalını mask olarak kullan
            img = rgb_img
        elif img.mode != 'RGB':
            # Diğer modları RGB'ye dönüştür
            img = img.convert('RGB')
        
        # Alfa kanalı olmadan kaydet
        img.save(output_path, 'PNG', optimize=True)
        print(f"[OK] Alfa kanali kaldirildi: {output_path}")
        return True
        
    except Exception as e:
        print(f"[HATA] Hata: {e}")
        return False

def main():
    # Kaynak simge dosyası
    source_icon = "assets/logo.png"
    
    # iOS 1024x1024 simge dosyası
    ios_icon_1024 = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
    
    print("iOS App Icon Alpha Channel Remover")
    print("=" * 50)
    
    # Kaynak simgeyi düzelt
    if os.path.exists(source_icon):
        print(f"\n1. Kaynak simgeyi düzeltiliyor: {source_icon}")
        remove_alpha_channel(source_icon)
    else:
        print(f"\n[UYARI] {source_icon} bulunamadi")
    
    # iOS 1024x1024 simgesini düzelt
    if os.path.exists(ios_icon_1024):
        print(f"\n2. iOS 1024x1024 simgesini düzeltiliyor: {ios_icon_1024}")
        remove_alpha_channel(ios_icon_1024)
    else:
        print(f"\n[UYARI] {ios_icon_1024} bulunamadi")
        print("   Simgeleri yeniden olusturmak icin 'flutter pub run flutter_launcher_icons' komutunu calistirin")
    
    print("\n" + "=" * 50)
    print("[OK] Islem tamamlandi!")
    print("\nSonraki adimlar:")
    print("1. Simgeleri yeniden oluşturun: flutter pub run flutter_launcher_icons")
    print("2. iOS build'i temizleyin: flutter clean")
    print("3. Uygulamayı yeniden derleyin")

if __name__ == "__main__":
    main()

