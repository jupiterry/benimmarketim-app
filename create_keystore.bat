@echo off
echo Existing apps must reuse their original upload key.
echo To create a key for a NEW app only, run keytool interactively:
echo keytool -genkeypair -v -keystore android/app/release-key.keystore -alias benimmarketim -keyalg RSA -keysize 2048 -validity 10000
echo Put signing values in the ignored android/key.properties file.
