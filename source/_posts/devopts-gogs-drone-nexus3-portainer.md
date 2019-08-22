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

stack也就是componse file，我们添加之前的inspiration项目
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
  image: drone-portainer
  settings:
    url: http://127.0.0.1:9000
    stack: appinspiration
    username:
      from_secret: portainer_username
    password:
      from_secret: portainer_password
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

