#!/bin/bash
# Hata toleranslı mod (set -e kapalı)

# =========================================================
#  DBCENTER FACTORY: SNIPER MODE (V4)
# =========================================================

# Hedefler
TARGET_GIS_VERSIONS=("3.1.11" "3.2.7" "3.3.7" "3.4.3" "3.5.0")
TARGET_PG_VERSIONS=("12" "13" "14" "15" "16" "17" "18")

OUTPUT_DIR="/packages"
mkdir -p $OUTPUT_DIR
LOG_FILE="$OUTPUT_DIR/build_report.txt"

# Log fonksiyonu
log() {
    echo "$1"
    echo "$1" >> $LOG_FILE
}

log "BUILD BAŞLADI: $(date)"

# =========================================================
# FONKSİYON 1: LINUX (Zaten çalışan kısım - aynen korundu)
# =========================================================
build_linux() {
    local gis_ver=$1
    local pg_ver=$2
    
    ARCH=$(uname -m)
    [ "$ARCH" == "x86_64" ] && ARCH="amd64"
    PKG_NAME="postgis-${gis_ver}-linux-${ARCH}-pg${pg_ver}.tar.gz"

    if [ -f "$OUTPUT_DIR/$PKG_NAME" ]; then
        log "   [LINUX] $PKG_NAME zaten mevcut. (Atlanıyor)"
        return
    fi

    log "----------------------------------------------------"
    log "   [LINUX] Derleniyor: PostGIS $gis_ver -> PG $pg_ver"
    
    # Kaynak Kod İndirme (Cache)
    if [ ! -d "postgis-$gis_ver" ]; then
        wget -q https://download.osgeo.org/postgis/source/postgis-$gis_ver.tar.gz
        tar -xzf postgis-$gis_ver.tar.gz
    fi

    cd "postgis-$gis_ver"
    make clean > /dev/null 2>&1 || true
    
    # Derleme Kontrolleri
    if ./configure --with-pgconfig=/usr/lib/postgresql/$pg_ver/bin/pg_config > /dev/null 2>&1; then
        if make -j$(nproc) > /dev/null 2>&1; then
            STAGING="dist_linux_${gis_ver}_pg${pg_ver}"
            rm -rf $STAGING
            mkdir -p $STAGING/lib $STAGING/share/extension
            
            find . -name "postgis-*.so" -exec cp {} $STAGING/lib/ \;
            find . -name "rtpostgis-*.so" -exec cp {} $STAGING/lib/ \; || true
            find . -name "postgis_topology-*.so" -exec cp {} $STAGING/lib/ \; || true
            find . -name "address_standardizer-*.so" -exec cp {} $STAGING/lib/ \; || true
            
            find extensions -name "*.sql" -exec cp {} $STAGING/share/extension/ \;
            find extensions -name "*.control" -exec cp {} $STAGING/share/extension/ \;
            
            tar -czf "$OUTPUT_DIR/$PKG_NAME" -C $STAGING .
            rm -rf $STAGING
            log "   -> BAŞARILI: $PKG_NAME"
        else
            log "   ! HATA: Make başarısız (Kod uyumsuzluğu)."
        fi
    else
        log "   ! HATA: Configure başarısız (Desteklenmiyor)."
    fi
    cd ..
}

# =========================================================
# FONKSİYON 2: WINDOWS SNIPER (YENİ AKILLI TARAYICI)
# =========================================================
repackage_windows_smart() {
    local pg_ver=$2
    # Not: Windows'ta her GIS sürümü için değil, o an sunucuda ne varsa onu alacağız.
    # Bu yüzden döngüde gis_ver parametresini biraz esnek kullanacağız.
    
    # Çıktı dosya adı şablonu (GIS versiyonunu dinamik bulacağız)
    # PKG_NAME="postgis-{BULUNAN_VER}-windows-amd64-pg${pg_ver}.zip"

    log "----------------------------------------------------"
    log "   [WINDOWS] Sunucu Taranıyor: PG $pg_ver"

    # OSGeo Dizinleri
    BASE_URL="https://download.osgeo.org/postgis/windows/pg${pg_ver}/"
    ARCHIVE_URL="${BASE_URL}archive/"
    
    # HTML İndirip Zip Dosyasını Bulma (Regex)
    # postgis-bundle-pg15-3.4.2x64.zip gibi dosyaları arar.
    # head -n 1 ile en üsttekini (genelde en yenisi) alır.
    
    FOUND_FILE=""
    DOWNLOAD_URL=""

    # 1. Önce Ana Dizine Bak
    HTML_CONTENT=$(wget -qO- $BASE_URL)
    FOUND_FILE=$(echo "$HTML_CONTENT" | grep -o 'postgis-bundle-pg[0-9]*-[0-9.]*x64.zip' | sort -V -r | head -n 1)
    
    if [ -n "$FOUND_FILE" ]; then
        DOWNLOAD_URL="${BASE_URL}${FOUND_FILE}"
        log "   -> Ana dizinde bulundu: $FOUND_FILE"
    else
        # 2. Bulamazsa Archive Dizinine Bak
        HTML_CONTENT=$(wget -qO- $ARCHIVE_URL)
        FOUND_FILE=$(echo "$HTML_CONTENT" | grep -o 'postgis-bundle-pg[0-9]*-[0-9.]*x64.zip' | sort -V -r | head -n 1)
        
        if [ -n "$FOUND_FILE" ]; then
            DOWNLOAD_URL="${ARCHIVE_URL}${FOUND_FILE}"
            log "   -> Arşivde bulundu: $FOUND_FILE"
        else
            log "   ! BULUNAMADI: PG $pg_ver için Windows binary yok."
            return
        fi
    fi

    # Dosya adından versiyonu çek (Regex büyüsü)
    # postgis-bundle-pg15-3.4.2x64.zip -> 3.4.2
    EXTRACTED_VER=$(echo $FOUND_FILE | sed -E 's/.*-([0-9]+\.[0-9]+\.[0-9]+)x64\.zip/\1/')
    
    FINAL_PKG_NAME="postgis-${EXTRACTED_VER}-windows-amd64-pg${pg_ver}.zip"

    # Zaten var mı?
    if [ -f "$OUTPUT_DIR/$FINAL_PKG_NAME" ]; then
        log "   -> $FINAL_PKG_NAME zaten var. (Atlanıyor)"
        return
    fi

    # İndir ve İşle
    TEMP_ZIP="temp_win_pg${pg_ver}.zip"
    wget -q -O $TEMP_ZIP $DOWNLOAD_URL
    
    UNZIP_DIR="win_stage_pg${pg_ver}"
    rm -rf $UNZIP_DIR
    unzip -q $TEMP_ZIP -d $UNZIP_DIR
    
    TARGET_DIR="final_win_pg${pg_ver}"
    rm -rf $TARGET_DIR
    mkdir -p $TARGET_DIR
    
    INNER_DIR=$(find $UNZIP_DIR -maxdepth 1 -type d -name "postgis-bundle*" | head -n 1)
    if [ -n "$INNER_DIR" ]; then
        cp -r $INNER_DIR/* $TARGET_DIR/
        cd $TARGET_DIR
        zip -q -r "$OUTPUT_DIR/$FINAL_PKG_NAME" .
        cd ../..
        log "   -> PAKETLENDİ: $FINAL_PKG_NAME"
    else
        log "   ! HATA: Zip bozuk indi."
    fi
    
    rm -rf $UNZIP_DIR $TEMP_ZIP $TARGET_DIR
}

# =========================================================
# ANA DÖNGÜ
# =========================================================

# 1. LINUX DÖNGÜSÜ (Matrix)
for gis_ver in "${TARGET_GIS_VERSIONS[@]}"; do
    for pg_ver in "${TARGET_PG_VERSIONS[@]}"; do
        build_linux $gis_ver $pg_ver
    done
done

# 2. WINDOWS DÖNGÜSÜ (Smart Scan)
# Windows için matrix yapmıyoruz, her PG sürümü için "En İyi/Mevcut" olanı alıyoruz.
for pg_ver in "${TARGET_PG_VERSIONS[@]}"; do
    repackage_windows_smart "AUTO" $pg_ver
done

log "================================================="
log "   TÜM SÜREÇ TAMAMLANDI"
log "================================================="
chmod 777 $OUTPUT_DIR/* 2>/dev/null || true
ls -lh $OUTPUT_DIR