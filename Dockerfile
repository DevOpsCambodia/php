FROM php:8.4.16-fpm

WORKDIR /var/www/html

# Install system dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    cron \
    supervisor \
    git \
    unzip \
    curl \
    wget \
    libpq-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libpng-dev \
    libmagickwand-dev \
    libc-client2007e-dev \
    libkrb5-dev \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install -j$(nproc) \
    pdo_pgsql \
    pgsql \
    xml \
    xmlrpc \
    curl \
    gd \
    imap \
    mbstring \
    opcache \
    soap \
    zip \
    intl \
    pdo_sqlite \
    && pecl install imagick redis \
    && docker-php-ext-enable imagick redis

# Install Composer
RUN wget https://getcomposer.org/composer-stable.phar -O /usr/local/bin/composer \
    && chmod +x /usr/local/bin/composer

# Copy application files
COPY --chown=www-data:www-data . /var/www/html/

# Copy PHP configuration files
COPY cli.php.ini /usr/local/etc/php/php.ini
COPY fpm.php.ini /usr/local/etc/php-fpm.d/zz-custom.ini

# Copy supervisor configuration
COPY supervisor.conf /etc/supervisor/conf.d/

# Install Composer dependencies
RUN composer clear-cache \
    && COMPOSER_PROCESS_TIMEOUT=600 composer update \
    && COMPOSER_PROCESS_TIMEOUT=600 composer install --optimize-autoloader --no-dev

# Run Laravel artisan commands
RUN php artisan config:cache \
    && php artisan migrate --force \
    && php artisan optimize:clear \
    && php artisan cache:clear \
    && php artisan route:clear \
    && php artisan config:clear

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage \
    && chown -R www-data:www-data /var/www/html/bootstrap/cache

# Configure Nginx
RUN rm -f /etc/nginx/sites-enabled/default
COPY default.conf /etc/nginx/sites-enabled/

EXPOSE 80

STOPSIGNAL SIGTERM

CMD supervisord -c /etc/supervisor/supervisord.conf && nginx -g "daemon off;"