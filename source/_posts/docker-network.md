---
title: 深入docker网络配置
date: 2019-08-23 20:57:05
categories: 
- Docker
tags:
	- docker
	- network
---

网络配置是一个非常关键的地方，在大学中计算机系的有一门计算机基础的课程，还好有好好学习，这里我们来看看docker内部的网络是如何运行的，这对于我们的docker配置有更好的理解和深入。

<!-- more -->

## 默认 docker0 网桥
![](/images/docker-network/docker0.png)

当 Docker 启动时，会自动在主机上创建一个 docker0 虚拟网桥，实际上是 Linux 的一个 bridge，可以理解为一个软件交换机。它会在挂载到它的网口之间进行转发。该dokcer0虚拟网桥网段为172.17.0.0/16，同时它被分配了一个172.17.0.1，掩码为 255.255.0.0。可以看到之后创建的容器被分配的ip均在这个网段中。

![](/images/docker-network/portainer.png)

当创建一个 Docker 容器的时候，同时会创建了一对 veth pair 接口（当数据包发送到一个接口时，另外一个接口也可以收到相同的数据包）。这对接口一端在容器内，即 eth0；另一端在本地并被挂载到 docker0 网桥，名称以 veth 开头（例如 vethAQI2QT）。通过这种方式，主机可以跟容器通信，容器之间也可以相互通信。Docker 就创建了在主机和所有容器之间一个虚拟共享网络。

![](/images/docker-network/network.png)


## 端口映射实现

### NAT
![](/images/docker-network/nat.jpg)

NAT（Network Address Translation，网络地址转换）是1994年提出的。当在专用网内部的一些主机本来已经分配到了本地IP地址（即仅在本专用网内使用的专用地址），但现在又想和因特网上的主机通信（并不需要加密）时，可使用NAT方法。
这种方法需要在专用网连接到因特网的路由器上安装NAT软件。装有NAT软件的路由器叫做NAT路由器，它至少有一个有效的外部全球IP地址。这样，所有使用本地地址的主机在和外界通信时，都要在NAT路由器上将其本地地址转换成全球IP地址，才能和因特网连接。
另外，这种通过使用少量的公有IP 地址代表较多的私有IP 地址的方式，将有助于减缓可用的IP地址空间的枯竭，而且还能够有效地避免来自网络外部的攻击，隐藏并保护网络内部的计算机。

### 容器之间访问

默认情况下，所有容器都会被连接到 docker0 网桥上。并通过本地系统iptables FORWARD实现

![](/images/docker-network/docker-forward.png)


### 容器内部访问外部

容器要想访问外部网络，需要本地系统的转发支持，同时它是通过nat实现的。

```sh
$sysctl net.ipv4.ip_forward
net.ipv4.ip_forward = 1
```

查看nat规则

![](/images/docker-network/nat-docker1.png)

来自172.17.0.0/16的ip向其他网段或公网ip的请求都会由系统网卡发出。

### 容器外部访问内部

通过端口映射的方式，我们查看nat

![](/images/docker-network/nat-docker2.png)

就是我们的应用的端口映射的iptables规则

![](/images/docker-network/portainer.png)

## 配置 docker0 网桥

### 网桥工具查看

每次创建一个新容器的时候，Docker 从可用的地址段中选择一个空闲的 IP 地址分配给容器的 eth0 端口。使用本地主机上 docker0 接口的 IP 作为所有容器的默认网关。
![](/images/docker-network/docker-bridge.png)


先下载bridge工具用来配置和查看网桥。

```sh
sudo apt-get install bridge-utils
```

```sh
double@double:~$ sudo brctl show
bridge name	bridge id		STP enabled	interfaces
br-0c91047ea78b		8000.0242f7613f75	no		
br-22b5e305afac		8000.02424799b917	no		
br-e8b91e143b98		8000.0242de4c6de8	no		
br-fa31ce4c002c		8000.02420bf13133	no		
docker0		8000.0242dce64085	no		veth856d2af
							vethc93fc40
							vethd0813e4
```

查看容器eth0

```sh
$ sudo docker run -i -t --rm busybox /bin/bash
```

```sh
$ ip addr show eth0
# show
188: eth0@if189: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue 
    link/ether 02:42:ac:11:00:04 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.4/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever
```


```sh
$ ip route
# show
default via 172.17.0.1 dev eth0 
172.17.0.0/16 dev eth0 scope link  src 172.17.0.4 
```

### 网桥工具配置
除了默认的 docker0 网桥，用户也可以指定网桥来连接各个容器。

新建新网桥，删除原来的网桥

```sh
$ sudo systemctl stop docker
$ sudo ip link set dev docker0 down
$ sudo brctl delbr docker0
```

创建一个网桥
```sh
$ sudo brctl addbr bridge0
$ sudo ip addr add 192.168.5.1/24 dev bridge0
$ sudo ip link set dev bridge0 up
```

查看新网桥
```sh
$ ip addr show bridge0
```

在 Docker 配置文件 /etc/docker/daemon.json 中添加如下内容
```json
{
  "bridge": "bridge0",
}
```


参考链接
[https://yeasy.gitbooks.io/docker_practice/advanced_network/](https://yeasy.gitbooks.io/docker_practice/advanced_network/)

