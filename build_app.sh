#!/bin/bash

APP_NAME="TouchMonitor"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

echo "🔨 TouchMonitor uygulamasını inşa ediliyor..."

# Uygulama klasörlerini oluştur
mkdir -p "$MACOS_DIR"

# Info.plist oluştur (Uygulamanın Dock'ta görünmeyip sadece Menü Çubuğunda çalışması için LSUIElement=true)
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.teret.touchmonitor</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Swift dosyasını derle ve MacOS klasörüne at
swiftc TouchMonitor.swift -o "$MACOS_DIR/$APP_NAME"

echo "✅ Kurulum tamamlandı! $APP_DIR uygulaması başarıyla oluşturuldu."
echo "   Artık bu uygulamayı Applications (Uygulamalar) klasörüne atıp normal bir program gibi kullanabilirsin."
