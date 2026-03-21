FROM almalinux/10-base:latest

RUN dnf -y update && \
    dnf -y install epel-release && \
    dnf -y install https://rpms.remirepo.net/enterprise/remi-release-10.rpm && \
    dnf -y install \
        httpd \
        php82-php \
        php82-php-mysqlnd \
        php82-php-gd \
        php82-php-xml \
        php82-php-mbstring \
        php82-php-json \
        php82-php-zip \
        php82-php-curl \
        php82-php-intl \
        php82-php-bcmath \
        php82-php-soap \
        php82-php-opcache \
        php82-php-imagick \
        supervisor \
        cronie \
        unzip \
        curl \
        less && \
    ln -sf /opt/remi/php82/root/usr/bin/php /usr/bin/php && \
    dnf clean all

# Switch Apache to prefork MPM (required for non-threadsafe mod_php)
RUN sed -i 's/^LoadModule mpm_event_module/#LoadModule mpm_event_module/' /etc/httpd/conf.modules.d/00-mpm.conf && \
    sed -i 's/^#LoadModule mpm_prefork_module/LoadModule mpm_prefork_module/' /etc/httpd/conf.modules.d/00-mpm.conf

# Configure Apache to use PHP 8.2 from Remi
RUN echo 'LoadModule php_module /opt/remi/php82/root/usr/lib64/httpd/modules/libphp.so' > /etc/httpd/conf.modules.d/20-php82.conf && \
    echo -e '<FilesMatch \\.php$>\n    SetHandler application/x-httpd-php\n</FilesMatch>' > /etc/httpd/conf.d/php82.conf

# Apache configuration - enable rewrite module and AllowOverride for .htaccess
RUN sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf && \
    sed -i 's/^#LoadModule rewrite_module/LoadModule rewrite_module/' /etc/httpd/conf.modules.d/00-base.conf

# PHP configuration for WooCommerce
RUN echo -e "\n\
upload_max_filesize = 64M\n\
post_max_size = 64M\n\
memory_limit = 256M\n\
max_execution_time = 300\n\
max_input_vars = 3000\n" > /etc/opt/remi/php82/php.d/99-woocommerce.ini

# Install WP-CLI
RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp

# Create web root (WordPress + WooCommerce downloaded at runtime via entrypoint)
RUN mkdir -p /var/www/html && \
    chown -R apache:apache /var/www/html && \
    chmod -R 755 /var/www/html

# Supervisord configuration
COPY supervisord.conf /etc/supervisord.conf
COPY supervisor/*.ini /etc/supervisord.d/

# WordPress cron via system cron
RUN echo '*/5 * * * * apache /usr/bin/php /var/www/html/wp-cron.php > /dev/null 2>&1' > /etc/cron.d/wp-cron && \
    chmod 0644 /etc/cron.d/wp-cron

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
