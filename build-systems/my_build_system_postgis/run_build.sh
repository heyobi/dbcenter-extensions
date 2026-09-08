#!/bin/bash

# Çıktı klasörünü oluştur
mkdir -p packages

echo "--- Docker Image Oluşturuluyor (Linux Build Environment) ---"
docker build -t dbcenter-builder .

echo "--- 1. AMD64 (Standart PC/Sunucu) İçin Derleniyor... ---"
# --platform linux/amd64 diyerek mimariyi zorluyoruz
docker run --rm \
  --platform linux/amd64 \
  -v $(pwd)/packages:/packages \
  dbcenter-builder

# Eğer ARM (Mac M1/M2 veya Raspberry Pi) desteği de istersen:
# Not: Bunun çalışması için sisteminde QEMU kurulu olmalıdır.
# echo "--- 2. ARM64 (Apple Silicon / AWS Graviton) İçin Derleniyor... ---"
# docker run --rm \
#   --platform linux/arm64 \
#   -v $(pwd)/packages:/packages \
#   dbcenter-builder

echo "--- İŞLEM BİTTİ. 'packages' KLASÖRÜNÜ KONTROL ET ---"
ls -lh packages
