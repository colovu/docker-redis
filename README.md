# Redis

针对Redis的 Docker 镜像，用于提供 Redis 服务。



## 基本信息

* 镜像地址：endial/redis:v5.0.8
  * 依赖镜像：endial/ubuntu:v18.04

- 镜像地址：endial/redis-alpine:v5.0.8
  - 依赖镜像：endial/alpine:v3.11



## 数据卷

镜像默认提供以下数据卷定义：

```shell
/srv/data			# Redis 数据文件，主要存放Redis持久化数据；自动创建子目录redis
/srv/conf			# Redis 配置文件；自动创建子目录redis
/var/log			# 日志文件，日志文件名为：redis-server.log
/var/run			# 进程运行PID文件，PID文件名为：redis_6379.pid
```

如果需要持久化存储相应数据，需要在宿主机建立本地目录，并在使用镜像初始化容器时进行映射。

举例：

- 使用宿主机`/opt/conf`存储配置文件
- 使用宿主机`/srv/data`存储数据文件
- 使用宿主机`/srv/log`存储日志文件

创建以上相应的宿主机目录后，容器启动命令中对应的映射参数类似如下：

```dockerfile
-v /host/dir/for/conf:/srv/conf -v /host/dir/for/data:/srv/data -v /host/dir/for/log:/var/log
```

> 注意：应用需要使用的子目录会自动创建。



## 使用说明



### 运行容器

生成并运行一个新的容器：

```bash
docker run -d --name redis \
  -p 6379:6379 \
  -v /host/dir/for/data:/srv/data \
  -v /host/dir/for/conf:/srv/conf \
  -v /host/dir/for/log:/var/log \
  -v /host/dir/for/run:/var/run \
  endial/redis:v5.0.8 
```



使用个性化配置文件运行容器：

```shell
docker run -d --name redis \
  -p 6379:6379 \
  -v /host/dir/for/data:/srv/data \
  -v /host/dir/for/conf:/srv/conf \
  -v /host/dir/for/log:/var/log \
  -v /host/dir/for/run:/var/run \
  endial/redis:v5.0.8 redis-server /srv/conf/redis/redis.conf --appendonly yes
```

- `redis-server /srv/conf/redis/redis.conf`：用于以指定的配置文件创建容器，路径不可修改（为容器中路径）
- 该文件可以在宿主机路径`/host/dir/for/conf`中找到并进行修改；修改后需要重启容器才能使配置起作用
- `--appendonly yes`：打开redis持久化配置（非必须），可通过配置文件修改



如果存在`dvc`数据容器，可以使用以下命令：

```bash
docker run -d --name redis \
  -p 6379:6379 \
  --volumes-from dvc \
  endial/redis:v5.0.8 
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
- 如果应用使用后台方式运行，则容器的启动命令会在运行后自动退出，从而导致容器退出



----

本文原始来源 [Endial Fang](https://github.com/endial) @ [Github.com](https://github.com)

