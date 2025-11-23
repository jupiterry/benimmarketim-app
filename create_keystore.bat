@echo off
echo Creating release keystore...

"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore android\app\release-key.keystore -alias benimmarketim -keyalg RSA -keysize 2048 -validity 10000 -storepass benimmarketim123 -keypass benimmarketim123 -dname "CN=Benim Marketim, OU=Development, O=Benim Marketim, L=Istanbul, S=Istanbul, C=TR"

echo Keystore created successfully!
pause
