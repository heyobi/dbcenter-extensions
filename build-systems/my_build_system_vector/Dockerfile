FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# 1. ADIM: Önce repo eklemek için gereken temel araçları kur
RUN apt-get update && apt-get install -y \
    wget gnupg2 lsb-release curl software-properties-common

# 2. ADIM: PostgreSQL Resmi Reposunu (PGDG) Ekle
# Bu adım olmadan apt-get diğer postgres sürümlerini bulamaz!
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update

# 3. ADIM: Şimdi Development Headerlarını ve MinGW'yi kur
# Artık repo ekli olduğu için tüm sürümleri bulacaktır.
RUN apt-get install -y \
    build-essential git \
    zip unzip \
    mingw-w64 \
    postgresql-server-dev-13 \
    postgresql-server-dev-14 \
    postgresql-server-dev-15 \
    postgresql-server-dev-16 \
    postgresql-server-dev-17 \
    postgresql-server-dev-18

COPY builder.sh /builder.sh
RUN chmod +x /builder.sh

WORKDIR /build
ENTRYPOINT ["/builder.sh"]