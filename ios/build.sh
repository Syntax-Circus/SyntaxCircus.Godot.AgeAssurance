#!/usr/bin/env bash
set -euo pipefail
: "${GODOT_SOURCE:?Set matching configured Godot 4.7.2 source}"
source_dir="$(cd "$(dirname "$0")" && pwd)"
app="${1:?Pass consumer Godot app directory}"
out="$app/ios/plugins/age_assurance"
mkdir -p "$out"
sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
# 26.4+ SDK required for regulatory features; deployment remains iOS 15.
xcrun --sdk iphoneos swiftc -parse-as-library -emit-object -whole-module-optimization -O -module-name SyntaxCircusAgeAssurance -target arm64-apple-ios15.0 -sdk "$sdk" -emit-objc-header -emit-objc-header-path "$out/SyntaxCircusAgeAssurance-Swift.h" "$source_dir/AgeAssurance.swift" -o "$out/AgeAssurance.o"
xcrun --sdk iphoneos clang++ -arch arm64 -isysroot "$sdk" -miphoneos-version-min=15.0 -std=c++17 -fobjc-arc -fvisibility=hidden -DIOS_ENABLED -DUNIX_ENABLED -I "$GODOT_SOURCE" -I "$GODOT_SOURCE/platform/ios" -I "$out" -c "$source_dir/age_assurance.mm" -o "$out/bridge.o"
xcrun ar rcs "$out/SyntaxCircusAgeAssurance.a" "$out/AgeAssurance.o" "$out/bridge.o"
cp "$source_dir/SyntaxCircusAgeAssurance.gdip" "$out/SyntaxCircusAgeAssurance.gdip"
