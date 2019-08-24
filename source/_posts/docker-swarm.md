---
title: Swarm集群完整部署
date: 2019-08-23 23:06:03
categories: 
- Docker
tags:
	- cluster
	- docker
---

Docker Swarm 是 Docker 官方三剑客项目之一，提供 Docker 容器集群服务，是 Docker 官方对容器云生态进行支持的核心方案。Swarm具有容错能力的去中心化设计、内置服务发现、负载均衡、路由网格、动态伸缩、滚动更新、安全传输等。使得 Docker 原生的 Swarm 集群具备与 Mesos、Kubernetes 竞争的实力。其实部署集群重点是网络的配置，我们这里也很着重讲解网络的配置。

<!-- more -->

## 节点
![](/images/docker-swarm/swarm-diagram.png)

### 管理节点
用于 Swarm 集群的管理，docker swarm 命令基本只能在管理节点执行（节点退出集群命令 docker swarm leave 可以在工作节点执行）。一个 Swarm 集群可以有多个管理节点，但只有一个管理节点可以成为 leader，leader 通过 raft 协议实现。

### 工作节点

用于任务执行节点，管理节点将服务 (service) 下发至工作节点执行。管理节点默认也作为工作节点。你也可以通过配置让服务只运行在管理节点。

## 服务和任务

### 任务

任务 （Task）是 Swarm 中的最小的调度单位，目前来说就是一个单一的容器。

### 服务

服务 （Services） 是指一组任务的集合，服务定义了任务的属性。服务有两种模式：

- replicated services 按照一定规则在各个工作节点上运行指定个数的任务。

- global services 每个工作节点上运行一个任务

两种模式通过 docker service create 的 --mode 参数指定。

## 负载均衡

群集管理器使用ingress负载平衡来公开您希望在群集外部提供的服务。群集管理器可以自动为PublishedPort分配服务，也可以为服务配置PublishedPort。您可以指定任何未使用的端口。如果未指定端口，则swarm管理器会为服务分配30000-32767范围内的端口。Swarm模式有一个内部DNS组件，可以自动为swarm中的每个服务分配一个DNS条目。群集管理器使用内部负载平衡来根据服务的DNS名称在群集内的服务之间分发请求。

## 创建 Swarm

我只有一台机器，所以使用docker-machine，虚拟出多台机子，如果你是多台物理机子，那么可以跳过，安装docker-machine
```sh
curl -L https://linux-1251121573.cos.ap-guangzhou.myqcloud.com/docker/soft/docker-machine-Linux-x86_64.64 > /tmp/docker-machine && sudo mv /tmp/docker-machine /usr/local/bin/docker-machine
```
添加可执行
```sh
chmod +x /usr/local/bin/docker-machine
```

安装virtualbox
```sh
sudo apt-get install virtualbox
```

### 创建管理节点

```sh
docker-machine create -d virtualbox manager
```

进入管理节点初始化一个 Swarm 集群，如果你的 Docker 主机有多个网卡，拥有多个 IP，必须使用 --advertise-addr 指定 IP。我们可以查看IP`docker-machine ip manager`
```sh
docker-machine ssh manager
docker swarm init --advertise-addr 192.168.99.100
```

记得token和ip端口，我们下面创建工作节点用到
```sh
docker@manager:~$ docker swarm init --advertise-addr 192.168.99.100                                                                                                                          
Swarm initialized: current node (m3cvo1hzy3p6jbkji84f8a352) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-3r4qin8c9byg614da0vz65216gqad730nnxwoiaojgnw8hwg2h-em4037scmhwy7gw29zwn75dlu 192.168.99.100:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
```

如果你需要多添加管理节点，可以通过`docker swarm join-token manager`查看加入方式，我们这里只需要一个管理节点。


### 创建工作节点1

```sh
docker-machine create -d virtualbox worker1
docker-machine ssh worker1
```

加入上面的swarm
```sh
docker swarm join --token SWMTKN-1-3r4qin8c9byg614da0vz65216gqad730nnxwoiaojgnw8hwg2h-em4037scmhwy7gw29zwn75dlu 192.168.99.100:2377
```

### 创建工作节点2

```sh
docker-machine create -d virtualbox worker2
docker-machine ssh worker2
```

加入上面的swarm
```sh
docker swarm join --token SWMTKN-1-3r4qin8c9byg614da0vz65216gqad730nnxwoiaojgnw8hwg2h-em4037scmhwy7gw29zwn75dlu 192.168.99.100:2377
```

### 查看集群

```sh
double@double:~$ docker-machine ssh manager
   ( '>')
  /) TC (\   Core is distributed with ABSOLUTELY NO WARRANTY.
 (/-_--_-\)           www.tinycorelinux.net

docker@manager:~$ docker node ls                                   
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS      ENGINE VERSION
m3cvo1hzy3p6jbkji84f8a352 *   manager             Ready               Active              Leader              19.03.1
j9pvhyihe2er71g7lp79p2er1     worker1             Ready               Active                                  19.03.1
whpujyjx8ujipqul9bqz6toch     worker2             Ready               Active                                  19.03.1
```

因为我们是用docker-machine虚拟出来的机子，所以在本机上可以列出我们创建的虚拟机。
```sh
double@double:~$ docker-machine ls
NAME      ACTIVE   DRIVER       STATE     URL                         SWARM   DOCKER     ERRORS
manager   -        virtualbox   Running   tcp://192.168.99.100:2376           v19.03.1   
worker1   -        virtualbox   Running   tcp://192.168.99.101:2376           v19.03.1   
worker2   -        virtualbox   Running   tcp://192.168.99.102:2376           v19.03.1   
```

### UI管理集群
进入管理节点安装portainer
```sh
docker-machine ssh manager

export DOMAIN=double.portainer.com
export NODE_ID=$(docker info -f '{{.Swarm.NodeID}}')

docker node update --label-add portainer.portainer-data=true $NODE_ID

curl -L dockerswarm.rocks/portainer.yml -o portainer.yml # 需要修改，看下面

docker stack deploy -c portainer.yml portainer

docker stack ps portainer

docker service logs portainer_portainer
```

我们可以查看对应的compose-file（我们修改了traefik-net，traefik-net的配置以及traefik的搭建看下面一节，同时我们没有配置https所以也禁用http->https）
```yml
version: '3.3'

services:
  agent:
    image: portainer/agent
    environment:
      AGENT_CLUSTER_ADDR: tasks.agent
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
    networks:
      - agent-network
    deploy:
      mode: global
      placement:
        constraints:
          - node.platform.os == linux

  portainer:
    image: portainer/portainer
    command: -H tcp://tasks.agent:9001 --tlsskipverify
    volumes:
      - portainer-data:/data
    networks:
      - agent-network
      - traefik-net
    deploy:
      placement:
        constraints:
          - node.role == manager
          - node.labels.portainer.portainer-data == true
      labels:
        - traefik.frontend.rule=Host:${DOMAIN?Variable DOMAIN not set}
        - traefik.enable=true
        - traefik.port=9000
        - traefik.tags=traefik-net
        - traefik.docker.network=traefik-net
        # Traefik service that listens to HTTP
        # - traefik.redirectorservice.frontend.entryPoints=http
        # - traefik.redirectorservice.frontend.redirect.entryPoint=https
        # Traefik service that listens to HTTPS
        # - traefik.webservice.frontend.entryPoints=https

networks:
  agent-network:
    attachable: true
  traefik-net:
    external: true

volumes:
  portainer-data:
```

我们把portainter加入traefik的网络，所以traefik可以直接代理请求到9000
```yml
- traefik.port=9000
- traefik.tags=traefik-net
```

测试一下
```sh
double@double:~$ curl -H Host:double.portainer.com http://$(docker-machine ip manager)
<!DOCTYPE html><html lang="en" ng-app="portainer">
<head>
  <meta charset="utf-8">
  <title>Portainer</title>
  <meta name="description" content="">
  <meta name="author" content="Portainer.io">


  <!-- HTML5 shim, for IE6-8 support of HTML5 elements -->
  <!--[if lt IE 9]>
...
```
最后打开对应设置的domain`http://double.portainer.com`  (由于我们没有配置DNS，所以在访问的机子下添加 $(docker-machine ip manager) double.portainer.com)

![](/images/docker-swarm/portainer.png)
![](/images/docker-swarm/portainer-swarm.png)


详细的可以参考这里
[https://dockerswarm.rocks/portainer](https://dockerswarm.rocks/portainer)


查看是否部署成功。
```sh
docker stack ps portainer
docker service inspect --pretty portainer_portainer
docker service logs portainer_portainer
```

需要注意的是创建5分钟后没用登录会自动关闭
```sh
portainer_portainer.1.k56hxco75wmr@manager    | 2019/08/23 19:45:22 server: Listening on 0.0.0.0:8000...
portainer_portainer.1.k56hxco75wmr@manager    | 2019/08/23 19:45:22 Starting Portainer 1.22.0 on :9000
portainer_portainer.1.k56hxco75wmr@manager    | 2019/08/23 19:45:22 [DEBUG] [chisel, monitoring] [check_interval_seconds: 10.000000] [message: starting tunnel management process]
portainer_portainer.1.k56hxco75wmr@manager    | 2019/08/24 03:29:27 No administrator account was created after 5 min. Shutting down the Portainer instance for security reasons.
```

可以通过--force强制刷新
```sh
docker service update portainer_portainer --force
```

## Swarm 网络拓扑

ingress 拓扑

![](/images/docker-swarm/ingress-routing-mesh.png)


如果你想绕过默认的ingress（比如你只想在某台机器上对外暴露端口。），可以通过mode=指定。

你也可以配置外部负载均衡器
![](/images/docker-swarm/ingress-lb.png)

具体看这里
[https://docs.docker.com/engine/swarm/ingress/](https://docs.docker.com/engine/swarm/ingress/)

## 外部负载均衡器lb
光swarm内部的ingress是不够的，我们还需要把外部的网络请求转成内部的。这里使用Traefik. 官方地址[https://docs.traefik.io/](https://docs.traefik.io/)

![](/images/docker-swarm/taefik.png)

内部工作原理

![](/images/docker-swarm/internal.png)


Supported Providers¶
- Docker / Swarm mode
- Kubernetes
- Mesos / Marathon
- Rancher (API, Metadata)
- Azure Service Fabric
- Consul Catalog
- Consul / Etcd / Zookeeper / BoltDB
- Eureka
- Amazon ECS
- Amazon DynamoDB
- File
- Rest

我们直接配置Docker / Swarm mode

进入我们的管理节点

```sh
docker-machine ssh manager
```

创建traefik network
```sh
docker network create --driver=overlay traefik-net
```

创建traefik服务
```sh
docker service create \
    --name traefik \
    --constraint=node.role==manager \
    --publish 80:80 --publish 8080:8080 \
    --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
    --network traefik-net \
    traefik:latest \
    --docker \
    --docker.swarmMode \
    --docker.domain=traefik \
    --docker.watch \
    --api
```

我们可以打开8080看UI界面

![](/images/docker-swarm/taefik-ui.png)

接着我们可以在群集上部署我们的应用程序，这里是whoami，Go中的一个简单的Web服务器。我们在traefik-net网络上启动2项服务。

```sh
docker service create \
    --name whoami0 \
    --label traefik.port=80 \
    --network traefik-net \
    containous/whoami
```

```sh
docker service create \
    --name whoami1 \
    --label traefik.port=80 \
    --network traefik-net \
    --label traefik.backend.loadbalancer.sticky=true \
    containous/whoami
```

测试效果
```sh
double@double:~$ curl -H Host:whoami0.traefik http://$(docker-machine ip manager)
Hostname: 4ee722698d7d
IP: 127.0.0.1
IP: 10.0.2.31
IP: 172.18.0.5
GET / HTTP/1.1
Host: whoami0.traefik
User-Agent: curl/7.60.0
Accept: */*
Accept-Encoding: gzip
X-Forwarded-For: 10.255.0.2
X-Forwarded-Host: whoami0.traefik
X-Forwarded-Port: 80
X-Forwarded-Proto: http
X-Forwarded-Server: 64750f0c3074
X-Real-Ip: 10.255.0.2
```

如果请求不到数据可以log traefik
```sh
docker service logs traefik -f
```

收工，最后关闭我们的机器
```sh
double@double:~$ docker-machine stop manager worker1 worker2
Stopping "worker2"...
Stopping "manager"...
Stopping "worker1"...
```

参考链接
[https://docs.docker.com/engine/swarm/swarm-tutorial/drain-node/](https://docs.docker.com/engine/swarm/swarm-tutorial/drain-node/)
[https://docs.traefik.io/user-guide/swarm-mode/](https://docs.traefik.io/user-guide/swarm-mode/)
