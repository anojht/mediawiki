FROM php:7.0-apache
MAINTAINER Anojh Thayaparan <athayapa@sfu.ca>

ENV MEDIAWIKI_VERSION 1.31
ENV MEDIAWIKI_FULL_VERSION 1.31.0

RUN set -x; \
	apt-get update \
	&& apt-get install -y --no-install-recommends \
		wget \
		gnupg2 \
	&& echo "deb http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list \
	&& echo "deb-src http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list \
	&& cd /tmp \
	&& curl -sL https://deb.nodesource.com/setup_8.x -o nodesource_setup.sh \
	&& chmod +x nodesource_setup.sh \
	&& wget "https://www.dotdeb.org/dotdeb.gpg" \
	&& apt-key add dotdeb.gpg \
	&& rm dotdeb.gpg \
	&& ./nodesource_setup.sh \
	&& apt-get install -y nodejs build-essential \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		g++ \
		git \
		zlib1g-dev \
		libmcrypt-dev \
		libltdl-dev \
		libicu-dev \
		libcurl4-openssl-dev \
		libapache2-mod-rpaf \
		sysvinit-utils \
		python \
		dirmngr \
	&& apt-key advanced --keyserver pgp.mit.edu --recv-keys 90E9F83F22250DD7 \
        && echo "deb https://releases.wikimedia.org/debian jessie-mediawiki main" | tee /etc/apt/sources.list.d/parsoid.list \
        && apt-get install -y --no-install-recommends apt-transport-https \
        && apt-get update \
        && apt-get install -y --no-install-recommends parsoid \
	&& rm -rf /var/lib/apt/lists/*

# RUN docker-php-ext-configure intl \
RUN docker-php-ext-install zlib; exit 0

RUN cp /usr/src/php/ext/zlib/config0.m4 /usr/src/php/ext/zlib/config.m4

RUN docker-php-ext-configure mcrypt

RUN docker-php-ext-install mbstring mysqli opcache intl zlib mcrypt sockets \
&& docker-php-ext-enable mysqli opcache zlib mbstring intl mcrypt sockets

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
	&& apt-get purge -y --auto-remove g++ libicu-dev libcurl4-openssl-dev zlib1g-dev \
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
