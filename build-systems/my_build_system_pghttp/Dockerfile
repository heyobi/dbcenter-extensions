FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Temel Araçlar ve Bağımlılıklar
RUN apt-get update && apt-get install -y \
    wget gnupg2 lsb-release curl software-properties-common \
    build-essential git libxml2-dev libjson-c-dev \
    zip unzip \
    libcurl4-openssl-dev  # <--- KRİTİK: pg_http için gerekli

# PostgreSQL Reposu
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update

# Tüm Postgres Sürümleri (12-18)
RUN apt-get install -y \
    postgresql-server-dev-12 \
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