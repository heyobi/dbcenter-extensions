#!/bin/bash
# Hata toleranslı mod

# =========================================================
#  DBCENTER FACTORY: PGVECTOR EDITION
# =========================================================

# HEDEF VERSİYONLAR (Senin listene göre stratejik seçimler)
# 0.4.4 -> HNSW öncesi son stabil sürüm (Legacy destek için)
# 0.5.0 -> HNSW Miladı (Devrim)
# 0.5.1 - 0.7.4 -> Ara sürümler
# 0.8.0+ -> En yeniler (Postgres 17 destekler)
TARGET_VECTOR_VERSIONS=("0.4.4" "0.5.0" "0.5.1" "0.6.0" "0.6.2" "0.7.0" "0.7.2" "0.7.4" "0.8.0" "0.8.1")

# Postgres Sürümleri
TARGET_PG_VERSIONS=("13" "14" "15" "16" "17" "18")

OUTPUT_DIR="/packages"
mkdir -p $OUTPUT_DIR
LOG_FILE="$OUTPUT_DIR/build_report.txt"

log() {
    echo "$1"
    echo "$1" >> $LOG_FILE
}

log "BUILD BAŞLADI: $(date)"
log "Hedef Vector Sürümleri: ${TARGET_VECTOR_VERSIONS[*]}"

# =========================================================
# 1. LINUX DERLEYİCİ
# =========================================================
build_linux() {
    local vec_ver=$1
    local pg_ver=$2
    
    ARCH=$(uname -m)
    [ "$ARCH" == "x86_64" ] && ARCH="amd64"
    PKG_NAME="pgvector-${vec_ver}-linux-${ARCH}-pg${pg_ver}.tar.gz"

    if [ -f "$OUTPUT_DIR/$PKG_NAME" ]; then
        log "   [LINUX] $PKG_NAME zaten var. (Atlanıyor)"
        return
    fi

    log "----------------------------------------------------"
    log "   [LINUX] Derleniyor: pgvector $vec_ver -> PG $pg_ver"

    # Kaynak İndir (Cache)
    SRC_DIR="pgvector-$vec_ver"
    if [ ! -d "$SRC_DIR" ]; then
        # v0.x.x formatında indir
        wget -q "https://github.com/pgvector/pgvector/archive/refs/tags/v${vec_ver}.tar.gz" -O temp_src.tar.gz
        tar -xzf temp_src.tar.gz
        rm temp_src.tar.gz
    fi

    cd "$SRC_DIR"
    make clean > /dev/null 2>&1 || true

    # pgvector derleme
    # PG 17/18 gibi yeni sürümler, çok eski pgvector kodlarında (0.4.x) hata verebilir.
    # Bu yüzden hata yakalama (if) kullanıyoruz.
    if make PG_CONFIG=/usr/lib/postgresql/$pg_ver/bin/pg_config -j$(nproc) > /dev/null 2>&1; then
        
        STAGING="dist_linux_${vec_ver}_pg${pg_ver}"
        rm -rf $STAGING
        mkdir -p $STAGING/lib $STAGING/share/extension

        # Dosyaları Topla
        cp *.so $STAGING/lib/
        cp sql/*.sql $STAGING/share/extension/ 2>/dev/null || true
        # Bazı eski sürümlerde sql dosyaları kök dizinde olabilir
        cp *.sql $STAGING/share/extension/ 2>/dev/null || true
        cp *.control $STAGING/share/extension/

        tar -czf "$OUTPUT_DIR/$PKG_NAME" -C $STAGING .
        rm -rf $STAGING
        log "   -> BAŞARILI: $PKG_NAME"
    else
        log "   ! HATA: Make başarısız (Kod uyumsuzluğu: Vector $vec_ver <-> PG $pg_ver)."
    fi
    cd ..
}

# =========================================================
# 2. WINDOWS REPACKAGER
# =========================================================
repackage_windows() {
    local vec_ver=$1
    local pg_ver=$2
    
    PKG_NAME="pgvector-${vec_ver}-windows-amd64-pg${pg_ver}.zip"

    if [ -f "$OUTPUT_DIR/$PKG_NAME" ]; then
        log "   [WINDOWS] $PKG_NAME zaten var. (Atlanıyor)"
        return
    fi

    log "----------------------------------------------------"
    log "   [WINDOWS] Aranıyor: pgvector $vec_ver -> PG $pg_ver"

    # URL Formatı: https://github.com/pgvector/pgvector/releases/download/v0.8.0/pgvector_0.8.0_pg17.zip
    URL="https://github.com/pgvector/pgvector/releases/download/v${vec_ver}/pgvector_${vec_ver}_pg${pg_ver}.zip"
    TEMP_ZIP="temp_win_pg${pg_ver}.zip"

    if wget -q --spider "$URL"; then
        wget -q -O $TEMP_ZIP "$URL"
        
        UNZIP_DIR="win_stage_${vec_ver}_pg${pg_ver}"
        rm -rf $UNZIP_DIR
        unzip -q $TEMP_ZIP -d $UNZIP_DIR
        
        TARGET_DIR="final_win_${vec_ver}_pg${pg_ver}"
        rm -rf $TARGET_DIR
        mkdir -p $TARGET_DIR

        # Flattening (İç içe klasörleri temizle)
        # Bazen zip içinde 'pgvector_0.8.0' klasörü olur, bazen direkt dosyalar.
        cp -r $UNZIP_DIR/* $TARGET_DIR/
        
        # Eğer tek bir klasör varsa içeriğini yukarı taşı
        NUM_FILES=$(ls $TARGET_DIR | wc -l)
        if [ "$NUM_FILES" -eq "1" ] && [ -d "$TARGET_DIR/$(ls $TARGET_DIR)" ]; then
            mv $TARGET_DIR/*/* $TARGET_DIR/
        fi

        cd $TARGET_DIR
        zip -q -r "$OUTPUT_DIR/$PKG_NAME" .
        cd ../..
        
        log "   -> BAŞARILI: $PKG_NAME"
        rm -rf $UNZIP_DIR $TARGET_DIR $TEMP_ZIP
    else
        log "   ! BULUNAMADI: Windows binary yok ($URL)"
    fi
}

# =========================================================
# ANA MATRIX DÖNGÜSÜ
# =========================================================

# Kaynak kodları önceden indir
for vec_ver in "${TARGET_VECTOR_VERSIONS[@]}"; do
    if [ ! -d "pgvector-$vec_ver" ]; then
        wget -q "https://github.com/pgvector/pgvector/archive/refs/tags/v${vec_ver}.tar.gz" -O src.tar.gz
        tar -xzf src.tar.gz
        rm src.tar.gz
    fi
done

for vec_ver in "${TARGET_VECTOR_VERSIONS[@]}"; do
    for pg_ver in "${TARGET_PG_VERSIONS[@]}"; do
        
        # Linux Build
        build_linux $vec_ver $pg_ver
        
        # Windows Repackage
        repackage_windows $vec_ver $pg_ver
        
    done
done

log "================================================="
log "   PGVECTOR FACTORY TAMAMLANDI"
log "================================================="
chmod 777 $OUTPUT_DIR/* 2>/dev/null || true
ls -lh $OUTPUT_DIR