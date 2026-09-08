#!/bin/bash
# Hata toleranslı mod

# =========================================================
#  DBCENTER FACTORY: PGVECTOR EDITION (Smart Windows Downloader)
# =========================================================

# Hedeflenen pgvector sürümleri
TARGET_VECTOR_VERSIONS=("0.5.1" "0.6.0" "0.7.0" "0.7.3" "0.7.4" "0.8.0" "0.8.1")

# Postgres Sürümleri (13+)
TARGET_PG_VERSIONS=("13" "14" "15" "16" "17" "18")

OUTPUT_DIR="/packages"
mkdir -p $OUTPUT_DIR
LOG_FILE="$OUTPUT_DIR/build_report.txt"

log() {
    echo "$1"
    echo "$1" >> $LOG_FILE
}

log "BUILD BAŞLADI: $(date)"

# =========================================================
# 1. LINUX DERLEYİCİ (Kaynak Koddan)
# =========================================================
build_linux() {
    local vec_ver=$1
    local pg_ver=$2
    
    ARCH=$(uname -m)
    [ "$ARCH" == "x86_64" ] && ARCH="amd64"
    PKG_NAME="vector-${vec_ver}-linux-${ARCH}-pg${pg_ver}.tar.gz"

    if [ -f "$OUTPUT_DIR/$PKG_NAME" ]; then
        log "   [LINUX] $PKG_NAME zaten var. (Atlanıyor)"
        return
    fi

    log "----------------------------------------------------"
    log "   [LINUX] Derleniyor: pgvector $vec_ver -> PG $pg_ver"

    # Kaynak İndir (Cache)
    SRC_DIR="pgvector-$vec_ver"
    if [ ! -d "$SRC_DIR" ]; then
        wget -q "https://github.com/pgvector/pgvector/archive/refs/tags/v${vec_ver}.tar.gz" -O temp_src.tar.gz
        tar -xzf temp_src.tar.gz
        rm temp_src.tar.gz
    fi

    cd "$SRC_DIR"
    make clean > /dev/null 2>&1 || true

    # pgvector derleme
    if make PG_CONFIG=/usr/lib/postgresql/$pg_ver/bin/pg_config -j$(nproc) > /dev/null 2>&1; then
        
        STAGING="dist_linux_${vec_ver}_pg${pg_ver}"
        rm -rf $STAGING
        mkdir -p $STAGING/lib $STAGING/share/extension

        # Dosyaları Topla
        cp *.so $STAGING/lib/ 2>/dev/null || true
        cp sql/*.sql $STAGING/share/extension/ 2>/dev/null || true
        cp *.control $STAGING/share/extension/ 2>/dev/null || true

        tar -czf "$OUTPUT_DIR/$PKG_NAME" -C $STAGING .
        rm -rf $STAGING
        log "   -> BAŞARILI: $PKG_NAME"
    else
        log "   ! HATA: Make başarısız (Versiyon uyumsuzluğu olabilir)."
    fi
    cd ..
}

# =========================================================
# 2. WINDOWS DOWNLOADER (andreiramani repository'den)
# =========================================================
repackage_windows() {
    local vec_ver=$1
    local pg_ver=$2
    
    PKG_NAME="vector-${vec_ver}-windows-amd64-pg${pg_ver}.zip"

    if [ -f "$OUTPUT_DIR/$PKG_NAME" ]; then
        log "   [WINDOWS] $PKG_NAME zaten var. (Atlanıyor)"
        return
    fi

    log "----------------------------------------------------"
    log "   [WINDOWS] İndiriliyor: pgvector $vec_ver -> PG $pg_ver"

    # URL şablonları (verilen linklere göre)
    # Önce releases üzerinden deneyelim
    URL_RELEASE="https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/${vec_ver}_${pg_ver}/vector.v${vec_ver}-pg${pg_ver}.zip"
    # Eğer major sürüm varsa (örn: pg16 yerine pg16.0)
    URL_RELEASE_ALT="https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/${vec_ver}_${pg_ver}.0/vector.v${vec_ver}-pg${pg_ver}.0.zip"
    
    # GitHub blob URL'leri (raw content)
    URL_BLOB="https://github.com/andreiramani/pgvector_pgsql_windows/raw/main/zip/${vec_ver}/vector.v${vec_ver}-pg${pg_ver}.zip"
    
    TEMP_ZIP="temp_win_${vec_ver}_pg${pg_ver}.zip"
    DOWNLOAD_SUCCESS=false

    # 1. Deneme: Release URL
    if wget -q --spider "$URL_RELEASE" 2>/dev/null; then
        wget -q -O $TEMP_ZIP "$URL_RELEASE" && DOWNLOAD_SUCCESS=true
        log "   -> Release URL kullanıldı"
    # 2. Deneme: Blob URL
    elif wget -q --spider "$URL_BLOB" 2>/dev/null; then
        wget -q -O $TEMP_ZIP "$URL_BLOB" && DOWNLOAD_SUCCESS=true
        log "   -> Blob URL kullanıldı"
    # 3. Deneme: Alternatif Release URL
    elif wget -q --spider "$URL_RELEASE_ALT" 2>/dev/null; then
        wget -q -O $TEMP_ZIP "$URL_RELEASE_ALT" && DOWNLOAD_SUCCESS=true
        log "   -> Alternatif Release URL kullanıldı"
    # 4. Manuel özel durumlar (verilen linklere göre)
    else
        # Özel durum URL'leri
        case "${vec_ver}_${pg_ver}" in
            "0.8.1_14")
                URL="https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/0.8.1_14.20/vector.v0.8.1-pg14.20.zip"
                ;;
            "0.8.1_13")
                URL="https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/0.8.1_13.23/vector.v0.8.1-pg13.23.zip"
                ;;
            "0.8.1_18")
                URL="https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/0.8.1_18.0.2/vector.v0.8.1-pg18.zip"
                ;;
            "0.8.1_17")
                URL="https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/0.8.1_17.6/vector.v0.8.1-pg17.zip"
                ;;
            "0.8.1_16")
                URL="https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/0.8.1_16/vector.v0.8.1-pg16.zip"
                ;;
            "0.8.1_15")
                URL="https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/0.8.1_15.14/vector.v0.8.1-pg15.14.zip"
                ;;
            "0.8.0_17")
                URL="https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/0.8.0_17.6/vector.v0.8.0-pg17.6.zip"
                ;;
            "0.8.0_16")
                URL="https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/0.8.0_16/vector.v0.8.0-pg16.zip"
                ;;
            "0.8.0_15")
                URL="https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/0.8.0_15.14/vector.v0.8.0-pg15.14.zip"
                ;;
            "0.7.4_16")
                URL="https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/0.7.4/vector.v0.7.4-pg16.zip"
                ;;
            "0.7.3_15")
                URL="https://github.com/andreiramani/pgvector_pgsql_windows/releases/download/0.7.3/vector.v0.7.3-pg15.zip"
                ;;
            *)
                URL=""
                ;;
        esac
        
        if [ -n "$URL" ] && wget -q --spider "$URL" 2>/dev/null; then
            wget -q -O $TEMP_ZIP "$URL" && DOWNLOAD_SUCCESS=true
            log "   -> Özel URL kullanıldı"
        fi
    fi

    if [ "$DOWNLOAD_SUCCESS" = true ]; then
        # Zip'i aç
        UNZIP_DIR="win_stage_${vec_ver}_pg${pg_ver}"
        rm -rf $UNZIP_DIR
        unzip -q $TEMP_ZIP -d $UNZIP_DIR
        
        TARGET_DIR="final_win_${vec_ver}_pg${pg_ver}"
        rm -rf $TARGET_DIR
        mkdir -p $TARGET_DIR

        # İçeriği kopyala
        cp -r $UNZIP_DIR/* $TARGET_DIR/
        
        # Eğer tek bir klasör içine gömülmüşse içeriği bir yukarı taşı
        if [ $(ls $TARGET_DIR | wc -l) -eq 1 ] && [ -d "$TARGET_DIR/$(ls $TARGET_DIR)" ]; then
             mv $TARGET_DIR/*/* $TARGET_DIR/
        fi

        # Yeniden Paketle (postgis gibi isimlendirme)
        cd $TARGET_DIR
        zip -q -r "$OUTPUT_DIR/$PKG_NAME" .
        cd ../..
        
        log "   -> BAŞARILI: $PKG_NAME"
        
        rm -rf $UNZIP_DIR $TARGET_DIR $TEMP_ZIP
    else
        log "   ! BULUNAMADI: Windows binary (pgvector $vec_ver, pg$pg_ver)"
    fi
}

# =========================================================
# ANA MATRIX DÖNGÜSÜ
# =========================================================

for vec_ver in "${TARGET_VECTOR_VERSIONS[@]}"; do
    
    # Linux Kaynak İndir (Cache)
    if [ ! -d "pgvector-$vec_ver" ]; then
        wget -q "https://github.com/pgvector/pgvector/archive/refs/tags/v${vec_ver}.tar.gz" -O src.tar.gz
        tar -xzf src.tar.gz
        rm src.tar.gz
    fi

    for pg_ver in "${TARGET_PG_VERSIONS[@]}"; do
        
        # Linux: Derle
        build_linux $vec_ver $pg_ver
        
        # Windows: İndir ve Paketle (Asla derleme!)
        repackage_windows $vec_ver $pg_ver
        
    done
done

log "================================================="
log "   PGVECTOR FACTORY TAMAMLANDI"
log "================================================="
chmod 777 $OUTPUT_DIR/* 2>/dev/null || true
ls -lh $OUTPUT_DIR