# syntax=docker/dockerfile:1.4
FROM lscr.io/linuxserver/baseimage-ubuntu:focal

ARG BUILD_DATE
LABEL build_date="Build-date:- ${BUILD_DATE}"
LABEL maintainer="darthShadow"

ARG TARGETARCH
# 7.4
ARG PHP_RELEASE
# 8.4.1
ARG WHMCS_RELEASE

ENV PHP_VERSION=${PHP_RELEASE}

ENV TZ="UTC" PGID="1000" PUID="1000"

ENV AUTH_USER="" AUTH_PASS=""

ENV WHMCS_SERVER_IP="\$server_addr" WHMCS_SERVER_URL="_"

ENV DEBIAN_FRONTEND="noninteractive"

# Install nginx and PHP
RUN echo "**** Install Dependencies ****" && \
    apt-get -y update && \
    apt-get -y install --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        cron \
        curl \
        htop \
        jq \
        less \
        net-tools \
        openssl \
        software-properties-common \
        unrar \
        unzip \
        vim \
        wget \
        zip && \
    echo "**** Add PPA: ondrej/php ****" && \
    add-apt-repository -y "ppa:ondrej/php" && \
    echo "**** Add PPA: ondrej/nginx-mainline ****" && \
    add-apt-repository -y "ppa:ondrej/nginx-mainline" && \
    echo "**** Update Repositories ****" && \
    apt-get -y update && \
    echo "**** Upgrade Packages ****" && \
    apt-get -y upgrade && \
    echo "**** Install Nginx Packages ****" && \
    apt-get -y install --no-install-recommends \
        apache2-utils \
        nginx-full && \
    echo "**** Install PHP Packages ****" && \
    apt-get -y install --no-install-recommends \
        php-pear \
        php${PHP_VERSION} \
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
        php${PHP_VERSION}-json \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-xmlrpc \
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
    rm /var/log/lastlog /var/log/faillog

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

# Configure production php.ini for CLI
# * Max execution time = 1800 seconds
# * Set the timezone = ${TZ}
RUN sed -r -i \
    -e "s@^;date\.timezone\s+.*@date\.timezone=${TZ}@" \
    -e "s/(max_execution_time =) ([0-9]+)/\1 1800/" \
    /etc/php/${PHP_VERSION}/cli/php.ini

# Setup SourceGuardian for PHP
RUN case ${TARGETARCH} in \
         "amd64")  SOURCEGUARDIAN_ARCH="x86_64"  ;; \
         "arm64")  SOURCEGUARDIAN_ARCH="aarch64" ;; \
    esac && \
    echo "**** Installing SourceGuardian for PHP: Architecture: ${SOURCEGUARDIAN_ARCH} ****" && \
    mkdir /tmp/sourceguardian && cd /tmp/sourceguardian && \
    curl --user-agent "Mozilla" -o sourceguardian.zip https://www.sourceguardian.com/loaders/download/loaders.linux-${SOURCEGUARDIAN_ARCH}.zip && \
    unzip -q sourceguardian.zip && mkdir -p /usr/lib/php/sourceguardian && cp -vf ixed.${PHP_VERSION}.lin /usr/lib/php/sourceguardian/ && \
    echo "zend_extension=/usr/lib/php/sourceguardian/ixed.${PHP_VERSION}.lin" > /etc/php/${PHP_VERSION}/mods-available/00-sourceguardian.ini && \
    ln -sf /etc/php/${PHP_VERSION}/mods-available/00-sourceguardian.ini /etc/php/${PHP_VERSION}/fpm/conf.d/00-sourceguardian.ini && \
    ln -sf /etc/php/${PHP_VERSION}/mods-available/00-sourceguardian.ini /etc/php/${PHP_VERSION}/cli/conf.d/00-sourceguardian.ini && \
    rm -rf /tmp/sourceguardian

# Setup ionCube for PHP
RUN case ${TARGETARCH} in \
         "amd64")  IONCUBE_ARCH="x86-64"  ;; \
         "arm64")  IONCUBE_ARCH="aarch64" ;; \
    esac && \
    echo "**** Installing ionCube for PHP: Architecture: ${IONCUBE_ARCH} ****" && \
    mkdir /tmp/ioncube && cd /tmp/ioncube && \
    curl --user-agent "Mozilla" -o ioncube.zip http://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_${IONCUBE_ARCH}.zip && \
    unzip -q ioncube.zip && mkdir -p /usr/lib/php/ioncube && cp -vf ioncube/ioncube_loader_lin_${PHP_VERSION}.so /usr/lib/php/ioncube/ && \
    echo "zend_extension = /usr/lib/php/ioncube/ioncube_loader_lin_${PHP_VERSION}.so" > /etc/php/${PHP_VERSION}/mods-available/00-ioncube.ini && \
    ln -sf /etc/php/${PHP_VERSION}/mods-available/00-ioncube.ini /etc/php/${PHP_VERSION}/fpm/conf.d/00-ioncube.ini && \
    ln -sf /etc/php/${PHP_VERSION}/mods-available/00-ioncube.ini /etc/php/${PHP_VERSION}/cli/conf.d/00-ioncube.ini && \
    rm -rf /tmp/ioncube

# Setup nginx
RUN echo "**** Setting Up nginx ****" && \
    mkdir -p /var/www && \
    chown -R abc:abc /var/www && \
    ln -svf /dev/stdout /var/log/nginx/access.log && \
    ln -svf /dev/stderr /var/log/nginx/error.log && \
    rm -vf /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*

# Setup WHMCS
RUN echo "**** Setting WHMCS Release Version ****" && \
    if [ "x${WHMCS_RELEASE}" = "x" ]; then \
        WHMCS_RELEASE=$(curl -sX GET 'https://api1.whmcs.com/download/latest?type=stable' \
        | jq -r '.version'); \
    fi && \
    echo "**** Downloading WHMCS Release: ${WHMCS_RELEASE} ****" && \
    mkdir -p /whmcs && \
    curl --user-agent "Mozilla" -o /whmcs/whmcs.zip -L \
        https://releases.whmcs.com/v2/pkgs/whmcs-${WHMCS_RELEASE}-release.1.zip

COPY root/ /

# ssmtp service for SMTP Relay
# COPY --from=ajoergensen/baseimage-ubuntu /etc/service/. /etc/service/

VOLUME /config

EXPOSE 80
