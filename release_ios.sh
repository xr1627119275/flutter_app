#!/bin/bash

echo "🚀 Build + Shorebird Release"
shorebird release ios

echo "📦 Upload to App Store Connect"
xcrun altool \
  --upload-app \
  --type ios \
  -f build/ios/ipa/*.ipa \
  --apiKey $APP_STORE_CONNECT_API_KEY \
  --apiIssuer $APP_STORE_CONNECT_API_ISSUER

echo "✅ Done"
