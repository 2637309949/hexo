---
title: Docker文件存储最佳实践
date: 2019-08-23 15:05:36
categories: 
- DevOpts
tags:
	- docker
---

在实际开发中我们很多场景都会用到文件存储，为了统一管理我们的文件卷数据，我们通常会创建单独一个存储卷来存储数据，对于存储卷可以对应不用的driver，比如local,nfs的，我们这里实际演示local-persist/filebrowser来统一管理我们的服务数据。
<!-- more -->

## 插件 local-persist
A volume plugin that extends the default local driver’s functionality by allowing you specify a mountpoint anywhere on the host, which enables the files to always persist, even if the volume is removed via docker volume rm.

### Install
local-persist提供插件方式安装和容器的方式安装，目前插件的方式有系统兼容，我们这里选择以容器插件的方式部署。
```sh
docker run -d \
    -v /run/docker/plugins/:/run/docker/plugins/ \
    -v /home/double/docker/data/srv/plugin-data/local-persist:/var/lib/docker/plugin-data/ \
    -v /home/double/docker/data/srv/volume/:/srv/volume/ \
    --name=local-persist-volume-plugin \
    cwspear/docker-local-persist-volume-plugin
```

参数说明：
[https://github.com/MatchbookLab/local-persist](https://github.com/MatchbookLab/local-persist)

我们使用
- /home/double/docker/data/srv/plugin-data 插件数据存储
- /home/double/docker/data/srv/volume      应用数据存储（我们在储存卷里配置）

### 创建应用Volumes
```sh
docker volume create -d local-persist -o mountpoint=/home/double/docker/data/srv/volume/appname --name=appname-volume
```

由于docker不支持volumes的子目录映射，如appname-volume/app1:/app1，我们使用创建命名空间去区分，也就是创建对应应用的volume
### volume规划

项目存储规划

![](/images/docker-fs/project.png)


### 部署ghost
我们举例部署一个ghost博客站点来管理我们的公司技术文档。

#### 创建ghost volume
```sh
docker volume create -d local-persist -o mountpoint=/home/double/docker/data/srv/volume/ghost --name=ghost-volume
```

```sh
sudo mkdir -p /home/double/docker/data/srv/volume/ghost
```
#### 挂载并运行

```sh
docker run -d -p 8089:2368 -v ghost-volume:/var/lib/ghost ghost
```

## 管理 Volume

我们使用filebrowser管理/home/double/docker/data/srv/volume/

```sh
docker -d run -v /home/double/docker/data/srv/volume/:/srv filebrowser/filebrowser:latest -p 8087:80
```

![](/images/docker-fs/filebrowser.png)

我们可以创建不同可见范围的账号

![](/images/docker-fs/filebrowser-user.png)



