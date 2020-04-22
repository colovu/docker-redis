FROM endial/ubuntu:18.04

ENV APP_MAJOR=5.0.8 \
	APP_DOWNLOAD_SHA=f3c7eac42f433326a8d981b50dba0169fdfaf46abb23fcda2f933a7552ee4ed7

LABEL \
	"Version"="v${APP_MAJOR}" \
	"Description"="Docker image for Redis ${APP_MAJOR} based on Ubuntu 18.04." \
	"Dockerfile"="https://github.com/endial/docker-redis" \
	"Vendor"="Endial Fang (endial@126.com)"

RUN set -eux; \
	groupadd -r redis; \
	useradd -r -g redis -s /usr/sbin/nologin -d /usr/cache/redis redis; \
	\
	mkdir -p /etc/redis/default /srv/conf/redis /srv/data/redis /var/log/redis /var/run/redis; \
	\
	fetchDeps=" \
		autoconf \
		automake \
		gcc \
		g++ \
		gcc-multilib \
		make \
		ca-certificates \
		wget \
	"; \
	apt-get -y update; \
	apt-get -y install --no-install-recommends $fetchDeps; \
	\
	wget -O redis.tar.gz "http://download.redis.io/releases/redis-${APP_MAJOR}.tar.gz"; \
	echo "$APP_DOWNLOAD_SHA *redis.tar.gz" | sha256sum -c -; \
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
	cp -rf /usr/src/redis/*.conf /etc/redis/; \
	rm -r /usr/src/redis; \
	\
	ln -sf /srv/conf/redis/redis.conf /etc/redis/redis.conf; \
	ln -sf /srv/conf/redis/sentinel.conf /etc/redis/sentinel.conf; \
	chown -Rf redis:redis /etc/redis /srv/conf/redis /srv/data/redis /var/log/redis /var/run/redis; \
# this 777 will be replaced by 700 or 755 at runtime (allows semi-arbitrary "--user" values)
	chmod 777 /etc/redis /srv/conf/redis /srv/data/redis /var/log/redis /var/run/redis; \
	\
	apt purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false ${fetchDeps}; \
	apt autoclean -y; \
	rm -rf /var/lib/apt/lists/*; \
	\
	redis-cli --version; \
	redis-server --version


COPY ./entrypoint.sh /usr/local/bin/
COPY ./redis /etc/redis

VOLUME [ "/srv/data", "/srv/conf", "/var/log", "/var/run" ]

WORKDIR /srv/data/redis

# 如果使用gosu启动，必须保证端口在1024之上
EXPOSE 6379

ENTRYPOINT ["entrypoint.sh"]

CMD ["redis-server", "/srv/conf/redis/redis.conf"]
