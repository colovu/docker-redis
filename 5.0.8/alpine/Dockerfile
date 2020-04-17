FROM endial/alpine:v3.11

LABEL \
	"Version"="v5.0.8" \
	"Description"="Docker image for Redis 5.0.8 based on Alpine 3.11." \
	"Dockerfile"="https://github.com/endial/docker-libs" \
	"Vendor"="Endial Fang (endial@126.com)"

ENV REDIS_VERSION 5.0.8
ENV REDIS_DOWNLOAD_URL http://download.redis.io/releases/redis-5.0.8.tar.gz
ENV REDIS_DOWNLOAD_SHA f3c7eac42f433326a8d981b50dba0169fdfaf46abb23fcda2f933a7552ee4ed7

RUN addgroup -S -g 1000 redis; \
	adduser -S -G redis -u 1000 redis; \
	\
	apk add --no-cache \
		'su-exec>=0.2' \
		tzdata \
	; \
	\
	set -eux; \
	\
	apk add --no-cache --virtual .build-deps \
		coreutils \
		gcc \
		linux-headers \
		make \
		musl-dev \
		openssl-dev \
	; \
	\
	wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL"; \
	echo "$REDIS_DOWNLOAD_SHA *redis.tar.gz" | sha256sum -c -; \
	mkdir -p /usr/src/redis; \
	tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1; \
	rm redis.tar.gz; \
	\
# disable Redis protected mode [1] as it is unnecessary in context of Docker
# (ports are not automatically exposed when running inside Docker, but rather explicitly by specifying -p / -P)
# [1]: https://github.com/antirez/redis/commit/edd4d555df57dc84265fdfb4ef59a4678832f6da
	grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 1$' /usr/src/redis/src/server.h; \
	sed -ri 's!^(#define CONFIG_DEFAULT_PROTECTED_MODE) 1$!\1 0!' /usr/src/redis/src/server.h; \
	grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 0$' /usr/src/redis/src/server.h; \
# for future reference, we modify this directly in the source instead of just supplying a default configuration flag because apparently "if you specify any argument to redis-server, [it assumes] you are going to specify everything"
# see also https://github.com/docker-library/redis/issues/4#issuecomment-50780840
# (more exactly, this makes sure the default behavior of "save on SIGTERM" stays functional by default)
	\
	make -C /usr/src/redis -j "$(nproc)" all; \
	make -C /usr/src/redis install; \
	\
# TODO https://github.com/antirez/redis/pull/3494 (deduplicate "redis-server" copies)
	serverMd5="$(md5sum /usr/local/bin/redis-server | cut -d' ' -f1)"; export serverMd5; \
	find /usr/local/bin/redis* -maxdepth 0 \
		-type f -not -name redis-server \
		-exec sh -eux -c ' \
			md5="$(md5sum "$1" | cut -d" " -f1)"; \
			test "$md5" = "$serverMd5"; \
		' -- '{}' ';' \
		-exec ln -svfT 'redis-server' '{}' ';' \
	; \
	\
	mkdir -p /etc/redis/default; \
	chown redis:root /etc/redis/default; \
	mkdir -p /srv/data/redis; \
	chown redis:root /srv/data/redis; \
	mkdir -p /srv/conf/redis; \
	chown redis:root /srv/conf/redis; \
	\
#	cp -rf /usr/src/redis/*.conf /etc/redis/; \
	ln -sf /srv/conf/redis/redis.conf /etc/redis/redis.conf; \
	ln -sf /srv/conf/redis/sentinel.conf /etc/redis/sentinel.conf; \
	ln -sf /etc/redis/entrypoint.sh /usr/local/bin/entrypoint.sh; \
	rm -r /usr/src/redis; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-network --virtual .redis-rundeps $runDeps; \
	apk del --no-network .build-deps; \
	\
	redis-cli --version; \
	redis-server --version

VOLUME [ "/srv/data", "/srv/conf", "/var/log", "/var/run" ]
EXPOSE 6379

COPY ./redis /etc/redis
WORKDIR /srv/data/redis

ENTRYPOINT ["entrypoint.sh"]

CMD ["redis-server", "/etc/redis/redis.conf"]
