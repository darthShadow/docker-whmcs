# syntax=docker/dockerfile:1.4
ARG BASE_IMAGE=lscr.io/linuxserver/baseimage-ubuntu:noble
FROM ${BASE_IMAGE}

ARG BUILD_DATE

ARG TARGETARCH
# 8.2
ARG PHP_RELEASE
# 8.13.1
ARG WHMCS_RELEASE

ARG WHMCS_SHA256=""

# Optional SHA256 pins for the loader zips. Empty = skip verification (the
# build still validates the archive extracted the expected file). Provide a
# value to fail the build on tamper / corruption / unexpected upstream change.
ARG SOURCEGUARDIAN_SHA256_AMD64=""
ARG SOURCEGUARDIAN_SHA256_ARM64=""
ARG IONCUBE_SHA256_AMD64=""
ARG IONCUBE_SHA256_ARM64=""

LABEL build_date="Date:- ${BUILD_DATE}"
LABEL build_version="Version:- WHMCS ${WHMCS_RELEASE:+v}${WHMCS_RELEASE:-latest} on PHP v${PHP_RELEASE}"
LABEL maintainer="darthShadow"

ENV PHP_VERSION=${PHP_RELEASE}

ENV TZ="UTC" PGID="1000" PUID="1000"

ENV AUTH_USER="" AUTH_PASS=""

ENV WHMCS_SERVER_IP="\$server_addr" WHMCS_SERVER_URL="_"

ENV WHMCS_ADMIN_PATH="admin"

ENV DEBIAN_FRONTEND="noninteractive"

# Install nginx and PHP
RUN echo "**** Install Dependencies ****" && \
    apt-get -y update && \
    apt-get -y install --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        cron \
        curl \
        gettext-base \
        jq \
        less \
        openssl \
        software-properties-common \
        unrar \
        unzip \
        vim \
        wget \
        zip && \
    echo "**** Add PPA: ondrej/php ****" && \
    add-apt-repository -y "ppa:ondrej/php" && \
    echo "**** Add nginx.org APT repo (stable) ****" && \
    curl -fsSL --retry 3 --retry-delay 5 https://nginx.org/keys/nginx_signing.key \
        -o /usr/share/keyrings/nginx-archive-keyring.asc && \
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.asc] http://nginx.org/packages/ubuntu noble nginx" \
        > /etc/apt/sources.list.d/nginx.list && \
    printf "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
        > /etc/apt/preferences.d/99nginx && \
    echo "**** Update Repositories ****" && \
    apt-get -y update && \
    echo "**** Upgrade Packages ****" && \
    apt-get -y upgrade && \
    echo "**** Install Nginx Packages ****" && \
    apt-get -y install --no-install-recommends \
        apache2-utils \
        nginx && \
    echo "**** Install PHP Packages ****" && \
    apt-get -y install --no-install-recommends \
        php-pear \
        php${PHP_VERSION} \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-common \
        php${PHP_VERSION}-soap \
        php${PHP_VERSION}-imagick \
        php${PHP_VERSION}-igbinary \
        php${PHP_VERSION}-redis \
        php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-opcache \
        php${PHP_VERSION}-enchant \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-imap \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-zip \
        php${PHP_VERSION}-bz2 \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-curl && \
    echo "**** Cleanup ****" && \
    apt-get -y autoremove && \
    apt-get -y purge && \
    apt-get -y clean && \
    rm -rf \
        /tmp/* \
        /var/lib/apt/lists/* \
        /var/tmp/* && \
    rm -f /var/log/lastlog /var/log/faillog

# Set default php-cli & php-fpm version to match $PHP_VERSION
RUN update-alternatives --set php /usr/bin/php${PHP_VERSION} && \
    update-alternatives --install /usr/sbin/php-fpm php-fpm /usr/sbin/php-fpm${PHP_VERSION} 60

# Setup php
RUN echo "**** Setting Up php & php-fpm ****" && \
    if [ ! -d /var/lib/php/sessions ]; then \
        mkdir -p /var/lib/php/sessions; \
        chown -R abc:abc /var/lib/php; \
    fi && \
    mkdir -p \
        /etc/php/${PHP_VERSION}/fpm/conf.d/ \
        /etc/php/${PHP_VERSION}/fpm/pool.d/ && \
    if [ -f /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf ]; then \
        mv -vf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf /etc/php/${PHP_VERSION}/fpm/pool.d/00-www.conf; \
    fi

# Configure WHMCS PHP runtime defaults for both FPM and CLI.
RUN echo "**** Setting WHMCS PHP runtime defaults ****" && \
    printf "date.timezone = %s\nmax_execution_time = 600\nmax_input_time = 600\n" "${TZ}" \
        > /etc/php/${PHP_VERSION}/mods-available/00-whmcs.ini && \
    ln -sf /etc/php/${PHP_VERSION}/mods-available/00-whmcs.ini /etc/php/${PHP_VERSION}/fpm/conf.d/00-whmcs.ini && \
    ln -sf /etc/php/${PHP_VERSION}/mods-available/00-whmcs.ini /etc/php/${PHP_VERSION}/cli/conf.d/00-whmcs.ini && \
    printf "max_execution_time = 1800\n" \
        > /etc/php/${PHP_VERSION}/cli/conf.d/99-whmcs-cli.ini

# Setup SourceGuardian for PHP
RUN set -eu; \
    case ${TARGETARCH} in \
         "amd64")  SOURCEGUARDIAN_ARCH="x86_64";  EXPECTED_SHA256="${SOURCEGUARDIAN_SHA256_AMD64}" ;; \
         "arm64")  SOURCEGUARDIAN_ARCH="aarch64"; EXPECTED_SHA256="${SOURCEGUARDIAN_SHA256_ARM64}" ;; \
         *)        echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    echo "**** Installing SourceGuardian for PHP: Architecture: ${SOURCEGUARDIAN_ARCH} ****"; \
    mkdir /tmp/sourceguardian && cd /tmp/sourceguardian; \
    curl --user-agent "Mozilla" --fail --location --silent --show-error \
         --retry 5 --retry-delay 5 --retry-connrefused \
         -o sourceguardian.zip \
         "https://www.sourceguardian.com/loaders/download/loaders.linux-${SOURCEGUARDIAN_ARCH}.zip"; \
    ACTUAL_SHA256=$(sha256sum sourceguardian.zip | awk '{print $1}'); \
    echo "SHA256: sourceguardian.linux-${SOURCEGUARDIAN_ARCH}.zip = ${ACTUAL_SHA256}"; \
    if [ -n "${EXPECTED_SHA256}" ]; then \
        if [ "${EXPECTED_SHA256}" != "${ACTUAL_SHA256}" ]; then \
            echo "SourceGuardian SHA256 mismatch: expected ${EXPECTED_SHA256}, got ${ACTUAL_SHA256}" >&2; \
            exit 1; \
        fi; \
        echo "SourceGuardian SHA256 verified."; \
    else \
        echo "SourceGuardian SHA256 pin not set; skipping verification."; \
    fi; \
    unzip -q sourceguardian.zip; \
    if [ ! -s "ixed.${PHP_VERSION}.lin" ]; then \
        echo "SourceGuardian: ixed.${PHP_VERSION}.lin missing or empty after extract" >&2; \
        exit 1; \
    fi; \
    mkdir -p /usr/lib/php/sourceguardian; \
    cp -vf ixed.${PHP_VERSION}.lin /usr/lib/php/sourceguardian/; \
    echo "zend_extension=/usr/lib/php/sourceguardian/ixed.${PHP_VERSION}.lin" > /etc/php/${PHP_VERSION}/mods-available/00-sourceguardian.ini; \
    ln -sf /etc/php/${PHP_VERSION}/mods-available/00-sourceguardian.ini /etc/php/${PHP_VERSION}/fpm/conf.d/00-sourceguardian.ini; \
    ln -sf /etc/php/${PHP_VERSION}/mods-available/00-sourceguardian.ini /etc/php/${PHP_VERSION}/cli/conf.d/00-sourceguardian.ini; \
    rm -rf /tmp/sourceguardian

# Setup ionCube for PHP
RUN set -eu; \
    case ${TARGETARCH} in \
         "amd64")  IONCUBE_ARCH="x86-64";  EXPECTED_SHA256="${IONCUBE_SHA256_AMD64}" ;; \
         "arm64")  IONCUBE_ARCH="aarch64"; EXPECTED_SHA256="${IONCUBE_SHA256_ARM64}" ;; \
         *)        echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    echo "**** Installing ionCube for PHP: Architecture: ${IONCUBE_ARCH} ****"; \
    mkdir /tmp/ioncube && cd /tmp/ioncube; \
    curl --user-agent "Mozilla" --fail --location --silent --show-error \
         --retry 5 --retry-delay 5 --retry-connrefused \
         -o ioncube.zip \
         "https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_${IONCUBE_ARCH}.zip"; \
    ACTUAL_SHA256=$(sha256sum ioncube.zip | awk '{print $1}'); \
    echo "SHA256: ioncube_loaders_lin_${IONCUBE_ARCH}.zip = ${ACTUAL_SHA256}"; \
    if [ -n "${EXPECTED_SHA256}" ]; then \
        if [ "${EXPECTED_SHA256}" != "${ACTUAL_SHA256}" ]; then \
            echo "ionCube SHA256 mismatch: expected ${EXPECTED_SHA256}, got ${ACTUAL_SHA256}" >&2; \
            exit 1; \
        fi; \
        echo "ionCube SHA256 verified."; \
    else \
        echo "ionCube SHA256 pin not set; skipping verification."; \
    fi; \
    unzip -q ioncube.zip; \
    if [ ! -s "ioncube/ioncube_loader_lin_${PHP_VERSION}.so" ]; then \
        echo "ionCube: ioncube_loader_lin_${PHP_VERSION}.so missing or empty after extract" >&2; \
        exit 1; \
    fi; \
    mkdir -p /usr/lib/php/ioncube; \
    cp -vf ioncube/ioncube_loader_lin_${PHP_VERSION}.so /usr/lib/php/ioncube/; \
    echo "zend_extension = /usr/lib/php/ioncube/ioncube_loader_lin_${PHP_VERSION}.so" > /etc/php/${PHP_VERSION}/mods-available/00-ioncube.ini; \
    ln -sf /etc/php/${PHP_VERSION}/mods-available/00-ioncube.ini /etc/php/${PHP_VERSION}/fpm/conf.d/00-ioncube.ini; \
    ln -sf /etc/php/${PHP_VERSION}/mods-available/00-ioncube.ini /etc/php/${PHP_VERSION}/cli/conf.d/00-ioncube.ini; \
    rm -rf /tmp/ioncube

# Setup nginx
RUN echo "**** Setting Up nginx ****" && \
    mkdir -p /var/www && \
    chown -R abc:abc /var/www && \
    ln -svf /dev/stdout /var/log/nginx/access.log && \
    ln -svf /dev/stderr /var/log/nginx/error.log && \
    mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/modules-enabled && \
    rm -vf /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*

# Setup WHMCS
RUN echo "**** Setting WHMCS Release Version ****" && \
    if [ "x${WHMCS_RELEASE}" = "x" ]; then \
        echo "WHMCS_RELEASE not set" >&2; \
        exit 1; \
    fi && \
    echo "**** Downloading WHMCS Release: ${WHMCS_RELEASE} ****" && \
    mkdir -p /whmcs && \
    curl --user-agent "Mozilla" --fail --location --silent --show-error \
        --retry 5 --retry-delay 5 --retry-connrefused \
        -o /whmcs/whmcs.zip \
        https://releases.whmcs.com/v2/pkgs/whmcs-${WHMCS_RELEASE}-release.1.zip && \
    ACTUAL_SHA256=$(sha256sum /whmcs/whmcs.zip | awk '{print $1}') && \
    echo "SHA256: whmcs-${WHMCS_RELEASE}-release.1.zip = ${ACTUAL_SHA256}" && \
    if [ -n "${WHMCS_SHA256}" ]; then \
        echo "${WHMCS_SHA256}  /whmcs/whmcs.zip" | sha256sum -c -; \
        echo "WHMCS SHA256 verified."; \
    else \
        echo "WARNING: WHMCS_SHA256 not set; skipping WHMCS zip verification." >&2; \
    fi

COPY root/ /

# ssmtp service for SMTP Relay
# COPY --from=ajoergensen/baseimage-ubuntu /etc/service/. /etc/service/

VOLUME /config

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 CMD curl -fsSL -o /dev/null http://127.0.0.1/ || exit 1
