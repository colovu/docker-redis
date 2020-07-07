FROM colovu/ubuntu:18.04

ARG app_ver=5.0.8
ARG LOCAL_SERVER=http://172.29.14.108/dist-files/

ENV APP_NAME=redis \
	APP_EXEC=redis-server \
	APP_USER=redis \
	APP_GROUP=redis \
	APP_VERSION=${app_ver}

ENV	APP_BASE_DIR=/usr/local/${APP_NAME} \
	APP_DEF_DIR=/etc/${APP_NAME} \
	APP_CONF_DIR=/srv/conf/${APP_NAME} \
	APP_DATA_DIR=/srv/data/${APP_NAME} \
	APP_DATA_LOG_DIR=/srv/datalog/${APP_NAME} \
	APP_CACHE_DIR=/var/cache/${APP_NAME} \
	APP_RUN_DIR=/var/run/${APP_NAME} \
	APP_LOG_DIR=/var/log/${APP_NAME} \
	APP_CERT_DIR=/srv/cert/${APP_NAME} \
	APP_WWW_DIR=/srv/www

# 设置应用需要的环境变量
ENV PATH="${APP_BASE_DIR}/bin:${PATH}"

LABEL \
	"Version"="v${APP_VERSION}" \
	"Description"="Docker image for ${APP_NAME} ${APP_VERSION}." \
	"Dockerfile"="https://github.com/colovu/docker-${APP_NAME}" \
	"Vendor"="Endial Fang (endial@126.com)"

COPY prebuilds /

RUN set -eux; \
# 设置程序使用静默安装，而非交互模式；类似tzdata等程序需要使用静默安装
	export DEBIAN_FRONTEND=noninteractive; \
	\
# 设置入口脚本的可执行权限
	chmod +x /usr/local/bin/entrypoint.sh; \
	\
# 为应用创建对应的组、用户、相关目录
	APP_DIRS="${APP_DEF_DIR:-} ${APP_CONF_DIR:-} ${APP_DATA_DIR:-} ${APP_CACHE_DIR:-} ${APP_RUN_DIR:-} ${APP_LOG_DIR:-} ${APP_CERT_DIR:-} ${APP_WWW_DIR:-} ${APP_DATA_LOG_DIR:-}"; \
	groupadd -r ${APP_GROUP}; \
	useradd -r -g ${APP_GROUP} -s /usr/sbin/nologin ${APP_USER}; \
	mkdir -p ${APP_DIRS}; \
	\
# 应用软件包及依赖
	appDeps=" \
		"; \
	\
	fetchDeps=" \
		wget \
		ca-certificates \
		\
		autoconf \
		automake \
		gcc \
		g++ \
		gcc-multilib \
		make \
		\
	"; \
	savedAptMark="$(apt-mark showmanual) ${appDeps}"; \
	apt-get -y update; \
	apt-get -y install --no-install-recommends $fetchDeps; \
	\
	# 使用下载(编译)方式安装软件
	DIST_NAME="wait-for-port-1.0.0-1-linux-amd64-debian-10"; \
	DIST_URL=" \
		${LOCAL_SERVER} \
		https://downloads.bitnami.com/files/stacksmith/ \
		"; \
	. /usr/local/scripts/libdownload.sh && download_dist "${DIST_NAME}.tar.gz" "${DIST_URL}"; \
	\
# 二进制解压
	APP_BIN="/usr/local/bin"; \
	tar --extract --gunzip --file "${DIST_NAME}.tar.gz" --directory "${APP_BIN}" --strip-components 4 "${DIST_NAME}/files/common/bin/"; \
	rm -rf "${DIST_NAME}.tar.gz" "/usr/local/bin/.buildcomplete"; \
	\
# 使用下载(编译)方式安装软件
	DIST_NAME="${APP_NAME}-${APP_VERSION}.tar.gz"; \
	DIST_SHA256="f3c7eac42f433326a8d981b50dba0169fdfaf46abb23fcda2f933a7552ee4ed7"; \
	DIST_URL=" \
		${LOCAL_SERVER} \
		http://download.redis.io/releases/ \
		"; \
	. /usr/local/scripts/libdownload.sh && download_dist "${DIST_NAME}" "${DIST_URL}" --checksum "${DIST_SHA256}"; \
	\
# 源码编译
	APP_SRC="/usr/local/src/${APP_NAME}-${APP_VERSION}"; \
	mkdir -p ${APP_SRC}; \
	tar --extract --file "${DIST_NAME}" --directory "${APP_SRC}" --strip-components 1; \
	cd ${APP_SRC}; \
# disable Redis protected mode [1] as it is unnecessary in context of Docker
# (ports are not automatically exposed when running inside Docker, but rather explicitly by specifying -p / -P)
# [1]: https://github.com/antirez/redis/commit/edd4d555df57dc84265fdfb4ef59a4678832f6da
	grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 1$' ${APP_SRC}/src/server.h; \
	sed -ri 's!^(#define CONFIG_DEFAULT_PROTECTED_MODE) 1$!\1 0!' ${APP_SRC}/src/server.h; \
	grep -q '^#define CONFIG_DEFAULT_PROTECTED_MODE 0$' ${APP_SRC}/src/server.h; \
# for future reference, we modify this directly in the source instead of just supplying a default configuration flag because apparently "if you specify any argument to redis-server, [it assumes] you are going to specify everything"
# see also https://github.com/docker-library/redis/issues/4#issuecomment-50780840
# (more exactly, this makes sure the default behavior of "save on SIGTERM" stays functional by default)
	\
	make -j "$(nproc)" all; \
	make install; \
	cp -rf ./*.conf ${APP_DEF_DIR}/; \
	cd /; \
	rm -rf ${APP_SRC} ${DIST_NAME}; \
	\
# 检测是否存在overrides脚本文件，如果存在，执行
	{ [ ! -e "/usr/local/overrides/overrides-${APP_VERSION}.sh" ] || /bin/bash "/usr/local/overrides/overrides-${APP_VERSION}.sh"; }; \
	\
# 设置临时目录的权限信息，设置为777是为了保证后续使用`--user`或`gosu`时，可以更改目录对应的用户属性信息；运行时会被更改为700或755
	chown -Rf ${APP_USER}:${APP_GROUP} ${APP_DIRS}; \
	chmod 777 ${APP_DIRS}; \
	\
# 查找新安装的应用及应用依赖软件包，并标识为'manual'，防止后续自动清理时被删除
	apt-mark auto '.*' > /dev/null; \
	{ [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; }; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual; \
	\
# 删除安装的临时依赖软件包，清理缓存
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false ${fetchDeps}; \
	apt-get autoclean -y; \
	rm -rf /var/lib/apt/lists/*; \
	\
# 验证安装的软件是否可以正常运行，常规情况下放置在命令行的最后
	redis-cli --version; \
	redis-server --version

VOLUME [ "/srv/data", "/srv/conf", "/var/log", "/var/run" ]

WORKDIR /srv/data/redis

# 默认使用gosu切换为新建用户启动，必须保证端口在1024之上
EXPOSE 6379

# 容器初始化命令，默认存放在：/usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# 应用程序的服务命令，必须使用非守护进程方式运行
CMD ["redis-server", "/srv/conf/redis/redis.conf"]
