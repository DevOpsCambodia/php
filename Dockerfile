FROM ubuntu
WORKDIR /var/www/html
RUN apt update && apt-get install tzdata cron supervisor software-properties-common gnupg2 ca-certificates lsb-release apt-transport-https -y
RUN add-apt-repository ppa:ondrej/php -y
RUN apt update
RUN apt install nginx php8.4 php8.4-fpm phpunit git unzip curl wget php8.4-common php8.4-pgsql php8.4-xml php8.4-xmlrpc php8.4-curl php8.4-gd php8.4-imagick php8.4-cli php8.4-imap php8.4-mbstring php8.4-opcache php8.4-soap php8.4-zip php8.4-redis php8.4-intl -y
RUN apt install -y php8.4-dev php8.4-sqlite3 git --no-install-recommends

RUN wget https://getcomposer.org/composer-stable.phar -O /usr/local/bin/composer && chmod +x /usr/local/bin/composer

COPY --chown=www-data:www-data . /var/www/html/
COPY cli.php.ini /etc/php/8.4/cli/php.ini
COPY fpm.php.ini /etc/php/8.4/fpm/php.ini
#COPY configuration/supervisor.conf /etc/supervisor/conf.d/
RUN composer clear-cache
RUN COMPOSER_PROCESS_TIMEOUT=600 composer update
RUN COMPOSER_PROCESS_TIMEOUT=600 composer install --optimize-autoloader --no-dev
#RUN composer update
#RUN composer install --optimize-autoloader --no-dev
##RUN php artisan key:generate --force
RUN php artisan config:cache
RUN php artisan migrate --force
#RUN php artisan passport:keys --force
#RUN php artisan generate:jwt-keys
#RUN php artisan vendor:publish --tag=passport-config
##RUN php artisan db:seed
#RUN php artisan config:clear
#RUN php artisan key:generate
#RUN php artisan config:clear
RUN php artisan optimize:clear
#RUN php artisan cloudflare:reload
##RUN php artisan opcache:clear
RUN php artisan cache:clear
RUN php artisan route:clear
RUN php artisan config:clear
#RUN chown www-data:www-data /var/www/html/storage/oauth-*.key
#RUN chmod 0600 /var/www/html/storage/oauth-*.key
#RUN chown www-data:www-data /var/www/html/storage/jwt-*.key
#RUN chmod 0600 /var/www/html/storage/jwt-*.key

#RUN chmod a+x /var/www/html/run.sh
#ADD crontab /etc/cron.d/crontab
#RUN chmod 0600 /etc/cron.d/crontab
#RUN crontab /etc/cron.d/crontab
#RUN touch /var/log/cron.log

#COPY start-cron /usr/sbin
#RUN chmod +x /usr/sbin/start-cron
RUN chown -R www-data:www-data .
#RUN chmod -R ug+rwx /var/www/html/storage /var/www/html/bootstrap/cache
#RUN chmod -R 775 storage/ 
RUN chmod -R a+rwx storage/
RUN chmod -R ugo+rw bootstrap/
RUN chmod -R ugo+rw bootstrap/cache 
RUN chmod -R ugo+rw storage/logs
RUN chown -R www-data:www-data /var/www/html/storage 
RUN chown -R www-data:www-data /var/www/html/bootstrap/cache 
RUN chown -R www-data:www-data /var/www/html/storage/logs
RUN unlink /etc/nginx/sites-enabled/default
COPY default.conf /etc/nginx/sites-enabled/

EXPOSE 80
STOPSIGNAL SIGTERM
CMD service php8.4-fpm start && nginx -g "daemon off;"