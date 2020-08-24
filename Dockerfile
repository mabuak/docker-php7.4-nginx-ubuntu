FROM ubuntu:focal
LABEL maintainer="Fachruzi Ramadhan <fachruzi.ramadhan@gmail.com>"
# Install packages
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git-core \
        make \
        openssh-client \
        openssl \
        unzip \
        vim \
        wget \
        gnupg2 \
        lsb-release
# Nginx 1.18.0
RUN \
    wget --quiet -O - https://nginx.org/keys/nginx_signing.key | apt-key add - \
    && echo "deb http://nginx.org/packages/mainline/ubuntu `lsb_release -cs` nginx" >> /etc/apt/sources.list.d/nginx.list \
    && echo "deb-src http://nginx.org/packages/mainline/ubuntu `lsb_release -cs` nginx" >> /etc/apt/sources.list.d/nginx.list\
    && apt-get update && apt-get install -y --no-install-recommends nginx \
    # forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log
EXPOSE 80
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata
# PHP 7.4
RUN \
    apt-get install -y --no-install-recommends software-properties-common \
    && LANG=C.UTF-8 add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        php7.4-bcmath \
        php7.4-cli \
        php7.4-common \
        php7.4-curl \
        php7.4-dev \
        php7.4-fpm \
        php7.4-gd \
        php7.4-intl \
        php7.4-json \
        php7.4-mbstring \
        php7.4-mysql \
        php7.4-opcache \
        php7.4-pgsql \
        php7.4-sqlite3 \
        php7.4-xml \
        php7.4-zip \
        php7.4-iconv \
        php7.4-ctype \
        php7.4-fileinfo \
        php7.4-pdo \
        php7.4-tokenizer \
        php-apcu \
        php-imagick \
        php-mongodb \
        php-redis \
        php-xdebug \
    # forward logs to docker log collector
    && ln -sf /dev/stdout /var/log/php7.4-fpm.log
# Config PHP and NGINX
RUN \
    mkdir -p /run/php \
    && chown root:root /run/php \
    && sed -i "s/;date.timezone =.*/date.timezone = Asia\/Jakarta/g" /etc/php/7.4/fpm/php.ini \
    && sed -i "s/;date.timezone =.*/date.timezone = Asia\/Jakarta/g" /etc/php/7.4/cli/php.ini \
    && sed -i "s/upload_max_filesize =.*/upload_max_filesize = 250M/g" /etc/php/7.4/fpm/php.ini \
    && sed -i "s/memory_limit = 128M/memory_limit = 512M/g" /etc/php/7.4/fpm/php.ini \
    && sed -i "s/post_max_size =.*/post_max_size = 250M/g" /etc/php/7.4/fpm/php.ini \
    && sed -i "s/user = www-data/user = root/g" /etc/php/7.4/fpm/pool.d/www.conf \
    && sed -i "s/group = www-data/group = root/g" /etc/php/7.4/fpm/pool.d/www.conf \
    && sed -i "s/listen.owner = www-data/listen.owner = root/g" /etc/php/7.4/fpm/pool.d/www.conf \
    && sed -i "s/listen.group = www-data/listen.group = root/g" /etc/php/7.4/fpm/pool.d/www.conf \
    && sed -i "s/pm = dynamic/pm = ondemand/g" /etc/php/7.4/fpm/pool.d/www.conf \
    && sed -i "s/pm.max_children = 5/pm.max_children = 25/g" /etc/php/7.4/fpm/pool.d/www.conf \
    && sed -i "s/;pm.process_idle_timeout = 10s;/pm.process_idle_timeout = 10s;/g" /etc/php/7.4/fpm/pool.d/www.conf \
    && sed -i "s/worker_processes 2;/worker_processes auto;/g" /etc/nginx/nginx.conf \
    && sed -i "s/listen       80;/listen       80    default_server;/g" /etc/nginx/conf.d/default.conf \
    # clear cache
    && apt-get clean \
    && apt-get autoremove --purge \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
# NodeJS and NPM
RUN \
    apt-get update \
    && curl -sL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs jpegoptim \
    && npm install -g npm \
    # Install Yarn
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install yarn \
    && apt-get install libelf1
# Project
RUN mkdir -p /home/projects
VOLUME /home/projects
WORKDIR /home/projects
# Docker Container
COPY entrypoint.sh /
RUN chmod 755 /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]