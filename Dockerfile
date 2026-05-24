# Step 1: Build Frontend Assets using Node
FROM node:16 AS asset-builder
WORKDIR /app
# Only copy files that explicitly exist in this repo's root
COPY package*.json webpack.mix.js ./
COPY resources/ ./resources/
RUN npm install && npm run prod

# Step 2: Set up PHP 8.2 and Web Server
FROM php:8.2-apache

# Install required system libraries and PHP extensions
RUN apt-get update && apt-get install -y \
    git unzip libzip-dev libpng-dev libjpeg-dev libfreetype6-dev libxml2-dev libonig-dev \
    && docker-php-ext-install bcmath ctype fileinfo opcache pdo pdo_mysql zip xml mbstring

# Enable Apache Mod_Rewrite
RUN a2enmod rewrite

# Setup Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy code into web root
WORKDIR /var/www/html
COPY . .

# Copy compiled assets from Step 1
COPY --from=asset-builder /app/public/js ./public/js
COPY --from=asset-builder /app/public/css ./public/css

# Set comprehensive permissions so composer scripts can execute safely
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Update backend dependencies directly to bypass frozen lockfile conflicts
RUN composer update --no-interaction --optimize-autoloader --ignore-platform-reqs

# Point Apache to Laravel's public folder
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

EXPOSE 80
