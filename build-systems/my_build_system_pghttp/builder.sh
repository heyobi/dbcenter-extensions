#!/bin/bash
# Hata toleranslı (set -e kapalı)

# =========================================================
#  DBCENTER FACTORY: PG_HTTP EDITION
# =========================================================

# Linux için derlenecek kaynak kod versiyonları (Senin Listen)
TARGET_HTTP_VERSIONS=("1.7.0" "1.6.3" "1.6.2" "1.6.1" "1.6.0" "1.5.0" "1.4.1" "1.4.0" "1.3.1" "1.3.0" "1.2.4" "1.2.3" "1.2.2" "1.2.1" "1.2.0" "1.1.2" "1.1.1" "1.1.0")

# Postgres Sürümleri (Modern)
TARGET_PG_VERSIONS=("12" "13" "14" "15" "16" "17" "18")

OUTPUT_DIR="/packages"
mkdir -p $OUTPUT_DIR
LOG_FILE="$OUTPUT_DIR/build_report.txt"

log() {
    echo "$1"
    echo "$1" >> $LOG_FILE
}

log "BUILD BAŞLADI: $(date)"

# =========================================================
# 1. LINUX DERLEYİCİ
# =========================================================
build_linux() {
    local http_ver=$1
    local pg_ver=$2
    
    ARCH=$(uname -m)
    [ "$ARCH" == "x86_64" ] && ARCH="amd64"
    PKG_NAME="pghttp-${http_ver}-linux-${ARCH}-pg${pg_ver}.tar.gz"

    if [ -f "$OUTPUT_DIR/$PKG_NAME" ]; then
        log "   [LINUX] $PKG_NAME zaten var. (Atlanıyor)"
        return
    fi

    log "----------------------------------------------------"
    log "   [LINUX] Derleniyor: pg_http $http_ver -> PG $pg_ver"

    # Kaynak İndir
    SRC_DIR="pgsql-http-$http_ver"
    if [ ! -d "$SRC_DIR" ]; then
        wget -q "https://github.com/pramsey/pgsql-http/archive/refs/tags/v${http_ver}.tar.gz" -O temp_src.tar.gz
        tar -xzf temp_src.tar.gz
        rm temp_src.tar.gz
    fi

    cd "$SRC_DIR"
    make clean > /dev/null 2>&1 || true

    # Configure ve Make
    # pg_http configure kullanmaz, direkt make kullanır ama PG_CONFIG yolunu ister
    if make PG_CONFIG=/usr/lib/postgresql/$pg_ver/bin/pg_config -j$(nproc) > /dev/null 2>&1; then
        
        STAGING="dist_linux_${http_ver}_pg${pg_ver}"
        rm -rf $STAGING
        mkdir -p $STAGING/lib $STAGING/share/extension

        # Dosyaları Topla
        # pg_http genelde http.so üretir
        cp *.so $STAGING/lib/
        cp *.sql $STAGING/share/extension/
        cp *.control $STAGING/share/extension/

        tar -czf "$OUTPUT_DIR/$PKG_NAME" -C $STAGING .
        rm -rf $STAGING
        log "   -> BAŞARILI: $PKG_NAME"
    else
        log "   ! HATA: Make başarısız (Uyumsuzluk)."
    fi
    cd ..
}

# =========================================================
# 2. WINDOWS DEDEKTİFİ (Versiyon Okuyucu)
# =========================================================
repackage_windows_detect() {
    local pg_ver=$2
    
    log "----------------------------------------------------"
    log "   [WINDOWS] İndiriliyor ve Analiz Ediliyor: PG $pg_ver"

    # Windows Download URL
    # URL Formatı: https://www.postgresonline.com/downloads/pg18http_w64.zip
    URL="https://www.postgresonline.com/downloads/pg${pg_ver}http_w64.zip"
    TEMP_ZIP="temp_win_pg${pg_ver}.zip"

    if wget -q --spider "$URL"; then
        wget -q -O $TEMP_ZIP "$URL"
    else
        log "   ! BULUNAMADI: $URL"
        return
    fi

    # Zipi Aç
    UNZIP_DIR="win_stage_pg${pg_ver}"
    rm -rf $UNZIP_DIR
    unzip -q $TEMP_ZIP -d $UNZIP_DIR

    # --- DEDEKTİFLİK KISMI ---
    # pghttp_version.txt dosyasını bul (Bazen alt klasördedir)
    VERSION_FILE=$(find $UNZIP_DIR -name "pghttp_version.txt")
    
    if [ -n "$VERSION_FILE" ]; then
        # Dosyayı oku: "PGHTTP VERSION: 1.6.1 ..." satırını bul
        # awk ile 3. kelimeyi al (1.6.1)
        DETECTED_VER=$(grep "PGHTTP VERSION:" "$VERSION_FILE" | awk '{print $3}')
        
        if [ -n "$DETECTED_VER" ]; then
            log "   -> Tespit Edilen Versiyon: $DETECTED_VER"
            
            # Yeni Paket Adı
            PKG_NAME="pghttp-${DETECTED_VER}-windows-amd64-pg${pg_ver}.zip"
            
            # İçerik Hazırlama (Flattening)
            TARGET_DIR="final_win_pg${pg_ver}"
            rm -rf $TARGET_DIR
            mkdir -p $TARGET_DIR
            
            # Binarylerin olduğu klasörü bul (genelde txt dosyasının olduğu yerdir)
            SOURCE_CONTENT_DIR=$(dirname "$VERSION_FILE")
            
            # Dosyaları Kopyala
            cp -r "$SOURCE_CONTENT_DIR"/* $TARGET_DIR/
            
            # Gereksiz txt dosyalarını sil (isteğe bağlı, temizlik)
            rm -f $TARGET_DIR/*.txt

            # Paketle
            cd $TARGET_DIR
            zip -q -r "$OUTPUT_DIR/$PKG_NAME" .
            cd ../..
            
            log "   -> PAKETLENDİ: $PKG_NAME"
        else
            log "   ! HATA: Versiyon numarası okunamadı."
        fi
    else
        log "   ! HATA: pghttp_version.txt bulunamadı."
    fi

    rm -rf $UNZIP_DIR $TEMP_ZIP $TARGET_DIR
}

# =========================================================
# ANA DÖNGÜ
# =========================================================

# 1. LINUX DÖNGÜSÜ
for http_ver in "${TARGET_HTTP_VERSIONS[@]}"; do
    for pg_ver in "${TARGET_PG_VERSIONS[@]}"; do
        build_linux $http_ver $pg_ver
    done
done

# 2. WINDOWS DÖNGÜSÜ
# Windows'ta versiyon seçmiyoruz, sunucuda ne varsa onu indirip adını düzeltiyoruz.
for pg_ver in "${TARGET_PG_VERSIONS[@]}"; do
    repackage_windows_detect "AUTO" $pg_ver
done

log "================================================="
log "   PG_HTTP FACTORY TAMAMLANDI"
log "================================================="
chmod 777 $OUTPUT_DIR/* 2>/dev/null || true
ls -lh $OUTPUT_DIR