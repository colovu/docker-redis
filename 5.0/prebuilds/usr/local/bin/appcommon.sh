#!/bin/bash
#
# 应用通用业务处理函数

# 加载依赖脚本
. /usr/local/scripts/liblog.sh
. /usr/local/scripts/libfile.sh
. /usr/local/scripts/libfs.sh
. /usr/local/scripts/libos.sh
. /usr/local/scripts/libcommon.sh
. /usr/local/scripts/libvalidations.sh

# 函数列表

# 加载应用使用的环境变量初始值，该函数在相关脚本中以eval方式调用
# 全局变量:
#   ENV_* : 容器使用的全局变量
#   REDIS_* : 应用配置文件使用的全局变量，变量名根据配置项定义
# 返回值:
#   可以被 'eval' 使用的序列化输出
docker_app_env() {
    # 以下变量已经在创建镜像时定义，可直接使用
    # APP_NAME、APP_EXEC、APP_USER、APP_GROUP、APP_VERSION
    # APP_BASE_DIR、APP_DEF_DIR、APP_CONF_DIR、APP_CERT_DIR、APP_DATA_DIR、APP_DATA_LOG_DIR、APP_CACHE_DIR、APP_RUN_DIR、APP_LOG_DIR
    cat <<"EOF"
# Debug log message
export ENV_DEBUG=${ENV_DEBUG:-false}

# Paths
export REDIS_BASE_DIR="${REDIS_BASE_DIR:-${APP_BASE_DIR}}"
export REDIS_DATA_DIR="${REDIS_DATA_DIR:-${APP_DATA_DIR}}"
export REDIS_DATALOG_DIR="${REDIS_DATALOG_DIR:-${APP_DATA_LOG_DIR}}"
export REDIS_CONF_DIR="${REDIS_CONF_DIR:-${APP_CONF_DIR}}"
export REDIS_LOG_DIR="${REDIS_LOG_DIR:-${APP_LOG_DIR}}"
export REDIS_BIN_DIR="${REDIS_BIN_DIR:-${REDIS_BASE_DIR}/bin}"
export REDIS_CONF_FILE="${REDIS_CONF_DIR}/redis.conf"

# Users
export REDIS_DAEMON_USER="${REDIS_DAEMON_USER:-${APP_USER}}"
export REDIS_DAEMON_GROUP="${REDIS_DAEMON_GROUP:-${APP_GROUP}}"

# Redis settings
export REDIS_PORT="${REDIS_PORT:-6379}"
export REDIS_DISABLE_COMMANDS="${REDIS_DISABLE_COMMANDS:-}"
export REDIS_AOF_ENABLED="${REDIS_AOF_ENABLED:-yes}"

# Cluster configuration
export REDIS_SENTINEL_HOST="${REDIS_SENTINEL_HOST:-}"
export REDIS_SENTINEL_MASTER_NAME="${REDIS_SENTINEL_MASTER_NAME:-}"
export REDIS_SENTINEL_PORT_NUMBER="${REDIS_SENTINEL_PORT_NUMBER:-26379}"

export REDIS_MASTER_HOST="${REDIS_MASTER_HOST:-}"
export REDIS_MASTER_PORT_NUMBER="${REDIS_MASTER_PORT_NUMBER:-6379}"
export REDIS_MASTER_PASSWORD="${REDIS_MASTER_PASSWORD:-}"
export REDIS_REPLICATION_MODE="${REDIS_REPLICATION_MODE:-}"

# Redis TLS Settings
export REDIS_TLS_ENABLED="${REDIS_TLS_ENABLED:-no}"
export REDIS_TLS_PORT="${REDIS_TLS_PORT:-6379}"
export REDIS_TLS_CERT_FILE="${REDIS_TLS_CERT_FILE:-}"
export REDIS_TLS_KEY_FILE="${REDIS_TLS_KEY_FILE:-}"
export REDIS_TLS_CA_FILE="${REDIS_TLS_CA_FILE:-}"
export REDIS_TLS_DH_PARAMS_FILE="${REDIS_TLS_DH_PARAMS_FILE:-}"
export REDIS_TLS_AUTH_CLIENTS="${REDIS_TLS_AUTH_CLIENTS:-yes}"

# Authentication
export REDIS_ALLOW_EMPTY_PASSWORD="${REDIS_ALLOW_EMPTY_PASSWORD:-no}"
export REDIS_PASSWORD="${REDIS_PASSWORD:-}"
EOF

    if [[ -f "${REDIS_PASSWORD_FILE:-}" ]]; then
        cat <<"EOF"
export REDIS_PASSWORD="$(< "${REDIS_PASSWORD_FILE}")"
EOF
    fi
    if [[ -f "${REDIS_MASTER_PASSWORD_FILE:-}" ]]; then
        cat <<"EOF"
export REDIS_MASTER_PASSWORD="$(< "${REDIS_MASTER_PASSWORD_FILE}")"
EOF
    fi
}

# 将变量配置更新至配置文件
# 参数:
#   $1 - 文件
#   $2 - 变量
#   $3 - 值（列表）
redis_common_conf_set() {
    local file="${1:?missing file}"
    local key="${2:?missing key}"
    shift
    shift
    local values=("$@")

    if [[ "${#values[@]}" -eq 0 ]]; then
        LOG_E "missing value"
        return 1
    elif [[ "${#values[@]}" -ne 1 ]]; then
        for i in "${!values[@]}"; do
            redis_common_conf_set "$file" "${key[$i]}" "${values[$i]}"
        done
    else
        value="${values[0]}"
        # Sanitize inputs
        value="${value//\\/\\\\}"
        value="${value//&/\\&}"
        value="${value//\?/\\?}"
        [[ "$value" = "" ]] && value="\"$value\""
        # Check if the value was set before
        if grep -q "^${key} .*" "$file"; then
            # Update the existing key
            replace_in_file "$file" "^${key} .*" "${key} ${value}" false
        else
            # Add a new key
            printf '\n%s %s' "$key" "$value" >>"$file"
        fi
    fi
}

# 获取配置文件中指定关键字对应的值
# 全局变量:
#   APP_CONF_DIR
# 变量:
#   $1 - 变量
redis_conf_get() {
    local key="${1:?missing key}"

    grep -E "^\s*$key " "${REDIS_CONF_DIR}/redis.conf" | awk '{print $2}'
}

# 更新 redis.conf 配置文件中指定变量值，设置关键字及对应值
# 全局变量:
#   APP_CONF_DIR
# 变量:
#   $1 - 变量
#   $2 - 值（列表）
redis_conf_set() {
    redis_common_conf_set "${REDIS_CONF_DIR}/redis.conf" "$@"
}

# 更新 sentinel.conf 配置文件中指定变量值，设置关键字及对应值
# 全局变量:
#   APP_CONF_DIR
# 变量:
#   $1 - 变量
#   $2 - 值（列表）
redis_sentinel_conf_set() {
    redis_common_conf_set "${REDIS_CONF_DIR}/sentinel.conf" "$@"
}

# 更新 redis.conf 配置文件中指定变量值，取消关键字设置信息
# 全局变量:
#   APP_CONF_DIR
# 变量:
#   $1 - 变量
redis_conf_unset() {
    local key="${1:?missing key}"
    remove_in_file "${REDIS_CONF_DIR}/redis.conf" "^\s*$key .*" false
}

# 获取 Redis 版本信息
# 返回值:
#   Redis 版本号
redis_version() {
    redis-cli --version | grep -E -o "[0-9]+.[0-9]+.[0-9]+"
}

# 获取 Redis 主版本号
# 返回值:
#   Redis 主版本号
redis_major_version() {
    redis_version | grep -E -o "^[0-9]+"
}

# 检测用户参数信息是否满足条件；针对部分权限过于开放情况，打印提示信息
# 全局变量：
#   REDIS_*
app_verify_minimum_env() {
    local error_code=0
    LOG_D "Validating settings in REDIS_* env vars..."

    # Auxiliary functions
    print_validation_error() {
        LOG_E "$1"
        error_code=1
    }

    # Redis authentication validations
    if is_boolean_yes "$REDIS_ALLOW_EMPTY_PASSWORD"; then
        LOG_W "You set the environment variable REDIS_ALLOW_EMPTY_PASSWORD=${REDIS_ALLOW_EMPTY_PASSWORD}. For safety reasons, do not use this flag in a production environment."
    elif [[ -z "$REDIS_PASSWORD" ]]; then
        print_validation_error "The REDIS_PASSWORD environment variable is empty or not set. Set the environment variable REDIS_ALLOW_EMPTY_PASSWORD=yes to allow the container to be started with blank passwords. This is recommended only for development."
    fi

    if [[ -n "$REDIS_REPLICATION_MODE" ]]; then
        if [[ "$REDIS_REPLICATION_MODE" =~ ^(slave|replica)$ ]]; then
            if [[ -n "$REDIS_MASTER_PORT_NUMBER" ]]; then
                if ! err=$(validate_port "$REDIS_MASTER_PORT_NUMBER"); then
                    print_validation_error "An invalid port was specified in the environment variable REDIS_MASTER_PORT_NUMBER: $err"
                fi
            fi
            if ! is_boolean_yes "$REDIS_ALLOW_EMPTY_PASSWORD" && [[ -z "$REDIS_MASTER_PASSWORD" ]]; then
                print_validation_error "The REDIS_MASTER_PASSWORD environment variable is empty or not set. Set the environment variable REDIS_ALLOW_EMPTY_PASSWORD=yes to allow the container to be started with blank passwords. This is recommended only for development."
            fi
        elif [[ "$REDIS_REPLICATION_MODE" != "master" ]]; then
            print_validation_error "Invalid replication mode. Available options are 'master/replica'"
        fi
    fi

    if is_boolean_yes "$REDIS_TLS_ENABLED"; then
        if [[ "$REDIS_PORT" == "$REDIS_TLS_PORT" ]] && [[ "$REDIS_PORT" != "6379" ]]; then
            # If both ports are assigned the same numbers and they are different to the default settings
            print_validation_error "Enviroment variables REDIS_PORT and REDIS_TLS_PORT point to the same port number (${REDIS_PORT}). Change one of them or disable non-TLS traffic by setting REDIS_PORT=0"
        fi
        if [[ -z "$REDIS_TLS_CERT_FILE" ]]; then
            print_validation_error "You must provide a X.509 certificate in order to use TLS"
        elif [[ ! -f "$REDIS_TLS_CERT_FILE" ]]; then
            print_validation_error "The X.509 certificate file in the specified path ${REDIS_TLS_CERT_FILE} does not exist"
        fi
        if [[ -z "$REDIS_TLS_KEY_FILE" ]]; then
            print_validation_error "You must provide a private key in order to use TLS"
        elif [[ ! -f "$REDIS_TLS_KEY_FILE" ]]; then
            print_validation_error "The private key file in the specified path ${REDIS_TLS_KEY_FILE} does not exist"
        fi
        if [[ -z "$REDIS_TLS_CA_FILE" ]]; then
            print_validation_error "You must provide a CA X.509 certificate in order to use TLS"
        elif [[ ! -f "$REDIS_TLS_CA_FILE" ]]; then
            print_validation_error "The CA X.509 certificate file in the specified path ${REDIS_TLS_CA_FILE} does not exist"
        fi
        if [[ -n "$REDIS_TLS_DH_PARAMS_FILE" ]] && [[ ! -f "$REDIS_TLS_DH_PARAMS_FILE" ]]; then
            print_validation_error "The DH param file in the specified path ${REDIS_TLS_DH_PARAMS_FILE} does not exist"
        fi
    fi

    [[ "$error_code" -eq 0 ]] || exit "$error_code"
}

# 加载在后续脚本命令中使用的参数信息，包括从"*_FILE"文件中导入的配置
# 必须在其他函数使用前调用
docker_setup_env() {
	# 尝试从文件获取环境变量的值
	# file_env 'ENV_VAR_NAME'

	# 尝试从文件获取环境变量的值，如果不存在，使用默认值 default_val 
	# file_env 'ENV_VAR_NAME' 'default_val'

	# 检测变量 ENV_VAR_NAME 未定义或值为空，赋值为默认值：default_val
	# : "${ENV_VAR_NAME:=default_val}"
    : 
}

# 禁用 Redis 不安全的命令
# Globals:
#   REDIS_BASEDIR
# 参数:
#   $1 - 待禁用的命令列表
redis_disable_unsafe_commands() {
    # The current syntax gets a comma separated list of commands, we split them
    # before passing to redis_disable_unsafe_commands
    read -r -a disabledCommands <<< "$(tr ',' ' ' <<< "$REDIS_DISABLE_COMMANDS")"
    LOG_D "Disabling commands: ${disabledCommands[*]}"
    for cmd in "${disabledCommands[@]}"; do
        if grep -E -q "^\s*rename-command\s+$cmd\s+\"\"\s*$" "${REDIS_CONF_FILE}"; then
            LOG_D "$cmd was already disabled"
            continue
        fi
        echo "rename-command $cmd \"\"" >> "${REDIS_CONF_FILE}"
    done
}

# 生成默认配置文件
# 全局变量:
#   REDIS_*
redis_generate_conf() {
    redis_conf_set port "$REDIS_PORT"
    redis_conf_set dir "${REDIS_DATA_DIR}"
    redis_conf_set logfile "${REDIS_LOG_DIR}/redis.log" # Log to stdout
    redis_conf_set pidfile "${APP_RUN_DIR}/redis_6379.pid"
    redis_conf_set daemonize no
    redis_conf_set bind 0.0.0.0 # Allow remote connections
    # Enable AOF https://redis.io/topics/persistence#append-only-file
    # Leave default fsync (every second)
    redis_conf_set appendonly "${REDIS_AOF_ENABLED}"
    # Disable RDB persistence, AOF persistence already enabled.
    # Ref: https://redis.io/topics/persistence#interactions-between-aof-and-rdb-persistence
    redis_conf_set save ""
    # TLS configuration
    if is_boolean_yes "$REDIS_TLS_ENABLED"; then
        if [[ "$REDIS_PORT" ==  "6379" ]] && [[ "$REDIS_TLS_PORT" ==  "6379" ]]; then
            # If both ports are set to default values, enable TLS traffic only
            redis_conf_set port 0
            redis_conf_set tls-port "$REDIS_TLS_PORT"
        else
            # Different ports were specified
            redis_conf_set port "$REDIS_PORT"
            redis_conf_set tls-port "$REDIS_TLS_PORT"
        fi
        redis_conf_set tls-cert-file "$REDIS_TLS_CERT_FILE"
        redis_conf_set tls-key-file "$REDIS_TLS_KEY_FILE"
        redis_conf_set tls-ca-cert-file "$REDIS_TLS_CA_FILE"
        [[ -n "$REDIS_TLS_DH_PARAMS_FILE" ]] && redis_conf_set tls-dh-params-file "$REDIS_TLS_DH_PARAMS_FILE"
        redis_conf_set tls-auth-clients "$REDIS_TLS_AUTH_CLIENTS"
    fi

    if [[ -n "$REDIS_PASSWORD" ]]; then
        redis_conf_set requirepass "$REDIS_PASSWORD"
    else
        redis_conf_unset requirepass
    fi
    if [[ -n "$REDIS_DISABLE_COMMANDS" ]]; then
        redis_disable_unsafe_commands
    fi
}

# 配置 Redis 复制模式参数
# 全局变量:
#   REDIS_*
# 参数:
#   $1 - 复制模式
redis_configure_replication() {
    LOG_I "Configuring replication mode..."

    redis_conf_set replica-announce-ip "$(get_machine_ip)"
    redis_conf_set replica-announce-port "$REDIS_MASTER_PORT_NUMBER"
    if [[ "$REDIS_REPLICATION_MODE" = "master" ]]; then
        if [[ -n "$REDIS_PASSWORD" ]]; then
            redis_conf_set masterauth "$REDIS_PASSWORD"
        fi
    elif [[ "$REDIS_REPLICATION_MODE" =~ ^(slave|replica)$ ]]; then
        if [[ -n "$REDIS_SENTINEL_HOST" ]]; then
            local sentinel_info_command
            if is_boolean_yes "$REDIS_TLS_ENABLED"; then
                sentinel_info_command="redis-cli -h ${REDIS_SENTINEL_HOST} -p ${REDIS_SENTINEL_PORT_NUMBER} --tls --cert ${REDIS_TLS_CERT_FILE} --key ${REDIS_TLS_KEY_FILE} --cacert ${REDIS_TLS_CA_FILE} sentinel get-master-addr-by-name ${REDIS_SENTINEL_MASTER_NAME}"
            else
                sentinel_info_command="redis-cli -h ${REDIS_SENTINEL_HOST} -p ${REDIS_SENTINEL_PORT_NUMBER} sentinel get-master-addr-by-name ${REDIS_SENTINEL_MASTER_NAME}"
            fi
            REDIS_SENTINEL_INFO=($($sentinel_info_command))
            REDIS_MASTER_HOST=${REDIS_SENTINEL_INFO[0]}
            REDIS_MASTER_PORT_NUMBER=${REDIS_SENTINEL_INFO[1]}
        fi
        LOG_I "Waitting for Redis Master ready..."
        wait-for-port --host "$REDIS_MASTER_HOST" "$REDIS_MASTER_PORT_NUMBER"
        [[ -n "$REDIS_MASTER_PASSWORD" ]] && redis_conf_set masterauth "$REDIS_MASTER_PASSWORD"
        # Starting with Redis 5, use 'replicaof' instead of 'slaveof'. Maintaining both for backward compatibility
        local parameter="replicaof"
        [[ $(redis_major_version) -lt 5 ]] && parameter="slaveof"
        redis_conf_set "$parameter" "$REDIS_MASTER_HOST $REDIS_MASTER_PORT_NUMBER"
        # Configure replicas to use TLS for outgoing connections to the master
        if is_boolean_yes "$REDIS_TLS_ENABLED"; then
            redis_conf_set tls-replication yes
        fi
    fi
}

# 检测 Redis 服务是否在运行中
# 全局变量:
#   APP_RUN_DIR
# 返回值:
#   布尔值
#########################
is_redis_running() {
    local pid
    pid="$(get_pid_from_file "$APP_RUN_DIR/redis_6379.pid")"

    if [[ -z "$pid" ]]; then
        false
    else
        is_service_running "$pid"
    fi
}

# 以后台方式启动 Redis 服务，并等待启动就绪
# 全局变量:
#   REDIS_*
redis_start_server_bg() {
    is_redis_running && return
    debug "Starting Redis..."
    if _is_run_as_root; then
        gosu "$REDIS_DAEMON_USER" "redis-server" "${REDIS_CONF_FILE}" "--daemonize" "yes"
    else
        "redis-server" "${REDIS_CONF_FILE}" "--daemonize" "yes"
    fi
    local counter=3
    while ! is_redis_running ; do
        if [[ "$counter" -ne 0 ]]; then
            break
        fi
        sleep 1;
        counter=$((counter - 1))
    done

    # 检测端口是否就绪
    # wait-for-port --timeout 60 "$REDIS_PORT_NUMBER"
}

# 停止 Redis 后台服务
# 全局变量:
#   ENV_DEBUG
redis_stop_server() {
    local pass
    local port
    local args

    ! is_redis_running && return
    pass="$(redis_conf_get "requirepass")"
    is_boolean_yes "$REDIS_TLS_ENABLED" && port="$(redis_conf_get "tls-port")" || port="$(redis_conf_get "port")"

    [[ -n "$pass" ]] && args+=("-a" "\"$pass\"")
    [[ "$port" != "0" ]] && args+=("-p" "$port")
    #args+=("--daemonize" "yes")

    debug "Stopping Redis..."
    if _is_run_as_root; then
        gosu "$REDIS_DAEMON_USER" "redis-cli" "${args[@]}" shutdown
    else
        "redis-cli" "${args[@]}" shutdown
    fi
    local counter=5
    while is_redis_running ; do
        if [[ "$counter" -ne 0 ]]; then
            break
        fi
        sleep 1;
        counter=$((counter - 1))
    done
}

# 应用默认初始化操作
# 执行完毕后，会在 ${REDIS_DATA_DIR} 目录中生成 app_init_flag 及 data_init_flag 文件
docker_app_init() {
    LOG_D "Check init status of ${APP_NAME}..."

    # 检测配置文件是否存在
    if [[ ! -f "$REDIS_CONF_FILE" || ! -f "${REDIS_DATA_DIR}/app_init_flag" ]]; then
        LOG_I "No injected configuration file found, creating default config files..."
        redis_generate_conf

        # Configure Replication mode
        if [[ -n "$REDIS_REPLICATION_MODE" ]]; then
            redis_configure_replication
        fi

        echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." > ${REDIS_DATA_DIR}/app_init_flag
    else
        LOG_I "User injected custom configuration detected!"
    fi

    if is_dir_empty "$REDIS_DATA_DIR" || [[ ! -f "${REDIS_DATA_DIR}/data_init_flag" ]]; then
        LOG_I "Deploying ${APP_NAME} from scratch..."

        echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." > ${REDIS_DATA_DIR}/data_init_flag
    else
        LOG_I "Deploying ${APP_NAME} with persisted data..."
    fi
}

# 用户自定义的应用初始化操作，依次执行目录initdb.d中的初始化脚本
# 执行完毕后，会在 ${REDIS_DATA_DIR} 目录中生成 custom_init_flag 文件
docker_custom_init() {
    # 检测用户配置文件目录是否存在initdb.d文件夹，如果存在，尝试执行目录中的初始化脚本
    if [ -d "${REDIS_CONF_DIR}/initdb.d" ]; then
    	# 检测数据存储目录是否存在已初始化标志文件；如果不存在，进行初始化操作
    	if [ ! -f "${REDIS_DATA_DIR}/custom_init_flag" ]; then
            LOG_I "Process custom init scripts for ${APP_NAME}..."

    		# 检测目录权限，防止初始化失败
    		ls "${REDIS_CONF_DIR}/initdb.d/" > /dev/null

    		docker_process_init_files ${REDIS_CONF_DIR}/initdb.d/*

    		echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." > ${REDIS_DATA_DIR}/custom_init_flag
    		LOG_I "Custom init for ${APP_NAME} complete."
    	else
    		LOG_I "Custom init for ${APP_NAME} already done before, skipping initialization."
    	fi
    fi
}
