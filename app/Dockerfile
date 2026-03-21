FROM php:8.2-apache
RUN a2enmod rewrite
RUN docker-php-ext-install mysqli pdo pdo_mysql
COPY ./src /var/www/html/
WORKDIR /var/www/html
EXPOSE 80
