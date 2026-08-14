# ==========================================
# Stage 1: Build Frontend Assets (Vite)
# ==========================================
FROM oven/bun:1-alpine AS frontend-builder
WORKDIR /app

COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile || bun install

COPY vite.config.js ./
COPY resources ./resources
COPY public ./public

RUN bun run build

# ==========================================
# Stage 2: Production PHP + Nginx Environment
# ==========================================
FROM php:8.3-fpm-alpine

# Set working directory
WORKDIR /var/www/html

# Install system dependencies
RUN apk update && apk add --no-cache \
    nginx \
    supervisor \
    curl \
    git \
    unzip \
    bash \
    sed

# Install PHP extensions via official extension installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions \
    pdo_pgsql \
    pdo_mysql \
    gd \
    imagick \
    zip \
    bcmath \
    opcache \
    intl \
    pcntl \
    exif

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy application files
COPY . .

# Copy compiled frontend assets from Stage 1
COPY --from=frontend-builder /app/public/build ./public/build

# Install PHP dependencies without dev packages
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist

# Copy configuration files
COPY docker/nginx.conf /etc/nginx/http.d/default.conf
COPY docker/php.ini /usr/local/etc/php/conf.d/custom.ini
COPY docker/supervisord.conf /etc/supervisord.conf
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

# Setup permissions
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache && \
    chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache && \
    chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Expose Render default port (injected dynamically via $PORT)
EXPOSE 80 10000

# Run entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
