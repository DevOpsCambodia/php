FROM sothy/php:8.4.16-fpm-bookworm

WORKDIR /var/www/html

# Copy application files
COPY --chown=www-data:www-data . /var/www/html/

# Copy PHP configuration files
COPY cli.php.ini /usr/local/etc/php/php.ini
COPY fpm.php.ini /usr/local/etc/php-fpm.d/zz-custom.ini

# Copy supervisor configuration
# COPY supervisor.conf /etc/supervisor/conf.d/
ARG NODE_VERSION=22
ARG MYSQL_CLIENT="mysql-client"
ARG POSTGRES_VERSION=17

# Install system dependencies first
RUN apt-get update && apt-get upgrade -y \
    && mkdir -p /etc/apt/keyrings \
    && apt-get install -y gnupg gosu curl ca-certificates zip unzip git supervisor sqlite3 \
       libcap2-bin libpng-dev python3 dnsutils librsvg2-bin fswatch ffmpeg nano \
    && curl -sS 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xb8dc7e53946656efbce4c1dd71daeaab4ad4cab6' | gpg --dearmor | tee /etc/apt/keyrings/ppa_ondrej_php.gpg > /dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/ppa_ondrej_php.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu noble main" > /etc/apt/sources.list.d/ppa_ondrej_php.list \
    && apt-get update \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install -g npm \
    && npm install -g pnpm \
    && npm install -g bun \
    && npx -y playwright install-deps \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /etc/apt/keyrings/yarn.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    && curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/keyrings/pgdg.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt noble-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y yarn \
    && apt-get install -y ${MYSQL_CLIENT} \
    && apt-get install -y postgresql-client-${POSTGRES_VERSION} \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
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

# CMD ["/bin/bash", "-c", "supervisord -c /etc/supervisor/supervisord.conf && nginx -g 'daemon off;'"]
CMD ["/bin/bash", "-c", "php-fpm -D && nginx -g 'daemon off;'"]
