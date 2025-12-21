# Use official PHP with Apache
FROM php:8.2-apache

# Install MySQL extensions
RUN docker-php-ext-install mysqli pdo pdo_mysql

# Enable mod_rewrite (if you use clean URLs)
RUN a2enmod rewrite

# Copy app code into container
COPY ./src /var/www/html/

WORKDIR /var/www/html

EXPOSE 80
