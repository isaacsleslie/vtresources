# Step 1: Build Frontend Assets using Node
FROM node:16 AS asset-builder
WORKDIR /app
COPY package*.json webpack.mix.js ./
COPY resources/ ./resources/
RUN npm install && npm run prod

# Step 2: Use PHP 7.4 Apache to match the codebase version safely
FROM php:7.4-apache

# Install required system libraries and PHP extensions
RUN apt-get update && apt-get install -y \
    git unzip libzip-dev libpng-dev libjpeg-dev libfreetype6-dev libxml2-dev libonig-dev \
    && docker-php-ext-install bcmath ctype fileinfo opcache pdo pdo_mysql zip xml mbstring

# Enable Apache Mod_Rewrite
RUN a2enmod rewrite

# Setup Composer
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer

# Copy code into web root
WORKDIR /var/www/html
COPY . .

# Ensure an environment file exists
RUN cp .env.example .env || echo "APP_ENV=production" > .env

# Copy compiled assets from Step 1
COPY --from=asset-builder /app/public/js ./public/js
COPY --from=asset-builder /app/public/css ./public/css

# Set comprehensive permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Install dependencies matching PHP 7.4 specs cleanly
RUN composer install --no-interaction --optimize-autoloader --ignore-platform-reqs

# Point Apache to Laravel's public folder
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

EXPOSE 80
