#!/bin/sh
set -e

# Default PORT to 80 if not provided by Render
PORT="${PORT:-80}"
echo "Configuring Nginx to listen on port ${PORT}..."
sed -i "s/\${PORT}/${PORT}/g" /etc/nginx/http.d/default.conf

# Ensure required directories exist and have proper permissions
mkdir -p /var/www/html/storage/framework/cache/data \
         /var/www/html/storage/framework/sessions \
         /var/www/html/storage/framework/views \
         /var/www/html/storage/logs \
         /var/www/html/bootstrap/cache

chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Create storage symlink if it doesn't exist
php artisan storage:link --no-interaction || true

# Run Laravel optimizations for production
echo "Caching Laravel configuration, routes, and views..."
php artisan config:cache || true
php artisan route:cache || true
php artisan view:cache || true

# Run database migrations (Neon PostgreSQL)
if [ "${AUTORUN_MIGRATIONS:-true}" = "true" ]; then
    echo "Running database migrations on Neon PostgreSQL..."
    php artisan migrate --force || echo "Migration failed or database not reachable yet. Proceeding with startup..."
fi

echo "Starting Nginx and PHP-FPM via Supervisord..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
