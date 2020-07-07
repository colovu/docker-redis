#!/bin/bash -e

# 在安装完应用后，使用该脚本修改默认配置文件中部分配置项
# 如果相应的配置项已经定义整体环境变量，则不需要在这里修改
echo "Process overrides for default configs..."
#sed -i -E 's/^listeners=/d' "$KAFKA_HOME/config/server.properties"

# 修改默认配置信息
sed -i -E 's/^bind .*/bind 0.0.0.0/g' "$APP_DEF_DIR/redis.conf"
sed -i -E 's/^pidfile .*/pidfile \/var\/run\/redis\/redis_6379.pid/g' "$APP_DEF_DIR/redis.conf"
sed -i -E 's/^daemonize .*/daemonize no/g' "$APP_DEF_DIR/redis.conf"
sed -i -E 's/^logfile .*/logfile \"\/var\/log\/redis\/redis.log\"/g' "$APP_DEF_DIR/redis.conf"

# 修改 Sentinel 默认配置信息
sed -i -E 's/^daemonize .*/daemonize yes/g' "$APP_DEF_DIR/sentinel.conf"
sed -i -E 's/^pidfile .*/pidfile \/var\/run\/redis\/redis-sentinel.pid/g' "$APP_DEF_DIR/sentinel.conf"
sed -i -E 's/^logfile .*/logfile \"\/var\/log\/redis\/redis-sentinel.log\"/g' "$APP_DEF_DIR/sentinel.conf"
