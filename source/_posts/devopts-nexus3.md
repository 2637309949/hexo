---
title: Nexus3搭建私有仓库
date: 2019-08-20 20:30:00
categories: 
- DevOpts
tags:
	- docker
	- ci/di
---
在企业开发中我们都会建立自已公司的仓库，便于管理各种引用包，同时也加速了拉取共用资源。这里我们使用相对成熟的nexus3搭建我们的私有仓库。
<!-- more -->

## 启动 Nexus 容器
```sh
$ docker run \
  -d --name nexus3 --restart=always -p 8081:8081 \
  -p 8082:8082 --mount src=nexus-data,target=/nexus-data sonatype/nexus3
```
注意：nexus内开放的端口要记得在run nexus时声明，如上面的8082是我们下面开启服务的端口，我们这里把它映射出来。

### 登录nexus
```sh
docker exec -it 9cd27dc221d0be4fdd6661f1ca4f6988d1e14d5537ac9f3bcdb10a770c1bf018 /bin/sh -c "[ -e /bin/bash ] && /bin/bash || /bin/sh"
```

### 重置密码
进容器查看默认密码，默认账号admin，密码在/nexus-data/admin.password，
```sh
bash-4.4$ cd nexus-data/
bash-4.4$ ls
admin.password  elasticsearch      javaprefs  log                  tmp
blobs           etc                kar        orient
cache           generated-bundles  keystores  port
db              instances          lock       restore-from-backup
bash-4.4$ cat admin.password 
d9dab0e4-9e59-484f-bc6c-9ff033be6729
```

进浏览器重置密码
浏览器打开`127.0.0.1:8081`，点击右上角的sign in，输入
账号密码admin/d9dab0e4-9e59-484f-bc6c-9ff033be6729，接着重置密码

## 创建仓库
nexus3目前支持的仓库类型

![](/images/nexus3/repositories.png)

我们这里建立一个docker(hosted)来存储我们的docker镜像
（实际中我们可以创建一个docker (proxy) 类型的仓库链接到 DockerHub 上。再创建一个 docker (group) 类型的仓库把刚才的 hosted 与 proxy 添加在一起。主机在访问的时候默认下载私有仓库中的镜像，如果没有将链接到 DockerHub 中下载并缓存到 Nexus 中。）

docker(hosted)
1. Name: 仓库的名称
2. HTTP: 仓库单独的访问端口
3. Enable Docker V1 API: 如果需要同时支持 V1 版本请勾选此项（不建议勾选）。
4. Hosted -> Deployment pollcy: 请选择 Allow redeploy 否则无法上传 Docker 镜像。

我们选择http形式，如果需要https，则要配置证书
https形式的可以参考这篇文章[http://www.eryajf.net/1816.html](http://www.eryajf.net/1816.html)

## 添加访问权限

- 菜单 Security->Realms 把 Docker Bearer Token Realm 移到右边的框中保存。
- 添加用户规则：菜单 Security->Roles->Create role 在 Privlleges 选项搜索 docker 把相应的规则移动到右边的框中然后保存。
- 添加用户：菜单 Security->Users->Create local user 在 Roles 选项中选中刚才创建的规则移动到右边的窗口保存。

重启docker

```sh
systemctl restart docker
```

## 登录registry

登录127.0.0.1可以非https形式与仓库交互，如何是其他网段，我们需要开启TLS或者修改配置（下面）,我们这边情况适合单机部署服务的情况，本机访问即可
```sh
double@double:~/Work$ docker login 127.0.0.1:8082
Username: simple
Password: 
Login Succeeded
```
## 主机访问镜像仓库

默认情况下Docker 不允许非 HTTPS 方式推送镜像，（如果你配置的是TLS 的私有仓库，这节可以跳过）
在 /etc/docker/daemon.json 中写入如下内容（如果文件不存在请新建该文件）
```json
{
  "registry-mirror": [
    "https://registry.docker-cn.com"
  ],
  "insecure-registries": [
    "172.20.10.3:8082"
  ]
}
```
修改后记得要重启docker

## 推送镜像
### docker推送镜像到仓库
登录registry
```sh
double@double:~/Work$ docker login 127.0.0.1:8082
Username: simple
Password: 
Login Succeeded
```
对image打标记并推送
```sh
double@double:~/Work$ docker tag mongo:3.4.20-jessie 127.0.0.1:8082/mongo:3.4.20-jessie
double@double:~/Work$ docker push 127.0.0.1:8082/mongo:3.4.20-jessie
The push refers to repository [127.0.0.1:8082/mongo]
e837e1109f43: Pushed 
2133d8522bc2: Pushed 
8a149c25ef98: Pushed 
696604439d09: Pushed 
d7c5ad90f26f: Pushed 
90e3b5adb806: Pushed 
a0fe554d0346: Pushed 
3331ba0d1cf6: Pushed 
0dcc3466d5c9: Pushed 
1fcf7849ce05: Pushed 
43a852aaa685: Pushed 
3.4.20-jessie: digest: sha256:e8be4bb2b900165e188b07808178462ed1ce5b7f87578d71f4119a9316d6b151 size: 2615
```
### 登录nexus查看
![](/images/nexus3/push.png)

## 使用私有仓库

删除刚才的镜像
```sh
double@double:~$ docker images
REPOSITORY                               TAG                 IMAGE ID            CREATED             SIZE
sonatype/nexus3                          latest              35ca857d5b19        11 days ago         599MB
phpmyadmin/phpmyadmin                    latest              626319eaebed        2 months ago        421MB
redis                                    latest              a55fbf438dfd        4 months ago        95MB
127.0.0.1:8081/repository/simple/mongo   3.4.20-jessie       0b7f4e6af48a        4 months ago        390MB
127.0.0.1:8082/mongo                     3.4.20-jessie       0b7f4e6af48a        4 months ago        390MB
mongo                                    3.4.20-jessie       0b7f4e6af48a        4 months ago        390MB
```

```sh
docker rmi -f 0b7f4e6af48a
```

查看私有仓库
```sh
curl 127.0.0.1:8082/v2/_catalog
```

拉取私有仓库镜像

```sh
{"repositories":["mongo"]}double@double:~$ docker pull 127.0.0.1:8082/mongo:3.4.20-jessie
3.4.20-jessie: Pulling from mongo
2a639da97f77: Already exists 
073b4f52defe: Already exists 
bce37d0f5c17: Already exists 
379dc19f9963: Already exists 
e44806c61e63: Already exists 
b76faf91d209: Already exists 
dd1d9be5b26b: Already exists 
9420e1982a2f: Already exists 
9ad2432e6a03: Already exists 
741494f9ac47: Already exists 
a03462db0fd4: Already exists 
Digest: sha256:e8be4bb2b900165e188b07808178462ed1ce5b7f87578d71f4119a9316d6b151
Status: Downloaded newer image for 127.0.0.1:8082/mongo:3.4.20-jessie
```

