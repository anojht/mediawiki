FROM php:7.0-apache
MAINTAINER Anojh Thayaparan <athayapa@sfu.ca>

ENV MEDIAWIKI_VERSION 1.29
ENV MEDIAWIKI_FULL_VERSION 1.29.1

RUN set -x; \
	apt-get update \
	&& apt-get install -y --no-install-recommends \
		wget \
	&& echo "deb http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list \
	&& echo "deb-src http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list \
	&& cd /tmp \
	&& curl -sL https://deb.nodesource.com/setup_8.x -o nodesource_setup.sh \
	&& chmod +x nodesource_setup.sh \
	&& ./nodesource_setup.sh \
	&& apt-get install nodejs build-essential \
	&& wget "https://www.dotdeb.org/dotdeb.gpg" \
	&& apt-key add dotdeb.gpg \
	&& rm dotdeb.gpg \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		g++ \
		libicu-dev \
		libapache2-mod-rpaf \
		sysvinit-utils \
		libssl-dev \
		libcurl4-openssl-dev \
		pkg-config \
	&& apt-key advanced --keyserver keys.gnupg.net --recv-keys 90E9F83F22250DD7 \
        && echo "deb https://releases.wikimedia.org/debian jessie-mediawiki main" | tee /etc/apt/sources.list.d/parsoid.list \
        && apt-get install -y --no-install-recommends apt-transport-https \
        && apt-get update \
        && apt-get install -y --no-install-recommends parsoid \
	&& apt-get purge -y --auto-remove g++ libicu-dev \
	&& rm -rf /var/lib/apt/lists/*

# RUN docker-php-ext-configure intl \
RUN docker-php-ext-install mysqli opcache zlib mbstring intl mcrypt
# && echo extension=intl.so >> /usr/local/etc/php/conf.d/ext-intl.ini \
# && docker-php-ext-enable mysqli opcache curl json zlib mbstring intl mcrypt

RUN pecl channel-update pecl.php.net \
	&& pecl install apcu-5.1.8 \
	&& docker-php-ext-enable apcu

RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN set -x; \
	apt-get update \
	&& apt-get install -y --no-install-recommends imagemagick \
	&& rm -rf /var/lib/apt/lists/*

RUN a2enmod rewrite

# Mediawiki server keys for fetching and install mediawiki package
RUN gpg --keyserver pool.sks-keyservers.net --recv-keys \
    441276E9CCD15F44F6D97D18C119E1A64D70938E \
    41B2ABE817ADD3E52BDA946F72BC1C5D23107F8A \
    162432D9E81C1C618B301EECEE1F663462D84F01 \
    1D98867E82982C8FE0ABC25F9B69B3109D3BB7B0 \
    3CEF8262806D3F0B6BA1DBDD7956EE477F901A30 \
    280DB7845A1DCAC92BB5A00A946B02565DC00AA7

RUN MEDIAWIKI_DOWNLOAD_URL="https://releases.wikimedia.org/mediawiki/$MEDIAWIKI_VERSION/mediawiki-$MEDIAWIKI_FULL_VERSION.tar.gz"; \
	set -x; \
	mkdir -p /usr/src/mediawiki \
	&& curl -fSL "$MEDIAWIKI_DOWNLOAD_URL" -o mediawiki.tar.gz \
	&& curl -fSL "${MEDIAWIKI_DOWNLOAD_URL}.sig" -o mediawiki.tar.gz.sig \
	&& gpg --verify mediawiki.tar.gz.sig \
	&& tar -xf mediawiki.tar.gz -C /usr/src/mediawiki --strip-components=1

COPY apache/mediawiki.conf /etc/apache2/
RUN echo Include /etc/apache2/mediawiki.conf >> /etc/apache2/apache2.conf

COPY docker-entrypoint.sh /entrypoint.sh
RUN set -x; \
	chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
