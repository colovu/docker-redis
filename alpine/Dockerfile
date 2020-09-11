# Ver: 1.2 by Endial Fang (endial@126.com)
#

# 预处理 =========================================================================
FROM colovu/abuilder as builder

# sources.list 可使用版本：default / tencent / ustc / aliyun / huawei
ARG apt_source=default

# 编译镜像时指定用于加速的本地服务器地址
ARG local_url=""

WORKDIR /usr/local

RUN select_source ${apt_source};
#RUN install_pkg xz-utils

# 下载并解压软件包
RUN set -eux; \
	appVersion=1.0.0; \
	appName="wait-for-port-${appVersion}-1-linux-amd64-debian-10.tar.gz"; \
	[ ! -z ${local_url} ] && localURL=${local_url}/bitnami; \
	appUrls="${localURL:-} \
		https://downloads.bitnami.com/files/stacksmith \
		"; \
	download_pkg unpack ${appName} "${appUrls}"; \
	chmod +x /usr/local/wait-for-port-1.0.0-1-linux-amd64-debian-10/files/common/bin/wait-for-port;

RUN set -eux; \
	appVersion=6.0.5; \
	appName="redis-${appVersion}.tar.gz"; \
	sha256="42cf86a114d2a451b898fcda96acd4d01062a7dbaaad2801d9164a36f898f596"; \
	[ ! -z ${local_url} ] && localURL=${local_url}/redis; \
	appUrls="${localURL:-} \
		http://download.redis.io/releases \
		"; \
	download_pkg unpack ${appName} "${appUrls}" -s "${sha256}"; \
	mkdir -p /usr/local/redis; \
	cd /usr/local/redis-${appVersion}; \
# 禁用安全保护模式，在 Docker 中运行时不需要
	grep -E '^ *createBoolConfig[(]"protected-mode",.*, *1 *,.*[)],$' /usr/local/redis-${appVersion}/src/config.c; \
	sed -ri 's!^( *createBoolConfig[(]"protected-mode",.*, *)1( *,.*[)],)$!\10\2!' /usr/local/redis-${appVersion}/src/config.c; \
	grep -E '^ *createBoolConfig[(]"protected-mode",.*, *0 *,.*[)],$' /usr/local/redis-${appVersion}/src/config.c; \
	make MALLOC=libc BUILD_TLS=yes \
		-j "$(nproc)" all; \
	make PREFIX=/usr/local/redis install; \
	\
# 删除重复的应用程序，并生成对应的连接
	serverMd5="$(md5sum /usr/local/redis/bin/redis-server | cut -d' ' -f1)"; export serverMd5; \
	find /usr/local/redis/bin/redis* -maxdepth 0 \
		-type f -not -name redis-server \
		-exec sh -eux -c ' \
			md5="$(md5sum "$1" | cut -d" " -f1)"; \
			test "$md5" = "$serverMd5"; \
		' -- '{}' ';' \
		-exec ln -svfT 'redis-server' '{}' ';' ; 



#find /usr/local/redis/bin -type f -executable -exec ldd '{}' ';' | awk '/=>/ { print $(NF-1) }' | sort -u | xargs -r dpkg-query --search | cut -d: -f1 | sort -u

# 镜像生成 ========================================================================
FROM colovu/alpine:3.12

ARG apt_source=default
ARG local_url=""

ENV APP_NAME=redis \
	APP_USER=redis \
	APP_EXEC=redis-server \
	APP_VERSION=6.0.5

ENV	APP_HOME_DIR=/usr/local/${APP_NAME} \
	APP_DEF_DIR=/etc/${APP_NAME} \
	APP_CONF_DIR=/srv/conf/${APP_NAME} \
	APP_DATA_DIR=/srv/data/${APP_NAME} \
	APP_DATA_LOG_DIR=/srv/datalog/${APP_NAME} \
	APP_CACHE_DIR=/var/cache/${APP_NAME} \
	APP_RUN_DIR=/var/run/${APP_NAME} \
	APP_LOG_DIR=/var/log/${APP_NAME} \
	APP_CERT_DIR=/srv/cert/${APP_NAME}

ENV \
	PATH="${APP_HOME_DIR}/bin:${PATH}"

LABEL \
	"Version"="v${APP_VERSION}" \
	"Description"="Docker image for ${APP_NAME}(v${APP_VERSION})." \
	"Dockerfile"="https://github.com/colovu/docker-${APP_NAME}" \
	"Vendor"="Endial Fang (endial@126.com)"

COPY customer /

# 以包管理方式安装软件包(Optional)
#RUN select_source ${apt_source}
RUN install_pkg openssl

RUN create_user && prepare_env

# 从预处理过程中拷贝软件包(Optional)
COPY --from=builder /usr/local/wait-for-port-1.0.0-1-linux-amd64-debian-10/files/common/bin/ /usr/local/bin/
COPY --from=builder /usr/local/redis /usr/local/redis
COPY --from=builder /usr/local/redis-${APP_VERSION}/*.conf ${APP_DEF_DIR}/

# 执行预处理脚本，并验证安装的软件包
RUN set -eux; \
	override_file="/usr/local/overrides/overrides-${APP_VERSION}.sh"; \
	[ -e "${override_file}" ] && /bin/bash "${override_file}"; \
	gosu ${APP_USER} redis-cli --version; \
	gosu ${APP_USER} redis-server --version; \
	:;

# 默认提供的数据卷
VOLUME ["/srv/conf", "/srv/data", "/srv/datalog", "/srv/cert", "/var/log"]

# 默认使用gosu切换为新建用户启动，必须保证端口在1024之上
EXPOSE 6379

# 容器初始化命令，默认存放在：/usr/local/bin/entry.sh
ENTRYPOINT ["entry.sh"]

# 应用程序的服务命令，必须使用非守护进程方式运行。如果使用变量，则该变量必须在运行环境中存在（ENV可以获取）
CMD ["${APP_EXEC}", "${REDIS_CONF_FILE}"]

