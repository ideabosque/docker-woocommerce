#!/bin/bash
set -e

# If the volume mount is empty, install WordPress
if [ ! -f /var/www/html/wp-includes/version.php ]; then
    echo "WordPress not found in /var/www/html, downloading..."
    wp core download --path=/var/www/html --allow-root
    chown -R apache:apache /var/www/html
fi

# Wait for MariaDB to be ready
echo "Waiting for database..."
for i in $(seq 1 30); do
    if php -r "new PDO('mysql:host=${WORDPRESS_DB_HOST};port=3306', '${WORDPRESS_DB_USER}', '${WORDPRESS_DB_PASSWORD}');" 2>/dev/null; then
        echo "Database is ready."
        break
    fi
    echo "Attempt $i/30 - database not ready yet..."
    sleep 2
done

# Generate wp-config.php if it doesn't exist
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "Creating wp-config.php..."
    wp config create \
        --dbname="${WORDPRESS_DB_NAME}" \
        --dbuser="${WORDPRESS_DB_USER}" \
        --dbpass="${WORDPRESS_DB_PASSWORD}" \
        --dbhost="${WORDPRESS_DB_HOST}" \
        --path=/var/www/html \
        --allow-root

    wp config set WP_DEBUG "${WP_DEBUG:-false}" --raw --path=/var/www/html --allow-root
    wp config set WP_MEMORY_LIMIT '256M' --path=/var/www/html --allow-root
fi

# Install WordPress if not already installed
if ! wp core is-installed --path=/var/www/html --allow-root 2>/dev/null; then
    echo "Installing WordPress..."
    wp core install \
        --url="${WORDPRESS_URL:-http://localhost:8080}" \
        --title="${WORDPRESS_TITLE:-WooCommerce Store}" \
        --admin_user="${WORDPRESS_ADMIN_USER:-admin}" \
        --admin_password="${WORDPRESS_ADMIN_PASSWORD:-admin}" \
        --admin_email="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}" \
        --path=/var/www/html \
        --allow-root
fi

# Install and activate WooCommerce via WP-CLI (handles download + activation)
if ! wp plugin is-active woocommerce --path=/var/www/html --allow-root 2>/dev/null; then
    echo "Installing and activating WooCommerce..."
    wp plugin install woocommerce --activate --path=/var/www/html --allow-root
fi

# Install and activate Storefront theme (WooCommerce's official theme)
CURRENT_THEME=$(wp theme status --path=/var/www/html --allow-root 2>/dev/null | grep 'Active:' | awk '{print $NF}')
if [ "$CURRENT_THEME" != "storefront" ]; then
    echo "Installing and activating Storefront theme..."
    wp theme install storefront --activate --path=/var/www/html --allow-root
fi

# Ensure permalinks are set and rewrite rules are flushed
wp rewrite structure '/%postname%/' --path=/var/www/html --allow-root
wp rewrite flush --hard --path=/var/www/html --allow-root

# Ensure .htaccess exists with proper rewrite rules
if [ ! -f /var/www/html/.htaccess ]; then
    echo "Creating .htaccess..."
    cat > /var/www/html/.htaccess << 'HTACCESS'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
HTACCESS
fi

# Ensure correct ownership
chown -R apache:apache /var/www/html

# Hand off to CMD (supervisord via docker-compose)
exec "$@"
