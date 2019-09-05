---
title: K8S集群内容梳理
date: 2019-09-01 13:54:08
categories: 
- DevOpts
tags:
	- docker,k8s
---

Kubernetes 构建于 Google 数十年经验，一大半来源于 Google 生产环境规模的经验。结合了社区最佳的想法和实践。在分布式系统中，部署，调度，伸缩一直是最为重要的也最为基础的功能。Kubernetes 就是希望解决这一序列问题的。在笔者公司中是通过rancher界面管理K8S，背后很多知识点久而久之就淡忘了，所以趁现在有空梳理一下K8S的内容，我们还是使用上一节搭建的microk8s。

<!-- more -->

## Kubernetes特点

- 易学：轻量级，简单，容易理解
- 便携：支持公有云，私有云，混合云，以及多种云平台
- 可拓展：模块化，可插拔，支持钩子，可任意组合
- 自修复：自动重调度，自动重启，自动复制

## 内部结构
![](/images/k8s/k8s_architecture.png)

![](/images/k8s/kubernetes_design.jpg)


- 节点（Node）：一个节点是一个运行 Kubernetes 中的主机。
- 容器组（Pod）：一个 Pod 对应于由若干容器组成的一个容器组，同个组内的容器共享一个存储卷(volume)。
- 容器组生命周期（pos-states）：包含所有容器状态集合，包括容器组状态类型，容器组生命周期，事件，重启策略，以及 replication controllers。
- 副本控制器（Replication Controllers）：主要负责指定数量的 pod 在同一时间一起运行。
- 服务（services）：一个 Kubernetes 服务是容器组逻辑的高级抽象，同时也对外提供访问容器组的策略。
- 卷（volumes）：一个卷就是一个目录，容器对其有访问权限。
- 标签（labels）：标签是用来连接一组对象的，比如容器组。标签可以被用来组织和选择子对象。
- 接口权限（accessing_the_api）：端口，IP 地址和代理的防火墙规则。
- web 界面（ux）：用户可以通过 web 界面操作 Kubernetes。
- 命令行操作（cli）：kubecfg命令。

## kubectl
### Basic Commands (Beginner)
### Kubernetes Service
### Basic Commands (Intermediate)
### Deploy Commands
### Cluster Management Commands
### Troubleshooting and Debugging Commands
### Advanced Commands
### Settings Commands
### Other Commands

## 常用插件

### dns
DNS原理
[https://www.cnblogs.com/boshen-hzb/p/7495344.html](https://www.cnblogs.com/boshen-hzb/p/7495344.html)

microk8s开启dns
```sh
microk8s.enable dns
```
我们看到rancher已经有一个coredns-f7867546d-skmmz被启动了

### dashboard
microk8s开启dashboard
```sh
microk8s.enable dashboard
```
我们看到rancher已经有一个kubernetes-dashboard-7d75c474bb-p5rqn被启动了

不过该dashboard还处理集群内部中，我们可以通过kubectl proxy的方式去访问服务，不过我们统一用ingresss来处理吧。
由于默认的dashbord是ssl的，对于部署需要注意的事项可以参考：
[https://tonybai.com/2018/06/25/the-kubernetes-ingress-practice-for-https-service/](https://tonybai.com/2018/06/25/the-kubernetes-ingress-practice-for-https-service/)


### storage

### ingress
Ingress原理
[https://www.cnblogs.com/linuxk/p/9706720.html](https://www.cnblogs.com/linuxk/p/9706720.html)

microk8s开启ingress
```sh
microk8s.enable ingress
```
我们看到rancher已经有一个nginx-ingress-microk8s-controller-cjv2m被启动了，不过出错，443被占用，我们回到宿主机节点查看
```sh
double@double:~$ sudo netstat -tnlp | grep :443
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      5543/vmware-hostd   
tcp6       0      0 :::443                  :::*                    LISTEN      5543/vmware-hostd   
```
进入vmware把443占用改成其他的。

最后看到，表示ok了
```sh
-------------------------------------------------------------------------------
NGINX Ingress controller
Release: 0.24.1
Build: git-ce418168f
Repository: https://github.com/kubernetes/ingress-nginx
-------------------------------------------------------------------------------
```

```sh
double@double:~$ sudo netstat -tnlp | grep :443
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      18870/nginx: master 
tcp6       0      0 :::443                  :::*                    LISTEN      18870/nginx: master 
tcp6       0      0 :::443                  :::*                    LISTEN      18870/nginx: master 
tcp6       0      0 :::443                  :::*                    LISTEN      18870/nginx: master 
tcp6       0      0 :::443                  :::*                    LISTEN      18870/nginx: master 
tcp6       0      0 :::443                  :::*                    LISTEN      18870/nginx: master 
tcp6       0      0 :::443                  :::*                    LISTEN      18870/nginx: master 
tcp6       0      0 :::443                  :::*                    LISTEN      18870/nginx: master 
tcp6       0      0 :::443                  :::*                    LISTEN      18870/nginx: master 
double@double:~$ sudo netstat -tnlp | grep :80
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      18870/nginx: master 
tcp        0      0 127.0.0.1:8080          0.0.0.0:*               LISTEN      12114/kube-apiserve 
tcp6       0      0 :::80                   :::*                    LISTEN      18870/nginx: master 
tcp6       0      0 :::80                   :::*                    LISTEN      18870/nginx: master 
tcp6       0      0 :::80                   :::*                    LISTEN      18870/nginx: master 
tcp6       0      0 :::80                   :::*                    LISTEN      18870/nginx: master 
tcp6       0      0 :::80                   :::*                    LISTEN      18870/nginx: master 
tcp6       0      0 :::80                   :::*                    LISTEN      18870/nginx: master 
tcp6       0      0 :::80                   :::*                    LISTEN      18870/nginx: master 
tcp6       0      0 :::80                   :::*                    LISTEN      18870/nginx: master 
```

我们可以通过rancher的界面管理我们的ingress，我们把之前的inspiration打包进3200registry
```sh
docker tag bfe6dde444a9 localhost:32000/inspiration:registry
docker push localhost:32000/inspiration
```
然后在rancher创建app
![](/images/k8s/inspiration.png)

接着创建ingress
![](/images/k8s/inspiration_lb.png)

由于我们的inspiration是静态网页，资源是/目录的，所以我们这里直接把根目录划给inspiration

接着在本机创建host
```sh
127.0.0.1 dashbord.microk8s.com
```

最后访问
![](/images/k8s/inspiration_web.png)


### gpu
### istio
### registry
registry的搭建可以看我的另一篇`Nexus3搭建私有仓库`

microk8s自带一个registry，我们开启它
```sh
microk8s.enable registry
```
我们试着把本地inspiration推上32000

```sh
docker tag bfe6dde444a9 localhost:32000/inspiration:registry
```

```sh
double@double:~$ docker push localhost:32000/inspiration 
The push refers to repository [localhost:32000/inspiration]
6aea07e1609d: Layer already exists 
e00130921dc2: Layer already exists 
e0e384814422: Layer already exists 
a38699e45aa7: Layer already exists 
77edc51b295a: Layer already exists 
33b1e8df5729: Layer already exists 
acdd6738af44: Layer already exists 
03901b4a2ea8: Layer already exists 
registry: digest: sha256:42fc45659bdf6135733ba76b2fe89d9b596b96cf32987f2749966bc16dcecd36 size: 1993
```

### metrics-server
### prometheus
### fluentd
### jaeger
### linkerd
### rbac
### knative
### helm
### cilium
### cert

参考链接
[https://yeasy.gitbooks.io/docker_practice/kubernetes/concepts.html](https://yeasy.gitbooks.io/docker_practice/kubernetes/concepts.html)
