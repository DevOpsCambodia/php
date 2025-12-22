FROM ubuntu
WORKDIR /var/www/html
RUN apt update && apt-get install tzdata cron supervisor software-properties-common gnupg2 ca-certificates lsb-release apt-transport-https -y
RUN add-apt-repository ppa:ondrej/php -y
RUN apt update
RUN apt install nginx php8.2 php8.2-fpm phpunit git unzip curl wget php8.2-common php8.2-pgsql php8.2-xml php8.2-xmlrpc php8.2-curl php8.2-gd php8.2-imagick php8.2-cli php8.2-imap php8.2-mbstring php8.2-opcache php8.2-soap php8.2-zip php8.2-redis php8.2-intl -y
RUN apt install -y php8.2-dev php8.2-sqlite3 git --no-install-recommends

RUN wget https://getcomposer.org/composer-stable.phar -O /usr/local/bin/composer && chmod +x /usr/local/bin/composer
RUN wget https://github.com/elastic/apm-agent-php/releases/download/v1.8.1/apm-agent-php_1.8.1_all.deb
RUN dpkg -i apm-agent-php_1.8.1_all.deb

COPY --chown=www-data:www-data . /var/www/html/
COPY cli.php.ini /etc/php/8.2/cli/php.ini
COPY fpm.php.ini /etc/php/8.2/fpm/php.ini
COPY 98-elastic-apm.ini /etc/php/8.2/fpm/conf.d/98-elastic-apm.ini
COPY 98-elastic-apm.ini /etc/php/8.2/cli/conf.d/98-elastic-apm.ini
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
CMD service php8.2-fpm start && nginx -g "daemon off;"