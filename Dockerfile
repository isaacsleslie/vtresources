# Step 1: Build Frontend Assets using Node
FROM node:16 AS asset-builder
WORKDIR /app
COPY package*.json webpack.mix.js ./
COPY resources/ ./resources/
RUN npm install && npm run prod

# Step 2: Set up PHP and Web Server
FROM php:8.1-apache

# Install required system libraries and PHP extensions from the readme
RUN apt-get update && apt-get install -y \
    git unzip libzip-dev libpng-dev libjpeg-dev libfreetype6-dev libxml2-dev \
    && docker-php-ext-install bcmath ctype fileinfo opcache pdo pdo_mysql zip xml

# Enable Apache Mod_Rewrite (Requested in readme web server config)
RUN a2enmod rewrite

# Setup Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy code into web root
WORKDIR /var/www/html
COPY . .

# Copy compiled assets from Step 1
COPY --from=asset-builder /app/public/js ./public/js
COPY --from=asset-builder /app/public/css ./public/css

# Install backend dependencies
RUN composer install --no-interaction --optimize-autoloader

# Set permissions as requested in readme (chmod 755 equivalent for web server user)
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Point Apache to Laravel's public folder
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

EXPOSE 80
