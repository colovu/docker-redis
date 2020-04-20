#!/bin/bash
# Alpine 系统只能使用 /bin/sh
# 
# docker entrypoint script

# 以下变量已在 Dockerfile 中定义，不需要修改
# APP_NAME: 应用名称，如 redis
# APP_EXEC: 应用可执行二进制文件，如 redis-server
# APP_USER: 应用对应的用户名，如 redis
# APP_GROUP: 应用对应的用户组名，如 redis

# Alpine系统因使用/bin/sh，仅支持 set -e
set -Eeo pipefail

LOG_RAW() {
	local type="$1"; shift
	printf '%s [%s] Entrypoint: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$type" "$*"
}
LOG_I() {
	LOG_RAW Note "$@"
}
LOG_W() {
	LOG_RAW Warn "$@" >&2
}
LOG_E() {
	LOG_RAW Error "$@" >&2
	exit 1
}

LOG_I "Initial container for ${APP_NAME}"

# 检测当前脚本是被直接执行的，还是从其他脚本中使用 "source" 调用的
_is_sourced() {
	[ "${#FUNCNAME[@]}" -ge 2 ] \
		&& [ "${FUNCNAME[0]}" = '_is_sourced' ] \
		&& [ "${FUNCNAME[1]}" = 'source' ]
}

# 使用root用户运行时，创建默认的数据目录，并拷贝所必须的默认配置文件及初始化文件
# 修改对应目录所属用户为应用对应的用户(Docker镜像创建时，相应目录默认为777模式)
docker_create_user_directories() {
	local user_id; user_id="$(id -u)"
#/etc/${APP_NAME}/default /srv/conf/${APP_NAME} /srv/data/${APP_NAME} 
	LOG_I "Check directories used by ${APP_NAME}"
	mkdir -p "/var/log/${APP_NAME}"
	mkdir -p "/var/run/${APP_NAME}"
	mkdir -p "/srv/data/${APP_NAME}"

	mkdir -p "/srv/conf/${APP_NAME}"
	# 检测指定文件是否存在，如果不存在则拷贝
	[ ! -e /srv/conf/${APP_NAME}/redis.conf ] && cp /etc/redis/default/redis.conf /srv/conf/${APP_NAME}/redis.conf
	[ ! -e /srv/conf/${APP_NAME}/sentinel.conf ] && cp /etc/redis/default/sentinel.conf /srv/conf/${APP_NAME}/sentinel.conf

	# 允许容器使用`--user`参数启动，修改相应目录的所属用户信息
	# 如果设置了'--user'，这里 user_id 不为 0
	# 如果没有设置'--user'，这里 user_id 为 0，需要使用默认用户名设置相关目录权限
	if [ "$user_id" = '0' ]; then
		find /var/run/${APP_NAME} \! -user ${APP_USER} -exec chown ${APP_USER} '{}' +
		find /var/log/${APP_NAME} \! -user ${APP_USER} -exec chown ${APP_USER} '{}' +
		find /srv/data/${APP_NAME} \! -user ${APP_USER} -exec chown ${APP_USER} '{}' +
		find /srv/conf/${APP_NAME} \! -user ${APP_USER} -exec chown ${APP_USER} '{}' +
		chmod 0755 /etc/${APP_NAME} /var/log/${APP_NAME} /var/run/${APP_NAME} /srv/conf/${APP_NAME} /srv/data/${APP_NAME}
		# 解决使用gosu后，nginx: [emerg] open() "/dev/stdout" failed (13: Permission denied)
		chmod 0622 /dev/stdout /dev/stderr
	fi
}

# 检测可能导致容器执行后直接退出的命令，如"--help"；如果存在，直接返回 0
docker_app_want_help() {
	local arg
	for arg; do
		case "$arg" in
			-'?'|--help|-V|--version)
				return 0
				;;
		esac
	done
	return 1
}

_main() {
	# 如果命令行参数是以配置参数("-")开始，修改执行命令，确保使用可执行应用命令启动服务器
	if [ "${1:0:1}" = '-' ]; then
		set -- ${APP_EXEC} "$@"
	fi

	# 命令行参数以可执行应用命令起始，且不包含直接返回的命令(如：-V、--version、--help)时，执行初始化操作
	if [ "$1" = "${APP_EXEC}" ] && ! docker_app_want_help "$@"; then
		# 以root用户运行时，设置数据存储目录与权限；设置完成后，会使用gosu重新以"${APP_USER}"用户运行当前脚本
		docker_create_user_directories
		if [ "$(id -u)" = '0' ]; then
			LOG_I "Restart container with default user: ${APP_USER}'"
			LOG_I ""
			exec gosu ${APP_USER} "$0" "$@"
		fi
	fi

	LOG_I "Start container with: $@"
	# 执行命令行
	exec "$@"
}

if ! _is_sourced; then
	_main "$@"
fi
