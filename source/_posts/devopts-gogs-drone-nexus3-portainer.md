---
title: Gogs-drone-nexus3自動部署流程2
date: 2019-08-22 22:45:06
categories: 
- DevOpts
tags:
	- docker
	- ci/di
---
在一个小型公司或者物理机器资源有限的情况下我们没法选择像swarn或者k8s，最近在找一些资源用来搭建单机或1-3机器的自动化部署最佳实践，这里我们选择gogs/drone/nexus3/portainer来搭建我们的自动化部署流程。当然如果你们物理机器有5+的推荐直接上k8s，笔者公司使用的就是k8s，机器4-一下的不推荐真心很不稳定。
<!-- more -->

## 部署gogs
`参考Gogs-Drone-Nexus3自動部署流程1`
## 部署drone
`参考Gogs-Drone-Nexus3自動部署流程1`
## 部署nexus3
`参考Gogs-Drone-Nexus3自動部署流程1`
## 部署portainer
Portainer是一个轻量级管理UI，可让您轻松管理Docker主机或Swarm集群。而且使用非常简单。它由一个可以在任何Docker引擎上运行的单个容器组成（支持Docker for Linux和Docker for Windows）。允许您管理Docker堆栈，容器，映像，卷，网络等等！它与独立的Docker引擎和 Docker Swarm兼容。


```sh
docker run -d \
    -p 9000:9000 \
    --restart always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/double/docker/data/portainer:/data portainer/portainer

```
我们将部署机器作为第一个Endpoints
```sh
-v /var/run/docker.sock:/var/run/docker.sock \
```

### 查看Endpoints
![](/images/devopts-gogs-drone-nexus3-portainer/endpoints-list.png)
Endpoint即每个拥有docker环境的端点，portainer支持添加多个端点，我们一开始把本地加入了端点

### 添加Endpoints
![](/images/devopts-gogs-drone-nexus3-portainer/endpoints-add.png)
我们可以把其他机器的docker加进来，推荐使用portainer agent。

### 添加Registries
把之前搭建的私有仓库加进来
![](/images/devopts-gogs-drone-nexus3-portainer/registry-add.png)

### 添加stack
![](/images/devopts-gogs-drone-nexus3-portainer/stack.png)

stack是兼容componse file的，我们添加之前的inspiration项目
```yml
version: '2'
services:
  web:
    image: 172.20.10.3:8082/inspiration:master-20
    ports:
      - 80
```

运行后我们可以看到containters已经有了，而且也可以访问了
![](/images/devopts-gogs-drone-nexus3-portainer/stack-run.png)
![](/images/devopts-gogs-drone-nexus3-portainer/stack-app.png)

接下来我们就在drone构建阶段中去把我们的项目部署到这个stack中来（stack不存在时会新建或存在时重新部署）

## 编写CI/DI脚本
在原来的构建脚本下添加maniack/drone-portainer

整个文件配置
```yml
kind: pipeline
name: default

steps:
- name: master-build  
  image: node:carbon-alpine
  commands:
    - npm config set registry http://registry.npm.taobao.org/
    - npm install
    - npm run build
    - npm config set registry https://registry.npmjs.org/
  when:
    branch:
      - master
    event: [push]

- name: master-docker  
  image: plugins/docker
  settings:
    registry: 172.20.10.3:8082
    mirror: http://hub-mirror.c.163.com
    username: simple
    password: admin123
    dockerfile: ./Dockerfile
    repo: 172.20.10.3:8082/${DRONE_REPO_NAME}
    tags: ${DRONE_COMMIT_BRANCH}-${DRONE_BUILD_NUMBER}
    insecure: true
  when:
    branch:
      - master
    event: [push]

- name: master-deploy
  image: maniack/drone-portainer
  settings:
    portainer: http://127.0.0.1:9000
    insecure: true
    username:
      from_secret: portainer_username
    password:
      from_secret: portainer_password
    endpoint: local
    stack: appinspiration
    file: docker-stack.yml
    environment:
      DRONE_COMMIT_BRANCH: ${DRONE_COMMIT_BRANCH}
      DRONE_BUILD_NUMBER: ${DRONE_BUILD_NUMBER}
```
 
根目录下添加docker-stack.yml
```yml
version: '2'
services:
  web:
    image: 172.20.10.3:8082/inspiration:${DRONE_COMMIT_BRANCH}-${DRONE_BUILD_NUMBER}
    ports:
      - 80
```

在drone中添加账号密码
![](/images/devopts-gogs-drone-nexus3-portainer/drone-pwd.png)

推上gogos触发构建后查看效果
![](/images/devopts-gogs-drone-nexus3-portainer/drone-detail.png)

在potainter查看效果
![](/images/devopts-gogs-drone-nexus3-portainer/app-update.png)

至此整个单机版的自动化部署方案完成啦。


## 负载均衡
我们使用haproxy作为负载均衡lb

```yml
version: '2'
services:
  web:
    image: 172.20.10.3:8082/inspiration:${DRONE_COMMIT_BRANCH}-${DRONE_BUILD_NUMBER}
    ports:
      - 80
  lb:
    image: dockercloud/haproxy
    ports:
      - 80:80
    links:
      - web
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

笔者在测试LB时stack文件声明的HAProxy不能自动links我们的应用，觉得很奇怪，如下面的lb理论在启动后会去docker-api拿到web的映射hostname并加入负载均衡里面去（省去手动配置），我们在宿主机下用docker-compose是正常的。如下

```sh
double@double:~/Work/K11/repo/inspiration$ docker-compose -f docker-stack.yml up
Recreating inspiration_web_1 ... done
Recreating inspiration_lb_1  ... done
Attaching to inspiration_web_1, inspiration_lb_1
lb_1   | INFO:haproxy:dockercloud/haproxy 1.6.7 is running outside Docker Cloud
lb_1   | INFO:haproxy:Haproxy is running by docker-compose, loading HAProxy definition through docker api
lb_1   | INFO:haproxy:dockercloud/haproxy PID: 7
lb_1   | INFO:haproxy:=> Add task: Initial start - Compose Mode
lb_1   | INFO:haproxy:=> Executing task: Initial start - Compose Mode
lb_1   | INFO:haproxy:==========BEGIN==========
lb_1   | INFO:haproxy:Linked service: inspiration_web
lb_1   | INFO:haproxy:Linked container: inspiration_web_1
lb_1   | INFO:haproxy:HAProxy configuration:
lb_1   | global
lb_1   |   log 127.0.0.1 local0
lb_1   |   log 127.0.0.1 local1 notice
lb_1   |   log-send-hostname
lb_1   |   maxconn 4096
lb_1   |   pidfile /var/run/haproxy.pid
lb_1   |   user haproxy
lb_1   |   group haproxy
lb_1   |   daemon
lb_1   |   stats socket /var/run/haproxy.stats level admin
lb_1   |   ssl-default-bind-options no-sslv3
lb_1   |   ssl-default-bind-ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA:DHE-DSS-AES128-SHA:DES-CBC3-SHA
lb_1   | defaults
lb_1   |   balance roundrobin
lb_1   |   log global
lb_1   |   mode http
lb_1   |   option redispatch
lb_1   |   option httplog
lb_1   |   option dontlognull
lb_1   |   option forwardfor
lb_1   |   timeout connect 5000
lb_1   |   timeout client 50000
lb_1   |   timeout server 50000
lb_1   | listen stats
lb_1   |   bind :1936
lb_1   |   mode http
lb_1   |   stats enable
lb_1   |   timeout connect 10s
lb_1   |   timeout client 1m
lb_1   |   timeout server 1m
lb_1   |   stats hide-version
lb_1   |   stats realm Haproxy\ Statistics
lb_1   |   stats uri /
lb_1   |   stats auth stats:stats
lb_1   | frontend default_port_80
lb_1   |   bind :80
lb_1   |   reqadd X-Forwarded-Proto:\ http
lb_1   |   maxconn 4096
lb_1   |   default_backend default_service
lb_1   | backend default_service
lb_1   |   server inspiration_web_1 inspiration_web_1:80 check inter 2000 rise 2 fall 3
lb_1   | INFO:haproxy:Launching HAProxy
lb_1   | INFO:haproxy:HAProxy has been launched(PID: 10)
lb_1   | INFO:haproxy:===========END===========
```

然而在portainter下的stack-file的启动日志，很明显木有自动加载hostname，如下

```sh
INFO:haproxy:dockercloud/haproxy 1.6.7 is running outside Docker Cloud,
INFO:haproxy:Haproxy is running by docker-compose, loading HAProxy definition through docker api,
INFO:haproxy:dockercloud/haproxy PID: 7,
INFO:haproxy:=> Add task: Initial start - Compose Mode,
INFO:haproxy:=> Executing task: Initial start - Compose Mode,
INFO:haproxy:==========BEGIN==========,
INFO:haproxy:Linked service: ,
INFO:haproxy:Linked container: ,
INFO:haproxy:HAProxy configuration:,
global,
  log 127.0.0.1 local0,
  log 127.0.0.1 local1 notice,
  log-send-hostname,
  maxconn 4096,
  pidfile /var/run/haproxy.pid,
  user haproxy,
  group haproxy,
  daemon,
  stats socket /var/run/haproxy.stats level admin,
  ssl-default-bind-options no-sslv3,
  ssl-default-bind-ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA:DHE-DSS-AES128-SHA:DES-CBC3-SHA,
defaults,
  balance roundrobin,
  log global,
  mode http,
  option redispatch,
  option httplog,
  option dontlognull,
  option forwardfor,
  timeout connect 5000,
  timeout client 50000,
  timeout server 50000,
listen stats,
  bind :1936,
  mode http,
  stats enable,
  timeout connect 10s,
  timeout client 1m,
  timeout server 1m,
  stats hide-version,
  stats realm Haproxy\ Statistics,
  stats uri /,
  stats auth stats:stats,
INFO:haproxy:Launching HAProxy,
INFO:haproxy:HAProxy has been launched(PID: 10),
INFO:haproxy:===========END===========,
```

我们看到日志link是失败的
```sh
INFO:haproxy:==========BEGIN==========,
INFO:haproxy:Linked service: ,
INFO:haproxy:Linked container: ,
INFO:haproxy:HAProxy configuration:,
```