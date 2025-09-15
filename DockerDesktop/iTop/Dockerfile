FROM php:8.1-apache

# Installation des extensions PHP requises pour iTop
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libldap2-dev \
    libxml2-dev \
    graphviz \
    unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    mysqli \
    pdo \
    pdo_mysql \
    zip \
    ldap \
    soap \
    opcache \
    && pecl install apcu \
    && docker-php-ext-enable apcu \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configuration Apache
RUN a2enmod rewrite headers

# Configuration PHP
RUN { \
    echo 'memory_limit=256M'; \
    echo 'post_max_size=64M'; \
    echo 'upload_max_filesize=32M'; \
    echo 'max_execution_time=300'; \
    echo 'max_input_time=300'; \
    echo 'max_input_vars=5000'; \
    echo 'session.gc_maxlifetime=1440'; \
    echo 'session.save_path=/var/lib/php/sessions'; \
    echo 'apc.enabled=1'; \
    echo 'apc.enable_cli=1'; \
    echo 'xdebug.mode=debug'; \
    echo 'xdebug.start_with_request=yes'; \
    echo 'xdebug.client_host=host.docker.internal'; \
    } > /usr/local/etc/php/conf.d/itop.ini

# Créer le répertoire des sessions PHP
RUN mkdir -p /var/lib/php/sessions \
    && chown -R www-data:www-data /var/lib/php/sessions \
    && chmod 1733 /var/lib/php/sessions

# Création des répertoires nécessaires
RUN mkdir -p /var/www/html/data \
    && mkdir -p /var/www/html/log \
    && mkdir -p /var/www/html/conf \
    && mkdir -p /var/www/html/env-production \
    && mkdir -p /var/www/html/extensions

# Permissions appropriées
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

EXPOSE 80

CMD ["apache2-foreground"]