# Redis

针对 Redis 应用的 Docker 镜像，用于提供 Redis 服务。

详细信息可参照官网：https://redis.io



![redis-white](img/redis-white.png)

**版本信息：**

- 6.0、6.0.5
- 5.0、5.0.8、latest

**镜像信息：**

* 镜像地址：colovu/redis:latest
  * 依赖镜像：colovu/ubuntu:latest

**使用 Docker Compose 运行应用**

可以使用 Git 仓库中的默认`docker-compose.yml`，快速启动应用进行测试：

```shell
$ curl -sSL https://raw.githubusercontent.com/colovu/docker-redis/master/docker-compose.yml > docker-compose.yml

$ docker-compose up -d
```



## 默认对外声明

### 端口

- 6379：Redis 业务客户端访问端口
- 26379：Redis Sentinel 端口

### 数据卷

镜像默认提供以下数据卷定义：

```shell
/srv/data			# Redis 数据文件，主要存放Redis持久化数据；自动创建子目录redis
/srv/datalog	# Redis 数据操作日志文件；自动创建子目录redis
/srv/conf			# Redis 配置文件；自动创建子目录redis
/var/log			# 日志文件，日志文件名为：redis.log
/var/run			# 进程运行PID文件，PID文件名为：redis_6379.pid、redis_sentinel.pid
```

如果需要持久化存储相应数据，需要在宿主机建立本地目录，并在使用镜像初始化容器时进行映射。

举例：

- 使用宿主机`/host/dir/for/conf`存储配置文件
- 使用宿主机`/host/dir/for/data`存储数据文件
- 使用宿主机`/host/dir/for/log`存储日志文件

创建以上相应的宿主机目录后，容器启动命令中对应的映射参数类似如下：

```dockerfile
-v /host/dir/for/conf:/srv/conf -v /host/dir/for/data:/srv/data -v /host/dir/for/log:/var/log
```

使用 Docker Compose 时配置文件类似如下：

```yaml
services:
  redis:
  ...
    volumes:
      - /host/dir/to/conf:/srv/conf
      - /host/dir/to/data:/srv/data
      - /host/dir/to/log:/var/log
  ...
```

> 注意：应用需要使用的子目录会自动创建。



## 使用说明

- 在后续介绍中，启动的容器默认命名为`redis`/`redis1`/`redis2`/`redis3`，需要根据实际情况修改
- 在后续介绍中，容器默认使用的网络命名为`app-tier`，需要根据实际情况修改



### 容器网络

在工作在同一个网络组中时，如果容器需要互相访问，相关联的容器可以使用容器初始化时定义的名称作为主机名进行互相访问。

创建网络：

```shell
$ docker network create app-tier --driver bridge
```

- 使用桥接方式，创建一个命名为`app-tier`的网络



如果使用已创建的网络连接不同容器，需要在启动命令中增加类似`--network app-tier`的参数。使用 Docker Compose 时，在`docker-compose`的配置文件中增加：

```yaml
services:
	redis:
		...
		networks:
    	- app-tier
  ...
```



### 下载镜像

可以不单独下载镜像，如果镜像不存在，会在初始化容器时自动下载。

```shell
# 下载指定Tag的镜像
$ docker pull colovu/redis:tag

# 下载最新镜像
$ docker pull colovu/redis:latest
```

> TAG：替换为需要使用的指定标签名



### 持久化数据存储

如果需要将容器数据持久化存储至宿主机或数据存储中，需要确保宿主机对应的路径存在，并在启动时，映射为对应的数据卷。

Redis 镜像默认配置了用于存储数据的数据卷 `/srv/data`及用于存储数据日志的数据卷`/srv/datalog`。可以使用宿主机目录映射相应的数据卷，将数据持久化存储在宿主机中。路径中，应用对应的子目录如果不存在，容器会在初始化时创建，并生成相应的默认文件。

> 注意：将数据持久化存储至宿主机，可避免容器销毁导致的数据丢失。同时，将数据存储及数据日志分别映射为不同的本地设备（如不同的共享数据存储）可提供较好的性能保证。



### 实例化服务容器

生成并运行一个新的容器：

```shell
$ docker run -d --name redis -p 6379:6379 -e ALLOW_EMPTY_PASSWORD=yes colovu/redis:latest
```

- `-d`: 使用服务方式启动容器
- `--name redis`: 为当前容器命名
- `-e ALLOW_EMPTY_PASSWORD=yes`: 设置默认允许任意用户登录（调试时使用，生产系统应当使用认证）



使用数据卷映射生成并运行一个容器：

```shell
 $ docker run -d --name redis -e ALLOW_EMPTY_PASSWORD=yes \
 	-p 6379:6379 \
  -v /host/dir/to/data:/srv/data \
  -v /host/dir/to/datalog:/srv/datalog \
  -v /host/dir/to/conf:/srv/conf \
  colovu/redis:latest
```



### 连接容器

启用 [Docker container networking](https://docs.docker.com/engine/userguide/networking/)后，工作在容器中的 Redis 服务可以被其他应用容器访问和使用。

#### 命令行方式

使用已定义网络`app-tier`，启动 Redis 容器：

```shell
$ docker run -d --name redis -e ALLOW_EMPTY_PASSWORD=yes \
	-p 6379:6379 \
	--network app-tier \
	colovu/redis:latest
```

- `--network app-tier`: 容器使用的网络



其他业务容器连接至 Redis 容器：

```shell
$ docker run -d --name other-app -p 6379:6379 --network app-tier --link redis:redis.server other-app-image:tag
```

- `--link redis:redis.server`: 链接 redis 容器，并命名为 `redis.server` 进行使用（如果其他容器中使用了该名称进行访问）



#### Docker Compose 方式

如使用配置文件`docker-compose-test.yml`:

```yaml
version: '3.6'

services:
  redis:
    image: 'colovu/redis:latest'
    ports:
    	- 6379:6379
    environment:
    	- ALLOW_EMPTY_PASSWORD=yes
    networks:
      - app-tier
  myapp:
    image: 'other-app-img:tag'
    links:
    	- redis:redis.server
    networks:
      - app-tier
      
networks:
  app-tier:
    driver: bridge
```

> 注意：
>
> - 需要修改 `other-app-img:tag`为相应业务镜像的名字
> - 在其他的应用中，使用`redis`连接 Redis 容器，如果应用不是使用的该名字，可以重定义启动时的命名，如使用`--links redis:name-in-app`进行名称映射

启动方式：

```shell
$ docker-compose -f docker-compose-test.yml up -d
```

- 如果配置文件命名为`docker-compose.yml`，可以省略`-f docker-compose-test.yml`参数



#### 其他连接操作

使用 exec 命令访问容器ID或启动时的命名，进入容器并执行命令：

```shell
$ docker exec -it redis /bin/bash
```

- `/bin/bash`: 在进入容器后，运行的命令



使用 attach 命令进入已运行的容器：

```shell
$ docker attach --sig-proxy=false redis
```

- **该方式无法执行命令**，仅用于通过日志观察应用运行状态
- 如果不使用` --sig-proxy=false`，关闭终端或`Ctrl + C`时，会导致容器停止



### 停止容器

使用 stop 命令以容器ID或启动时的命名方式停止容器：

```shell
$ docker stop redis
```



### 查看日志

默认方式启动容器时，容器的运行日志输出至终端，可使用如下方式进行查看：

```shell
$ docker logs redis
```

在使用 Docker Compose 管理容器时，使用以下命令查看：

```shell
$ docker-compose logs redis
```



## Docker Compose 部署

### 单机部署

根据需要，修改 Docker Compose 配置文件，如`docker-compose.yml`，并启动:

```bash
$ docker-compose up -d
```

- 在不定义配置文件的情况下，默认使用当前目录的`docker-compose.yml`文件
- 如果配置文件为其他名称，可以使用`-f 文件名`方式指定



`docker-compose.yml`文件参考如下：

```yaml
version: '3.6'

services:
  redis:
    image: 'colovu/redis:latest'
    ports:
      - '6379:6379'
    environment:
      - ALLOW_EMPTY_PASSWORD=yes
      - REDIS_DISABLE_COMMANDS=FLUSHDB,FLUSHALL
```



#### 环境验证





### 集群部署

根据需要，修改 Docker Compose 配置文件，如`docker-compose-cluster.yml`，并启动:

```bash
$ docker-compose -f docker-compose-cluster.yml up -d
```

- 在不定义配置文件的情况下，默认使用当前目录的`docker-compose.yml`文件



可以使用 [`docker stack deploy`](https://docs.docker.com/engine/reference/commandline/stack_deploy/) 或 [`docker-compose`](https://github.com/docker/compose) 方式，启动一组服务容器。 `docker-compose.yml` 配置文件（伪集群）参考如下：

```yaml
version: '3.6'

services:
  redis-primary:
    image: 'colovu/redis:latest'
    ports:
      - '6379:6379'
    environment:
      - REDIS_REPLICATION_MODE=master
      - REDIS_PASSWORD=colovu
      - REDIS_DISABLE_COMMANDS=FLUSHDB,FLUSHALL

  redis-replica:
    image: 'colovu/redis:latest'
    ports:
      - '6379'
    environment:
      - REDIS_REPLICATION_MODE=slave
      - REDIS_MASTER_HOST=redis-primary
      - REDIS_MASTER_PORT_NUMBER=6379
      - REDIS_MASTER_PASSWORD=colovu
      - REDIS_PASSWORD=colovu
      - REDIS_DISABLE_COMMANDS=FLUSHDB,FLUSHALL
    depends_on:
      - redis-primary

```

> 由于配置的是伪集群模式, 所以各个 server 的端口参数必须不同（使用同一个宿主机的不同端口）



以上方式将以 [replicated mode](https://redis.io/topics/cluster-tutorial) 启动 Redis 。也可以以  [Docker Swarm](https://www.docker.com/products/docker-swarm) 方式进行配置。

> 注意：在一个机器上设置多个服务容器，并不能提供冗余特性；如果主机因各种原因导致宕机，则所有 Redis 服务都会下线。如果需要完全的冗余特性，需要在完全独立的不同物理主机中启动服务容器；即使在一个集群的中的不同虚拟主机中启动单独的服务容器也无法完全避免因物理主机宕机导致的问题。



#### 集群动态扩容

```shell
docker-compose up --detach --scale redis-primary=1 --scale redis-replica=3
```

以上命令，将 replicated 容器增加为 3 台，也可以使用类似命令减少容器数量。

> 不能增加/减少 primary 容器的数量，仅能存在一个 primary 容器节点。



#### 环境验证

使用`docker ps`命令可以查看所有在运行的容器：





## 容器配置

在初始化 redis 容器时，如果配置文件`zoo.cfg`不存在，可以在命令行中使用相应参数对默认参数进行修改。类似命令如下：

```shell
$ docker run -d --restart always -e "REDIS_INIT_LIMIT=10" --name zoo1 colovu/zookeeper:latest
```



### 常规配置参数

常使用的环境变量主要包括：

#### `REDIS_PORT`

默认值：**6379**。设置应用的默认客户访问端口。

#### `REDIS_DISABLE_COMMANDS`

默认值：**无**。设置禁用的 Redis 命令。

#### `REDIS_AOF_ENABLED`

默认值：**yes**。设置是否启用 Append Only File 存储。

#### `ENV_DEBUG`

默认值：**false**。设置是否输出容器调试信息。

> 可设置为：1、true、yes



### Sentinel配置参数

#### `REDIS_SENTINEL_HOST`

默认值：**无**。

#### `REDIS_SENTINEL_MASTER_NAME`

默认值：**无**。

#### `REDIS_SENTINEL_PORT_NUMBER`

默认值：**26379**。设置 Sentinel 默认端口。



### 集群配置参数

使用 redis 镜像，可以很容易的建立一个 [redis](https://redis.apache.org/doc/r3.1.2/redisAdmin.html) 集群。针对 redis 的集群模式（复制模式），有以下参数可以配置：

#### `REDIS_REPLICATION_MODE`

默认值：**无**。当前主机在集群中的工作模式，可使用值为：`master`/`slave`/`replica`。

#### `REDIS_MASTER_HOST`

默认值：**无**。作为`slave`/`replica`时，对应的 master 主机名或 IP 地址。

#### `REDIS_MASTER_PORT_NUMBER`

默认值：**6379**。master 主机对应的端口。

#### `REDIS_MASTER_PASSWORD`

默认值：**无**。master 主机对应的登录验证密码。



### 可选配置参数

如果没有必要，可选配置参数可以不用定义，直接使用对应的默认值，主要包括：

#### `REDIS_BASE_DIR`

默认值：**/usr/local/redis**。设置应用的默认基础目录。

#### `REDIS_DATA_DIR`

默认值：**/srv/data/redis**。设置应用的默认数据存储目录。

#### `REDIS_DATA_LOG_DIR`

默认值：**/srv/datalog/redis**。设置应用的默认数据日志目录。

#### `REDIS_CONF_DIR`

默认值：**/srv/conf/redis**。设置应用的默认配置文件目录。

#### `REDIS_LOG_DIR`

默认值：**/var/log/redis**。设置应用的默认日志目录。

#### `REDIS_DAEMON_USER`

默认值：**redis**。设置应用的默认运行用户。

#### `REDIS_DAEMON_GROUP`

默认值：**redis**。设置应用的默认运行用户组。

#### `ALLOW_EMPTY_PASSWORD`

默认值：**no**。设置是否允许无密码连接。如果没有设置`REDIS_PASSWORD`，则必须设置当前环境变量为 `yes`。

#### `REDIS_PASSWORD`

默认值：**无**。客户端认证的密码。

#### `REDIS_PASSWORD_FILE`

默认值：**无**。以绝对地址指定的客户端认证用户密码存储文件。该路径指的是容器内的路径。

#### `REDIS_MASTER_PASSWORD_FILE`

默认值：**无**。以绝对地址指定的服务器密码存储文件。该路径指的是容器内的路径。



### SSL配置参数

使用证书加密传输时，相关配置参数如下：

- `REDIS_TLS_ENABLED`: 启用或禁用 TLS。默认值：**no**
 - `REDIS_TLS_PORT`: 使用 TLS 加密传输的端口。默认值：**6379**
 - `REDIS_TLS_CERT_FILE`: TLS 证书文件。默认值：**无**
 - `REDIS_TLS_KEY_FILE`: TLS 私钥文件。默认值：**无**
 - `REDIS_TLS_CA_FILE`: TLS 根证书文件。默认值：**无**
 - `REDIS_TLS_DH_PARAMS_FILE`: 包含 DH 参数的配置文件 (DH 加密方式时需要)。默认值：**无**
 - `REDIS_TLS_AUTH_CLIENTS`: 配置客户端是否需要 TLS 认证。 默认值：**yes**

当使用 TLS 时，则默认的 non-TLS 通讯被禁用。如果需要同时支持 TLS 与 non-TLS 通讯，可以使用参数`REDIS_TLS_PORT`配置容器使用不同的 TLS 端口。

1. 使用 `docker run`：

   ```console
   $ docker run --name redis \
       -v /path/to/certs:/srv/cert/redis \
       -v /path/to/redis-data:/srv/data/redis \
       -e ALLOW_EMPTY_PASSWORD=yes \
       -e REDIS_TLS_ENABLED=yes \
       -e REDIS_TLS_CERT_FILE=/srv/cert/redis/redis.crt \
       -e REDIS_TLS_KEY_FILE=/srv/cert/redis/redis.key \
       -e REDIS_TLS_CA_FILE=/srv/cert/redis/redisCA.crt \
       colovu/redis:latest
   ```

2. 使用 `docker-compose.yml` 配置文件，确保包含以下类似内容：

   ```yaml
   services:
     redis:
     ...
       environment:
         ...
         - REDIS_TLS_ENABLED=yes
         - REDIS_TLS_CERT_FILE=/srv/cert/redis/redis.crt
         - REDIS_TLS_KEY_FILE=/srv/cert/redis/redis.key
         - REDIS_TLS_CA_FILE=/srv/cert/redis/redisCA.crt
       ...
       volumes:
         - /path/to/certs:/srv/cert/redis
         - /path/to/redis-data:/srv/data/redis
     ...
   ```



### 应用配置文件

应用配置文件默认存储在容器内：`/srv/conf/redis/redis.conf`。

#### 使用已有配置文件

Redis 容器的配置文件默认存储在数据卷`/srv/conf`中，文件名及子路径为`redis/redis.conf`。有以下两种方式可以使用自定义的配置文件：

- 直接映射配置文件

```shell
$ docker run -d --restart always --name redis -v $(pwd)/redis.conf:/srv/conf/redis/redis.conf colovu/redis:latest
```

- 映射配置文件数据卷

```shell
$ docker run -d --restart always --name redis -v $(pwd):/srv/conf colovu/redis:latest
```

> 第二种方式时，本地路径中需要包含 redis 子目录，且相应文件存放在该目录中



#### 生成配置文件并修改

对于没有本地配置文件的情况，可以使用以下方式进行配置。

##### 使用镜像初始化容器

使用宿主机目录映射容器数据卷，并初始化容器：

```shell
$ docker run -d --restart always --name redis -v /host/path/to/conf:/srv/conf colovu/redis:latest
```

or using Docker Compose:

```yaml
version: '3.1'

services:
  redis:
    image: 'colovu/redis:latest'
    ports:
      - '6379'
    volumes:
      - /host/path/to/conf:/srv/conf
```

##### 修改配置文件

在宿主机中修改映射目录下子目录`redis`中文件`redis.conf`：

```shell
$ vi /path/to/redis.conf
```

##### 重新启动容器

在修改配置文件后，重新启动容器，以使修改的内容起作用：

```shell
$ docker restart redis
```

或者使用 Docker Compose：

```shell
$ docker-compose restart redis
```



## 安全

### 用户认证

Redis 镜像默认禁用了无密码访问功能，在实际生产环境中建议使用用户名及密码控制访问；如果为了测试需要，可以使用以下环境变量启用无密码访问功能：

```shell
ALLOW_EMPTY_PASSWORD=yes
```



通过配置环境变量`REDIS_PASSWORD`，可以启用基于密码的用户认证功能。命令行使用参考：

```
$ docker run -it -e REDIS_PASSWORD=colovu \
    colovu/redis:latest
```

使用 Docker Compose 时，`docker-compose.yml`应包含类似如下配置：

```
services:
  redis:
  ...
    environment:
      - REDIS_PASSWORD=colovu
  ...
```



### 持久化数据存储

Redis 镜像默认配置了用于存储数据及数据日志的数据卷 `/srv/data`和`/srv/datalog`。可以使用宿主机目录映射相应的数据卷，将数据持久化存储在宿主机中。

> 注意：将数据持久化存储至宿主机，可避免容器销毁导致的数据丢失。同时，将数据存储及数据日志分别映射为不同的本地设备（如不同的共享数据存储）可提供较好的性能保证。



## 日志

默认情况下，Docker 镜像配置为将容器日志直接输出至`stdout`，可以使用以下方式查看：

```bash
$ docker logs redis
```

使用 Docker Compose 管理时，使用以下命令：

```bash
$ docker-compose logs redis
```



实际使用时，可以配置将相应信息输出至`/var/log`或`/srv/datalog`数据卷的相应文件中。



## 容器维护

### 容器数据备份

默认情况下，镜像都会提供`/srv/data`数据卷持久化保存数据。如果在容器创建时，未映射宿主机目录至容器，需要在删除容器前对数据进行备份，否则，容器数据会在容器删除后丢失。

如果需要备份数据，可以使用按照以下步骤进行：

#### 停止当前运行的容器

如果使用命令行创建的容器，可以使用以下命令停止：

```bash
$ docker stop redis
```

如果使用 Docker Compose 创建的，可以使用以下命令停止：

```bash
$ docker-compose stop redis
```

#### 执行备份命令

在宿主机创建用于备份数据的目录`/path/to/back-up`，并执行以下命令：

```bash
$ docker run --rm -v /path/to/back-up:/backups --volumes-from redis busybox \
  cp -a /srv/data/redis /backups/
```

如果容器使用 Docker Compose 创建，执行以下命令：

```bash
$ docker run --rm -v /path/to/back-up:/backups --volumes-from `docker-compose ps -q redis` busybox \
  cp -a /srv/data/redis /backups/
```



### 容器数据恢复

在容器创建时，如果未映射宿主机目录至容器数据卷，则容器会创建私有数据卷。如果是启动新的容器，可直接使用备份的数据进行数据卷映射，命令类似如下：

```bash
$ docker run -v /path/to/back-up:/srv/data colovu/redis:latest
```

使用 Docker Compose 管理时，可直接在`docker-compose.yml`文件中指定：

```yaml
redis:
	volumes:
		- /path/to/back-up:/srv/data
```



### 镜像更新

针对当前镜像，会根据需要不断的提供更新版本。针对更新版本（大版本相同的情况下，如果大版本不同，需要参考指定说明处理），可使用以下步骤使用新的镜像创建容器：

#### 获取新版本的镜像

```bash
$ docker pull colovu/redis:TAG
```

这里`TAG`为指定版本的标签名，如果使用最新的版本，则标签为`latest`。

#### 停止容器并备份数据

如果容器未使用宿主机目录映射为容器数据卷的方式创建，参照`容器数据备份`中方式，备份容器数据。

如果容器使用宿主机目录映射为容器数据卷的方式创建，不需要备份数据。

#### 删除当前使用的容器

```bash
$ docker rm -v redis
```

使用 Docker Compose 管理时，使用以下命令：

```bash
$ docker-compose rm -v redis
```

#### 使用新的镜像启动容器

将宿主机备份目录映射为容器数据卷，并创建容器：

```bash
$ docker run --name redis -v /path/to/back-up:/srv/data colovu/redis:TAG
```

使用 Docker Compose 管理时，确保`docker-compose.yml`文件中包含数据卷映射指令，使用以下命令启动：

```bash
$ docker-compose up redis
```



## 注意事项

- 容器中 Redis 启动参数不能配置为后台运行，只能使用前台运行方式，即：`daemonize no`
- 如果应用使用后台方式运行，则容器的启动命令会在运行后自动退出，从而导致容器退出



----

本文原始来源 [Endial Fang](https://github.com/colovu) @ [Github.com](https://github.com)

