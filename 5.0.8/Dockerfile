FROM endial/ubuntu:v18.04

LABEL \
	"Version"="v5.0.8" \
	"Description"="Docker image for Redis 5.0.8 based on Ubuntu 18.04." \
	"Dockerfile"="https://github.com/endial/docker-libs" \
	"Vendor"="Endial Fang (endial@126.com)"

ENV REDIS_VERSION 5.0.8
ENV REDIS_DOWNLOAD_URL http://download.redis.io/releases/redis-5.0.8.tar.gz
ENV REDIS_DOWNLOAD_SHA f3c7eac42f433326a8d981b50dba0169fdfaf46abb23fcda2f933a7552ee4ed7

RUN set -eux; \
# add group and user, first account, use 1000
	groupadd -g 1000 redis; \
	useradd -M -g redis -s /usr/sbin/nologin -u 1000 redis; \
	\
	fetchDeps=' \
		gcc \
		gcc-multilib \
		make \
		wget \
	'; \
	apt-get -y update; \
	apt-get -y install --no-install-recommends $fetchDeps; \
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
	apt-get autoremove -y $fetchDeps; \
	rm -rf /var/lib/apt/lists/*; \
	\
	redis-cli --version; \
	redis-server --version

VOLUME [ "/srv/data", "/srv/conf", "/var/log", "/var/run" ]
EXPOSE 6379

COPY ./redis /etc/redis
WORKDIR /srv/data/redis

ENTRYPOINT ["entrypoint.sh"]

CMD ["redis-server", "/etc/redis/redis.conf"]
