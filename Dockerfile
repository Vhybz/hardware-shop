FROM php:8.2-cli

# Install system dependencies & PostgreSQL driver
RUN apt-get update && apt-get install -y \
    libpq-dev \
    zip \
    unzip \
    git \
    curl \
    && docker-php-ext-install pdo pdo_pgsql

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /app

# Copy application files
COPY . .

# Install Composer packages
RUN composer install --no-dev --optimize-autoloader

# Expose port and start Laravel server
EXPOSE 8000
CMD php artisan serve --host=0.0.0.0 --port=8000
