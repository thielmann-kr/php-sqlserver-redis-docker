# syntax=docker/dockerfile:1
# -----------------------------------------------------------------------------
# thielmann PHP 8.2 보안 런타임 베이스 이미지
#
#   thielmann/php-sqlserver-redis-docker:<VERSION 파일의 태그>
#
# 소비 측(tms_laravel / tms_cds / thielmann_admin)은 반드시 불변 태그 + digest 로
# 참조한다.  예) FROM thielmann/php-sqlserver-redis-docker:8.2.36-bookworm-v1@sha256:...
# `latest` 는 더 이상 갱신하지 않는다(2023-12-04 의 PHP 8.2.13 이미지에 고정된 채로 둔다).
# `latest` 를 쓰는 기존 저장소가 예고 없이 PHP 버전이 바뀌지 않게 하기 위함이다.
#
# 구성(기존 tms_laravel php-base 블록 v1 과 동일 + PHP 8.2.36):
#   * 기반: 공식 php:8.2.36-fpm-bookworm, index digest 고정(태그 이동 영향 없음)
#     - PHP 2026-11-19 보안 릴리스: CVE-2026-129289(FPM request smuggling),
#       CVE-2026-126714 / CVE-2026-115560(session RCE), CVE-2026-129496 등
#   * 확장: pcntl, gd(freetype/jpeg), zip, intl, ftp(SSL), sodium(공식 내장)
#           pecl sqlsrv/pdo_sqlsrv 5.11.1, redis 6.0.2
#   * OS 의존: msodbcsql18 18.3.2.1-1, mssql-tools18 18.2.1.1-1, unixodbc,
#             libgssapi-krb5-2, nodejs 20.10.0, git/unzip, TZ=Asia/Seoul
#   * composer 2.6.5 (공식 이미지 digest 고정)
#   * opcache 미로드 유지(공식 이미지 기본값과 달리 기존 base 와 동일)
#   * session.upload_progress.enabled = 0
#     (CVE-2026-126714 / CVE-2026-115560 의 비인증 입력 경로 차단. Laravel 은 PHP
#      네이티브 세션/업로드 진행률을 쓰지 않으므로 기능 영향 없음)
# -----------------------------------------------------------------------------
FROM php:8.2.36-fpm-bookworm@sha256:3874fa1a0d2b3f02daac3e3c3fc844df761b42e00770405d1df244237ddcae2a

ENV ACCEPT_EULA=Y

RUN set -eux; \
    apt-get update; \
    apt-get install -y \
      apt-transport-https gnupg2 zlib1g-dev libmcrypt-dev libpq-dev \
      libfreetype6-dev libjpeg62-turbo-dev libpng-dev git libzip-dev unzip \
      icu-devtools libicu-dev ca-certificates curl gnupg libgssapi-krb5-2; \
    docker-php-ext-install -j"$(nproc)" pcntl; \
    docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/; \
    docker-php-ext-install -j"$(nproc)" gd zip intl; \
    docker-php-ext-configure ftp --with-openssl-dir=/usr; \
    docker-php-ext-install -j"$(nproc)" ftp; \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg; \
    curl -fsSL https://packages.microsoft.com/config/debian/12/prod.list -o /etc/apt/sources.list.d/mssql-release.list; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list; \
    apt-get update; \
    apt-get install -y msodbcsql18=18.3.2.1-1 mssql-tools18=18.2.1.1-1 unixodbc-dev nodejs=20.10.0-1nodesource1; \
    apt-mark hold msodbcsql18 mssql-tools18 nodejs; \
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> /root/.bash_profile; \
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> /root/.bashrc; \
    pecl install sqlsrv-5.11.1 pdo_sqlsrv-5.11.1; \
    pecl install -o -f redis-6.0.2; \
    docker-php-ext-enable sqlsrv pdo_sqlsrv redis; \
    rm -rf /tmp/pear /var/lib/apt/lists/*; \
    # 최신 공식 이미지는 opcache 를 기본 활성화한다. 기존 base(8.2.13)는 미로드였으므로
    # 런타임 동작을 바꾸지 않도록 활성화 ini 만 지운다(확장 .so 는 남김).
    rm -f "$PHP_INI_DIR/conf.d/docker-php-ext-opcache.ini"; \
    printf 'session.upload_progress.enabled = 0\n' > "$PHP_INI_DIR/conf.d/zz-thielmann-security.ini"; \
    ln -snf /usr/share/zoneinfo/Asia/Seoul /etc/localtime; \
    echo "Asia/Seoul" > /etc/timezone; \
    php -r 'foreach (["sqlsrv","pdo_sqlsrv","redis","gd","intl","zip","pcntl","sodium","mbstring","ftp"] as $e) { if (!extension_loaded($e)) { fwrite(STDERR, "missing $e\n"); exit(1); } } if (extension_loaded("Zend OPcache")) { fwrite(STDERR, "opcache must stay off\n"); exit(1); } if (ini_get("session.upload_progress.enabled")) { fwrite(STDERR, "session.upload_progress must be off\n"); exit(1); }'; \
    test "$(php -r 'echo PHP_VERSION;')" = "8.2.36"

COPY --from=composer:2.6.5@sha256:67f1bec07666f688791bff2c13b34b9c35042cc4c1e42fbb5bd4dbe4ae70f0fb /usr/bin/composer /usr/bin/composer
