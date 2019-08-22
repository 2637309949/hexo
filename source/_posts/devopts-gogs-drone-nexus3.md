---
title: Gogs-Drone-Nexus3自動部署流程
date: 2019-08-21 10:29:24
categories: 
- DevOpts
tags:
	- docker
	- ci/di
---
在我们实际开发中持续化集成和持续化部署是最常见的，我们每天都会持续化集成n次，部署测试n次，所以搭建一个自动化ci/di流程是非常关键的，这里以Gogs-Drone-Nexus3为例子展开ci/di，从零打造一个单机版的自动发布流程。
<!-- more -->

应用清单

```sh
  |-----------------------------------------------    
  | 应用     作用           对外访问                
  |-----------------------------------------------           
  | gogos  | 代码托管      | http://127.0.0.1:1080 
  | drone  | 持续集成与部署 | http://127.0.0.1:2080 
  | nexus3 | 代码仓库      | http://127.0.0.1:8081
  | app    | 博客站点      | http://127.0.0.1:80   
  |-----------------------------------------------    
```


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

初次进去时需要配置一些东西，按实际情况填写即可，进去后注册一个账号，这里我们注册了一个simple账号,第一个注册的用户就是管理员

选择后gogs最终会生成一份存在/home/double/docker/data/gogs/gogs/conf.app.init，可以看看我的配置
```yml
APP_NAME = Gogs
RUN_USER = git
RUN_MODE = prod

[database]
DB_TYPE  = sqlite3
HOST     = 127.0.0.1:3306
NAME     = gogs
USER     = root
PASSWD   = 
SSL_MODE = disable
PATH     = data/gogs.db

[repository]
ROOT = /data/git/gogs-repositories

[server]
DOMAIN           = 172.20.10.3
HTTP_PORT        = 3000
ROOT_URL         = http://172.20.10.3:1080/
DISABLE_SSH      = false
SSH_PORT         = 22
START_SSH_SERVER = false
OFFLINE_MODE     = false

[mailer]
ENABLED = false

[service]
REGISTER_EMAIL_CONFIRM = false
ENABLE_NOTIFY_MAIL     = false
DISABLE_REGISTRATION   = false
ENABLE_CAPTCHA         = true
REQUIRE_SIGNIN_VIEW    = false

[picture]
DISABLE_GRAVATAR        = false
ENABLE_FEDERATED_AVATAR = false

[session]
PROVIDER = file

[log]
MODE      = file
LEVEL     = Info
ROOT_PATH = /app/gogs/log

[security]
INSTALL_LOCK = true
SECRET_KEY   = IqRMoYgjWb6ErPv
```


接着我们创建仓库inspiration博客站点（这个是我的博客站点）

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

最终会看到我们的app仓库，这个就是我们要部署的app。

![](/images/gogs-drone-nexus3/gogs.png)

## 部署drone
基于 Docker 的 CI/CD 工具 Drone 所有编译、测试的流程都在 Docker 容器中进行。开发者只需在项目中包含 .drone.yml 文件，将代码推送到 git 仓库，Drone 就能够自动化的进行编译、测试、发布。drone是年轻的一代CI/DI工具比以前用的jenkin好太多了，而且简单易用透明。

```sh
docker run \
  --restart=always \
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
drone是没有账号管理的，所有认证都是直接调用仓库工具提供的auth api（相当于mock登录）

运行后，直接使用在gogs注册的账号登录即可，登录后可看到的效果。

![](/images/gogs-drone-nexus3/drone.png)

点击右上角的sync即可同步最新仓库，我们看到我们的inspiration已经过来了

由于我们使用的是IP，所以drone仓库激活后在gogos创建的webhook有问题，所以我们需要在gogs修改一下，否则无法通信，打开仓库设置，修改ip和端口。

![](/images/gogs-drone-nexus3/hook.png)

修改后点击测试推送
![](/images/gogs-drone-nexus3/test-hook.png)

查看drone，看到已经在构建了，我们接下来修改.drone.yml让不再报错。
![](/images/gogs-drone-nexus3/test-drone.png)

## 部署nexus3
参考我们另一篇 `Nexus3搭建私有仓库`

## 编写CI/DI脚本

一开始我们先安装drone cli方便测试yml
```sh
curl -L https://github.com/drone/drone-cli/releases/download/v1.1.0/drone_linux_amd64.tar.gz | tar zx
sudo install -t /usr/local/bin drone
```

打开drone个人设置获取认证票据，下面是我的。

```sh
export DRONE_SERVER=http://127.0.0.1:2080
export DRONE_TOKEN=uF4qbQSjnlR2yiLNkhfOYFv9GlqhoMaf
drone info
```

查看当前building队列，说明cli正常了。
```sh
double@double:~/Work/repo/inspiration$ drone queue ls
item #15 
Status: running
Machine: ef7fdb4e7d05
OS: linux
Arch: amd64
Variant: 
Version: 
```

接着，在inspiration根目录下创建.drome.yaml

```yml
kind: pipeline
name: default

steps:
- name: master-build  
  image: node:carbon-alpine
  commands:
    - npm install
    - npm run build
  when:
    branch:
      - master
    event: [push]

# 我们的仓库配置
- name: master-docker  
  image: plugins/docker
  settings:
    registry: 172.20.10.3:8082
    mirror: https://registry.docker-cn.com
    username: simple
    password: admin123
    dockerfile: ./Dockerfile
    repo: 172.20.10.3:8082/${DRONE_REPO_NAME}
    tags: ${DRONE_COMMIT_BRANCH}-${DRONE_BUILD_NUMBER}
    insecure: true # http形式的要加上insecure
  when:
    branch:
      - master
    event: [push]
```

有一个地方需要非常注意，由于我们的仓库是insecure http形式的，所以要加上insecure: true，否则控制台不输出东西就终止了（自已debug半天才发现。。）

最后，在inspiration根目录下创建Dockerfile

```yml
FROM nginx:stable-alpine

RUN echo "http://mirrors.aliyun.com/alpine/v3.6/main/" > /etc/apk/repositories
RUN apk update && apk add tzdata \
    && rm -f /etc/localtime \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

WORKDIR /usr/share/nginx/html
RUN mkdir -p /etc/nginx/conf.d/
RUN mkdir -p /usr/share/nginx/html/inspiration

COPY nginx.conf /etc/nginx/conf.d/nginx.conf
COPY public /usr/share/nginx/html
COPY public /usr/share/nginx/html/inspiration

EXPOSE 80
CMD [ "nginx", "-g", "daemon off;" ]

```

Docfile的内容不懂的自已找资源学习，这里不扯。

最后推送
```sh
git push simple master
```

登录drone和nexus3查看效果

![](/images/gogs-drone-nexus3/drone-ok.png)

![](/images/gogs-drone-nexus3/nexus3-ok.png)

## 部署项目
![](/images/gogs-drone-nexus3/k8s-cd.jpg)

部署环节是个很关键的地方，很多公司有自已的部署方式，不外乎是单机和集群，通常我们线上都是使用成熟的容器集群框架，比如最流行的k8s, docker官方推出的swarm，这里由于是本地机子，我们这里直接ssh的方式去部署和演示，实际中我们要考虑CI工具和线上部署集群是否有现成的插件让CI直接推送。

我们屡一下整个发布流程，如下图。整个环节。

![](/images/gogs-drone-nexus3/all.png)

在部署的机器上部署ssh-server(其实考虑安全问题的话，我们可以对ip进行限制或者使用反向代理的形式登录服务器)

安装ssh-server
```sh
sudo apt-get install openssh-server
```
查看是否启动
```sh
double@double:~$ ps -aux | grep sshd
root      2331  0.0  0.0  72236  4556 ?        Ss   15:09   0:00 /usr/sbin/sshd -D
double    2516  0.0  0.0  14664  1060 pts/10   S+   16:49   0:00 grep sshd
root     14996  0.0  0.0   4308   408 ?        Ss   15:31   0:00 /usr/sbin/sshd -D -f /app/gogs/docker/sshd_config
```
未启动则
```sh
sudo service sshd start
```

继续在.drone.yml添加插件

```yml
- name: master-deploy  
  image: appleboy/drone-ssh
  settings:
    host:
      - 172.20.10.3
    username: double
    password:
      from_secret: ssh_secret
    port: 22
    command_timeout: 2m
    script:
      - docker pull 172.20.10.3:8082/${DRONE_REPO_NAME}:${DRONE_COMMIT_BRANCH}-${DRONE_BUILD_NUMBER}
      - docker run --rm -d -p 80:80/tcp 172.20.10.3:8082/${DRONE_REPO_NAME}:${DRONE_COMMIT_BRANCH}-${DRONE_BUILD_NUMBER}
```

记得在drone对应的repo上添加你的ssh密码，如考虑安全还可以配置秘钥的形式，drone-ssh当前也是支持的。

最后再推送一次git，等drone构建完成，直接打开80端口可以看到app效果。

![](/images/gogs-drone-nexus3/app.png)
