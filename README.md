# Docker WooCommerce on AlmaLinux

Dockerized WooCommerce stack running on AlmaLinux 10 with Apache, PHP 8.2 (Remi), MariaDB, and Supervisord.

## Stack

| Component    | Details                          |
|-------------|----------------------------------|
| OS          | AlmaLinux 10                     |
| Web Server  | Apache (prefork MPM)             |
| PHP         | 8.2 via Remi repository          |
| Database    | MariaDB 10.11                    |
| CMS         | WordPress (latest)               |
| E-Commerce  | WooCommerce (latest)             |
| Theme       | Storefront                       |
| Process Mgr | Supervisord (Apache + crond)     |

## Quick Start

1. **Clone the repository:**

   ```bash
   git clone <repo-url>
   cd docker-woocommerce
   ```

2. **Create your `.env` file:**

   ```bash
   cp .env.example .env
   ```

   Edit `.env` and update the passwords and settings as needed.

3. **Build and start:**

   ```bash
   docker compose up --build -d
   ```

4. **Access the site:**

   - Store: http://localhost:8081
   - Admin: http://localhost:8081/wp-admin

## Configuration

All configuration is managed through the `.env` file:

### Host Paths

| Variable       | Description                  | Default      |
|---------------|------------------------------|--------------|
| `WP_HOST_DIR` | Host path for WordPress data | `./wp_data`  |
| `DB_HOST_DIR` | Host path for MariaDB data   | `./db_data`  |

### WordPress

| Variable                  | Description              | Default                  |
|--------------------------|--------------------------|--------------------------|
| `WORDPRESS_DB_HOST`      | Database hostname         | `mariadb`                |
| `WORDPRESS_DB_NAME`      | Database name             | `woocommerce`            |
| `WORDPRESS_DB_USER`      | Database user             | `woocommerce`            |
| `WORDPRESS_DB_PASSWORD`  | Database password         | `change_me`              |
| `WORDPRESS_URL`          | Site URL                  | `http://localhost:8081`  |
| `WORDPRESS_TITLE`        | Site title                | `WooCommerce Store`      |
| `WORDPRESS_ADMIN_USER`   | Admin username            | `admin`                  |
| `WORDPRESS_ADMIN_PASSWORD`| Admin password           | `change_me_admin`        |
| `WORDPRESS_ADMIN_EMAIL`  | Admin email               | `admin@example.com`      |
| `WP_DEBUG`               | Enable WordPress debug    | `false`                  |

### MariaDB

| Variable              | Description           | Default          |
|----------------------|------------------------|------------------|
| `MYSQL_ROOT_PASSWORD`| MariaDB root password  | `change_me_root` |

## Project Structure

```
docker-woocommerce/
├── Dockerfile            # AlmaLinux 10 + Apache + PHP 8.2 image
├── docker-compose.yml    # Service definitions (woocommerce + mariadb)
├── entrypoint.sh         # Runtime setup (WP download, config, install)
├── supervisord.conf      # Supervisord main config
├── supervisor/
│   ├── httpd.ini         # Apache service definition
│   └── crond.ini         # Cron service definition
├── mu-plugins/           # WordPress must-use plugins
├── .env.example          # Environment variable template
└── .gitignore
```

## How It Works

On first boot, the entrypoint script:

1. Downloads WordPress if `/var/www/html` is empty (host volume mount)
2. Waits for MariaDB to be healthy
3. Generates `wp-config.php`
4. Installs WordPress core
5. Installs and activates WooCommerce plugin
6. Installs and activates Storefront theme
7. Configures permalinks and `.htaccess` rewrite rules
8. Copies must-use plugins
9. Hands off to Supervisord which manages Apache and crond

Subsequent restarts skip already-completed steps.

## Commands

```bash
# Start
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f woocommerce

# Rebuild from scratch
docker compose down
rm -rf ./wp_data/* ./db_data/*
docker compose up --build -d

# Access WP-CLI inside the container
docker compose exec woocommerce wp --path=/var/www/html --allow-root plugin list
```
