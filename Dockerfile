FROM php:8.4.16-fpm-bookworm

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
    libzip-dev \
    libicu-dev \
    libonig-dev \
    libsqlite3-dev \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install -j$(nproc) \
    pdo_pgsql \
    pgsql \
    gd \
    opcache \
    soap \
    zip \
    intl \
    pdo_sqlite \
    && pecl install imagick redis \
    && docker-php-ext-enable imagick redis

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

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
    && COMPOSER_PROCESS_TIMEOUT=600 composer clear-cache && \
    rm -rf vendor/ composer.lock && \
    composer install --no-interaction --prefer-dist --optimize-autoloader

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
    && chmod -R 755 /var/www/html/bootstrap/cache

# Configure Nginx
RUN rm -f /etc/nginx/sites-enabled/default
COPY default.conf /etc/nginx/sites-enabled/

EXPOSE 80

STOPSIGNAL SIGTERM

CMD ["/bin/bash", "-c", "supervisord -c /etc/supervisor/supervisord.conf && nginx -g 'daemon off;'"]