FROM php:8.3.6-apache

USER root
RUN whoami

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        vim \
        git \
        wget \
        rsync \
        default-mysql-client \
        libpng-dev \
        icu-devtools \
        libicu-dev \
        libjpeg-dev \
        graphicsmagick-libmagick-dev-compat \
        libzip-dev \
        sudo \
        less \
        curl \
        python3 \
        python3-pip \
        python3-venv \
        libxml2-dev && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y iputils-ping dnsutils zip

RUN docker-php-ext-configure bcmath
RUN docker-php-ext-configure exif
RUN docker-php-ext-configure gd --with-freetype --with-jpeg
RUN docker-php-ext-configure intl
RUN docker-php-ext-configure pdo_mysql 
RUN docker-php-ext-configure mysqli
RUN docker-php-ext-configure zip
RUN docker-php-ext-install -j "$(nproc)" bcmath exif gd intl pdo_mysql mysqli zip opcache soap

ARG APP
COPY ${APP}/ /var/www/html/
ENV WUT_NAME=${APP}

RUN chmod 0755 /var/www/html

COPY php.ini /usr/local/etc/php
COPY ports.conf /etc/apache2/ports.conf
RUN a2dissite 000-default.conf
COPY web-8081.conf /etc/apache2/sites-available/web-8081.conf
RUN a2ensite web-8081.conf
RUN a2enmod rewrite

#COPY proxy /proxy

COPY entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

#CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]

