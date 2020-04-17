# Redis

针对Redis的 Docker 镜像，用于提供 Redis 服务。



## 基本信息

* 镜像地址：endial/redis:v5.0.8
  * 依赖镜像：endial/ubuntu:v18.04

- 镜像地址：endial/redis-alpine:v5.0.8
  - 依赖镜像：endial/alpine:v3.11



## 数据卷

```shell
/srv/data			# Redis 数据文件，主要存放Redis持久化数据；自动创建子目录redis
/srv/conf			# Redis 配置文件；自动创建子目录redis
/var/log			# 日志文件，日志文件名为：redis-server.log
/var/run			# 进程运行PID文件，PID文件名为：redis_6379.pid
```



## 使用说明

定义环境变量：

```shell
# 确定数据卷存储位置，可使用分散的目录或集中存储
export DOCKER_VOLUME_BASE=</volumes/path>
```

- 注意修改主文件路径为实际路径



### 运行容器

生成并运行一个新的容器：

```bash
docker run -d --name redis \
  -p 6379:6379 \
  -v $DOCKER_VOLUME_BASE/srv/data:/srv/data \
  -v $DOCKER_VOLUME_BASE/srv/conf:/srv/conf \
  -v $DOCKER_VOLUME_BASE/var/log:/var/log \
  -v $DOCKER_VOLUME_BASE/var/run:/var/run \
  endial/redis-ubuntu:v5.0.8 
```



使用个性化配置文件运行容器：

```shell
docker run -d --name redis \
  -p 6379:6379 \
  -v $DOCKER_VOLUME_BASE/srv/data:/srv/data \
  -v $DOCKER_VOLUME_BASE/srv/conf:/srv/conf \
  -v $DOCKER_VOLUME_BASE/var/log:/var/log \
  -v $DOCKER_VOLUME_BASE/var/run:/var/run \
  endial/redis-ubuntu:v5.0.8 redis-server /srv/conf/redis/redis.conf --appendonly yes
```

- `redis-server /srv/conf/redis/redis.conf`：用于以指定的配置文件创建容器，路径不可修改（容器中路径）
- 该文件可以在宿主机路径`$DOCKER_VOLUME_BASE/srv/conf`中找到，可修改；修改后需要重启容器
- `--appendonly yes`：打开redis持久化配置（非必须），可通过配置文件修改



如果存在`dvc`数据容器，可以使用以下命令：

```bash
docker run -d --name redis \
  -p 6379:6379 \
  --volumes-from dvc \
  endial/redis-ubuntu:v5.0.8 
```



### 进入容器

使用容器ID或启动时的命名（本例中命名为`redis`）进入容器：

```shell
docker exec -it redis /bin/sh
```



### 停止容器

使用容器ID或启动时的命名（本例中命名为`redis`）停止：

```shell
docker stop redis
```



## 注意事项

- 容器中Redis启动参数不能配置为后台运行，只能使用前台运行方式，即：`daemonize no`