FROM php:8.3-fpm

ENV ACCEPT_EULA=Y

# php 와 연동해서 필요한 것
RUN apt-get update && apt-get install -y \
        apt-transport-https \
        gnupg2 \
        zlib1g-dev \
        libmcrypt-dev \
        libpq-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        git \
        libzip-dev \
        unzip \
        icu-devtools \
        libicu-dev
RUN rm -rf /var/lib/apt/lists/*

# 주요 php extention 설치
RUN docker-php-ext-install pcntl
RUN docker-php-ext-install -j$(nproc) pdo
RUN docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/
RUN docker-php-ext-install -j$(nproc) gd
RUN docker-php-ext-install zip
RUN docker-php-ext-install intl

# composer 설치
RUN curl -sS https://getcomposer.org/installer | \
    php -- --install-dir=/usr/bin/ --filename=composer

# SQL Server ODBC 17 Driver 설치
RUN curl https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc
RUN curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | tee /etc/apt/sources.list.d/mssql-release.list
RUN apt-get update
RUN ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev
RUN echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bash_profile
RUN echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
RUN exec bash
# optional: for unixODBC development headers <- but required for install sqlsrv and pdo_sqlsrv
RUN apt-get install -y unixodbc-dev
# optional: kerberos library for debian-slim distributions
RUN apt-get install -y libgssapi-krb5-2
RUN rm -rf /var/lib/apt/lists/*

# PHP extention 설치
RUN pecl install sqlsrv
RUN pecl install pdo_sqlsrv

# PHP extention enable
RUN docker-php-ext-enable sqlsrv
RUN docker-php-ext-enable pdo_sqlsrv

# node js 20 LTS 설치
RUN apt-get update
RUN apt-get install -y ca-certificates curl gnupg
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

# redis 설치
RUN pecl install -o -f redis \
    &&  rm -rf /tmp/pear \
    &&  docker-php-ext-enable redis

# 지역 정보 수정
RUN ln -snf /usr/share/zoneinfo/Asia/Seoul /etc/localtime && \
    echo "Asia/Seoul" > /etc/timezone
