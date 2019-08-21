---
title: Gogs-Drone-Nexus3自動部署流程
date: 2019-08-21 10:29:24
categories: 
- DevOpts
tags:
	- docker
	- ci/di
---
在我们实际开发中持续化集成和持续化部署是最常见的，我们每天都会持续化集成n次，部署测试n次，所以搭建一个ci/di流程是非常关键的，这里以Gogs-Drone-Nexus3为例子展开ci/di
<!-- more -->

## 部署gogs
Gogs 是一款类似GitHub的开源文件/代码管理系统（基于Git），Gogs 的目标是打造一个最简单、最快速和最轻松的方式搭建自助 Git 服务。使用 Go 语言开发使得 Gogs 能够通过独立的二进制分发，并且支持 Go 语言支持的 所有平台，包括 Linux、Mac OS X、Windows 以及 ARM 平台。

```sh
docker run \
    --name=gogs \
    -p 1022:22 \
    -p 1080:3000 \
    --restart=always \
    -v /home/double/docker/data/gogs:/data \
    -d \
    gogs/gogs
```

初次进去时需要配置一些东西，按实际情况填写即可，进去后注册一个账号，这里我们注册了一个simple账号

创建仓库inspiration（这个是我的博客站点）

本地拉取github上的inspiration
```sh
git clone https://github.com/2637309949/inspiration.git
```

创建新分支，并推送到我们的gogs来
```sh
double@double:~/Work/repo/inspiration$ git remote remove simple
double@double:~/Work/repo/inspiration$ git remote add simple http://172.20.10.3:1080/simple/inspiration.git
double@double:~/Work/repo/inspiration$ git push simple master
对象计数中: 550, 完成.
Delta compression using up to 8 threads.
压缩对象中: 100% (496/496), 完成.
Username for 'http://172.20.10.3:1080': simple
Password for 'http://simple@172.20.10.3:1080': 
写入对象中: 100% (550/550), 2.26 MiB | 351.00 KiB/s, 完成.
Total 550 (delta 187), reused 0 (delta 0)
remote: Resolving deltas: 100% (187/187), done.
To http://172.20.10.3:1080/simple/inspiration.git
 * [new branch]      master -> master
```
![](/images/gogs-drone-nexus3/gogs.png)


## 部署drone
基于 Docker 的 CI/CD 工具 Drone 所有编译、测试的流程都在 Docker 容器中进行。
开发者只需在项目中包含 .drone.yml 文件，将代码推送到 git 仓库，Drone 就能够自动化的进行编译、测试、发布。

```sh
docker run \
  --volume=/var/run/docker.sock:/var/run/docker.sock \
  --volume=/home/double/docker/data/drone:/data \
  --env=DRONE_GIT_ALWAYS_AUTH=false \
  --env=DRONE_GOGS_SERVER=http://172.20.10.3:1080 \
  --env=DRONE_RUNNER_CAPACITY=2 \
  --env=DRONE_SERVER_HOST=127.0.0.1 \
  --env=DRONE_SERVER_PROTO=https \
  --env=DRONE_TLS_AUTOCERT=false \
  --env=DRONE_USER_CREATE=username:simple,admin:true \
  --publish=2080:80 \
  --detach=true \
  --name=drone \
  drone/drone:1
```
注意gogs的配置即可，其他倒是没什么

用在gogs注册的账号登录
![](/images/gogs-drone-nexus3/drone.png)

点击右上角的sync即可同步最新仓库，我们看到我们的inspiration已经过来了


## 部署nexus3
参考我们另一篇 `Nexus3搭建私有仓库`

## 编写CI/DI脚本

在inspiration根目录下创建.drome.yaml



