---
title: 网络知识整理
date: 2019-08-27 18:11:44
categories: 
- network
tags:
    - ip,network,nat,vpn
---

趁自已有时间，整理一下网络相关的知识，也算是大学的课程知识，以及结合自己在工作中的经验，好好把理论和实践的东西写写加强对网络的认识，尤其在搭理自已的服务器时事半功倍。
<!-- more -->

## IP
IP，全称互联网协议地址，是指IP地址，意思是分配给用户上网使用的网际协议（英语：InternetProtocol,IP）的设备的数字标签。常见的IP地址分为IPv4与IPv6两大类，但是也有其他不常用的小分类。它是IP协议提供的一种统一的地址格式，它为互联网上的每一个网络和每一台主机分配一个逻辑地址，以此来屏蔽物理地址的差异。

### 网络互联
网协是怎样实现的？网络互连设备，如以太网、分组交换网等，它们相互之间不能互通，不能互通的主要原因是因为它们所传送数据的基本单元（技术上称之为“帧”）的格式不同。IP协议实际上是一套由软件、程序组成的协议软件，它把各种不同“帧”统一转换成“网协数据包”格式，这种转换是因特网的一个最重要的特点，使所有各种计算机都能在因特网上实现互通，即具有“开放性”的特点。

### 数据包
那么，“数据包（data packet）”是什么？它又有什么特点呢？数据包也是分组交换的一种形式，就是把所传送的数据分段打成 “包”，再传送出去。但是，与传统的“连接型”分组交换不同，它属于“无连接型”，是把打成的每个“包”（分组）都作为一个“独立的报文”传送出去，所以叫做“数据包”。这样，在开始通信之前就不需要先连接好一条电路，各个数据包不一定都通过同一条路径传输，所以叫做“无连接型”。这一特点非常重要，它大大提高了网络的坚固性和安全性。每个数据包都有报头和报文这两个部分，报头中有目的地址等必要内容，使每个数据包不经过同样的路径都能准确地到达目的地。在目的地重新组合还原成原来发送的数据。这就要IP具有分组打包和集合组装的功能。

在传送过程中，数据包的长度为30000字节(Byte)(1字节=8二进制位)。

另外，特别注意的是，ip数据包指一个完整的ip信息，即ip数据包格式中各项的取值范围或规定，如版本号可以是4或者6,ip包头长度可以是20字节-60字节，总长度不超过65535字节，封装的上层协议可以是tcp和udp等。

### 分片和重组
分片后的IP数据包，只有到达目的地才能重新组装。重新组装由目的地的IP层来完成，其目的是使分片和重新组装过程对传输层（TCP和UDP）是透明的。已经分片过的数据包有可能会再次进行分片（不止一次）。

IP分片原因：链路层具有最大传输单元MTU这个特性，它限制了数据帧的最大长度，不同的网络类型都有一个上限值。以太网的MTU是1500，你可以用 netstat -i 命令查看这个值。

```sh
Kernel Interface table
Iface      MTU    RX-OK RX-ERR RX-DRP RX-OVR    TX-OK TX-ERR TX-DRP TX-OVR Flg
br-0c910  1500        0      0      0 0             0      0      0      0 BMU
br-22b5e  1500        0      0      0 0             0      0      0      0 BMU
br-e8b91  1500        0      0      0 0             0      0      0      0 BMU
br-fa31c  1500        0      0      0 0             0      0      0      0 BMU
docker0   1500      807      0      0 0          1478      0      0      0 BMRU
```

如果IP层有数据包要传，而且数据包的长度超过了MTU，那么IP层就要对数据包进行分片（fragmentation）操作，使每一片的长度都小于或等于MTU。我们假设要传输一个UDP数据包，以太网的MTU为1500字节，一般IP首部为20字节，UDP首部为8字节，数据的净荷（payload）部分预留是1500-20-8=1472字节。如果数据部分大于1472字节，就会出现分片现象。

### IP地址

```sh
double@double:~$ ifconfig
br-0c91047ea78b: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        inet 172.22.0.1  netmask 255.255.0.0  broadcast 172.22.255.255
        ether 02:42:1d:f0:43:33  txqueuelen 0  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```
所谓IP地址就是给每个连接在互联网上的主机分配的一个32位地址。

IP地址就好像电话号码（地址码）：有了某人的电话号码，你就能与他通话了。同样，有了某台主机的IP地址，你就能与这台主机通信了。

按照TCP/IP（Transport Control Protocol/Internet Protocol，传输控制协议/Internet协议）协议规定，IP地址用二进制来表示，每个IP地址长32bit，比特换算成字节，就是4个字节。例如一个采用二进制形式的IP地址是一串很长的数字，人们处理起来也太费劲了。为了方便人们的使用，IP地址经常被写成十进制的形式，中间使用符号“.”分开不同的字节。于是，上面的IP地址可以表示为“10.0.0.1”。IP地址的这种表示法叫做“点分十进制表示法”，这显然比1和0容易记忆得多。

有人会以为，一台计算机只能有一个IP地址，这种观点是错误的。我们可以指定一台计算机具有多个IP地址，因此在访问互联网时，不要以为一个IP地址就是一台计算机；另外，通过特定的技术，也可以使多台服务器共用一个IP地址，这些服务器在用户看起来就像一台主机似的。将IP地址分成了网络号和主机号两部分，设计者就必须决定每部分包含多少位。网络号的位数直接决定了可以分配的网络数（计算方法2^网络号位数）；主机号的位数则决定了网络中最大的主机数（计算方法2^主机号位数-2）。然而，由于整个互联网所包含的网络规模可能比较大，也可能比较小，设计者最后聪明的选择了一种灵活的方案：将IP地址空间划分成不同的类别，每一类具有不同的网络号位数和主机号位数。
IP地址是IP网络中数据传输的依据，它标识了IP网络中的一个连接，一台主机可以有多个IP地址。IP分组中的IP地址在网络传输中是保持不变的。

地址分配: 根据用途和安全性级别的不同，IP地址还可以大致分为两类：公共地址和私有地址。

- 公用地址
公共地址在Internet中使用，可以在Internet中随意访问

- 私有地址
私有地址只能在内部网络中使用，只有通过代理服务器才能与Internet通信。

### 网关地址

![](/images/network-all/gateway.jpg)

网关地址是具有路由功能的设备的IP地址，具有路由功能的设备有路由器、启用了路由协议的服务器（实质上相当于一台路由器）、代理服务器（也相当于一台路由器）。

如果2个IP地址，不在同一网段。这时候，要想通过IP地址去访问另一网段的计算机，就需要网关地址，网关地址就是出口的地址，而且，网关地址，是最近的一个出口的地址。网关地址总是与你的计算机的IP地址是同一网段的。

### 广播地址

广播地址(Broadcast Address)是专门用于同时向网络中所有工作站进行发送的一个地址。在使用TCP/IP 协议的网络中，主机标识段host ID 为全1 的IP 地址为广播地址，广播的分组传送给host ID段所涉及的所有计算机。例如，对于10.1.1.0 （255.255.255.0 ）网段，其广播地址为10.1.1.255 （255 即为2 进制的11111111 ），当发出一个目的地址为10.1.1.255 的分组（封包）时，它将被分发给该网段上的所有计算机。


### IP协议

- 1 Internet体系结构
一个TCP/IP互联网提供了三组服务。最底层提供无连接的传送服务为其他层的服务提供了基础。第二层一个可靠的传送服务为应用层提供了一个高层平台。最高层是应用层服务。

- 2 IP协议： 这种不可靠的、无连接的传送机制称为Internet协议。

- 3 IP协议三个定义：

    - IP定义了在TCP/IP互联网上数据传送的基本单元和数据格式。
    - IP软件完成路由选择功能，选择数据传送的路径。
    - IP包含了一组不可靠分组传送的规则，指明了分组处理、差错信息发生以及分组的规则。

- 4 IP数据包：联网的基本传送单元是IP数据包，包括数据包头和数据区部分。

- 5 IP数据包封装：物理网络将包括数据包包头的整个数据包作为数据封装在一个帧中。

- 6 MTU网络最大传送单元：不同类型的物理网对一个物理帧可传送的数据量规定不同的上界。

- 7 IP数据包的重组：一是在通过一个网络重组；二是到达目的主机后重组。后者较好，它允许对每个数据包段独立地进行路由选择，且不要求路由器对分段存储或重组。

- 8 生存时间：IP数据包格式中设有一个生存时间字段，用来设置该数据包在联网中允许存在的时间，以秒为单位。如果其值为0，就把它从互联网上删除，并向源站点发回一个出错消息。

- 9 IP数据包选项：
　　IP数据包选项字段主要是用于网络测试或调试。包括：记录路由选项、源路由选项、时间戳选项等。
　　路由和时间戳选项提供了一种监视或控制互联网路由器路由数据包的方法。

### 分类
![](/images/network-all/ip.jpg)

#### 网络号
用于识别主机所在的网络.

#### 主机号
用于识别该网络中的主机。
IP地址分为五类，A类保留给政府机构，B类分配给中等规模的公司，C类分配给任何需要的人，D类用于组播，E类用于实验，各类可容纳的地址数目不同。
A、B、C三类IP地址的特征：当将IP地址写成二进制形式时，A类地址的第一位总是0，B类地址的前两位总是10，C类地址的前三位总是110。

#### 实体IP
在网络的世界里，为了要辨识每一部计算机的位置，因此有了计算机 IP 位址的定义。一个 IP 就好似一个门牌！例如，你要去微软的网站的话，就要去『 64.4.11.42 』这个 IP 位置！这些可以直接在网际网络上沟通的 IP 就被称为『实体 IP 』了。

#### 虚拟IP

不过，众所皆知的，IP 位址仅为 xxx.xxx.xxx.xxx 的资料型态，其中， xxx 为 1-255 间的整数，由于计算机的成长速度太快，实体的 IP 已经有点不足了，好在早在规划 IP 时就已经预留了三个网段的 IP 做为内部网域的虚拟 IP 之用。这三个预留的 IP 分别为：

- A级：10.0.0.1 - 10.255.255.254
- B级：172.16.0.1 - 172.31.255.254
- C级：192.168.0.1 - 192.168.255.254

上述中最常用的是192.168.0.0这一组。不过，由于是虚拟 IP ，所以当您使用这些地址的时候﹐当然是有所限制的，限制如下：

- 私有位址的路由信息不能对外散播
- 使用私有位址作为来源或目的地址的封包﹐不能透过Internet来转送
- 关于私有位址的参考纪录（如DNS）﹐只能限于内部网络使用

`由于虚拟 IP 的计算机并不能直接连上 Internet ，因此需要特别的功能才能上网。不过，这给我们架设IP网络提供了很大的方便﹐比如﹕您的公司还没有连上Internet﹐但这不保证将来不会。使用公共IP的话﹐如果没经过注册﹐在以后真正连上网络的时候﹐就很可能和别人冲突了。也正如前面所分析的﹐到时候再重新规划IP的话﹐将是件非常头痛的问题。这时候﹐我们可以先利用私有位址来架设网络﹐等到真要连上internet的时候﹐我们可以使用IP转换协定﹐如 NAT (Network Addresss Translation)等技术﹐配合新注册的IP就可以了。`

#### 掩码
为了标识IP地址的网络部分和主机部分，要和地址掩码（Address Mask）结合，掩码跟IP地址一样也是32 bits，用点分十进制表示。IP地址网络部分对应的掩码部分全为“1”，主机部分对应的掩码全为“0”。

缺省状态下，如果没有进行子网划分，A类网络的子网掩码为255.0.0.0，B类网络的子网掩码为255.255.0.0，C类网络的子网掩码为255.255.255.0。利用子网，网络地址的使用会更加有效。

有了子网掩码后，IP地址的标识方法如下：
例：192.168.1.1 255.255.255.0或者标识成192.168.1.1/24（掩码中“1”的个数）

- 固定IP与动态IP
基本上，这两个东西是由于网络公司大量的成长下的产物，例如，你如果向中国电信申请一个商业型态的 ADSL 专线，那他会给你一个固定的实体 IP ，这个实体 IP 就被称为『固定 IP 』了。而若你是申请计时制的 ADSL ，那由于你的 IP 可能是由数十人共同使用，因此你每次重新开机上网时，你这部计算机的 IP 都不会是固定的！于是就被称为『动态 IP』或者是『浮动式IP』。基本上，这两个都是『实体IP』，只是网络公司用来分配给用户的方法不同而产生不同的名称而已！


#### 环回地址

```sh
double@double:~$ ping 127.0.0.2
PING 127.0.0.2 (127.0.0.2) 56(84) bytes of data.
64 bytes from 127.0.0.2: icmp_seq=1 ttl=64 time=0.028 ms
64 bytes from 127.0.0.2: icmp_seq=2 ttl=64 time=0.028 ms
```
127网段的所有地址都称为环回地址，主要用来测试网络协议是否工作正常的作用。比如使用ping。127.0.0.1就可以测试本地TCP/IP协议是否已正确安装。另外一个用途是当客户进程用环回地址发送报文给位于同一台机器上的服务器进程，比如在浏览器里输入127.1.2.3，这样可以在排除网络路由的情况下用来测试IIS是否正常启动。

## 网络七层协议

![](/images/network-all/OSI.webp)

- 物理层：硬件之间的传输，主要定义了物理设备的标准，负责0、1比特流（0/1序列与电压的高低、逛的闪灭之间的转换。该层为上层协议提供了一个传输数据的物理媒体。在这一层，数据的单位称为比特（bit）

- 数据链路层：负责物理层面上的互联的、节点间的通信传输（例如一个以太网项链的2个节点之间的通信）；该层的作用包括：物理地址寻址、数据的成帧、流量控制、数据的检错、重发等。在这一层，数据的单位称为帧（frame）

- 网络层：主要提供独立于硬件的逻辑寻址，实现物理地址与逻辑地址的转换，将数据传输到目标地址；目标地址可以使多个网络通过路由器连接而成的某一个地址，主要负责寻找地址和路由选择，网络层还可以实现拥塞控制、网际互连等功能，在这一层，数据的单位称为数据包（packet）

- 传输层：提供端到端的交换数据的机制，检查分组编号与次序，传输层对其上三层如会话层等，提供可靠的传输服务,对网络层提供可靠的目的地站点信息主要功能，在这一层，数据的单位称为数据段（segment）

- 会话层：负责建立和断开通信连接（数据流动的逻辑通路），记忆数据的分隔等数据传输相关的管理

- 表示层：将应用处理的信息转换为适合网络传输的格式，或将来自下一层的数据转换为上层能够处理的格式；主要负责数据格式的转换，确保一个系统的应用层信息可被另一个系统应用层读取。
具体来说，就是将设备固有的数据格式转换为网络标准传输格式，不同设备对同一比特流解释的结果可能会不同；因此，主要负责使它们保持一致

- 应用层：为应用程序提供服务并规定应用程序中通信相关的细节

## DNS
域名解析是把域名指向网站空间IP，让人们通过注册的域名可以方便地访问到网站的一种服务。IP地址是网络上标识站点的数字地址，为了方便记忆，采用域名来代替IP地址标识站点地址。域名解析就是域名到IP地址的转换过程。域名的解析工作由DNS服务器完成。

阿里DNS
```sh
223.5.5.5和223.6.6.6
```

## NAT

NAT最初定义在RFC1631，用在接入广域网中，通过修改IP报文的地址信息，实现将内部网络的私有地址到外部网络的公有地址的转换。NAT的产生原因和无分类域间路由(CIDR)一样，都是为了减缓IPv4地址耗竭的问题。NAT实现了私有地址到公有地址的转换，使得企业内部网络可以使用相同的私有地址，但在对外通信的时候却可以使用公有地址通信，降低了企业对公有地址的需求。

网络地址转换（Network Address Translation，NAT）机制的问题在于，NAT设备自动屏蔽了非内网主机主动发起的连接，也就是说，从外网发往内网的数据包将被NAT设备丢弃，这使得位于不同NAT设备之后的主机之间无法直接交换信息。这一方面保护了内网主机免于来自外部网络的攻击，另一方面也为P2P通信带来了一定困难。Internet上的NAT设备大多是地址限制圆锥形NAT或端口限制圆锥形 NAT，外部主机要与内网主机相互通信，必须由内网主机主动发起连接，使 NAT设备产生一个映射条目，这就有必要研究一下内网穿透技术。

### 工作原理
NAT通过修改IP报文的地址信息，实现将内部网络的私有地址到外部网络的公有地址的转换。

### 分类
#### 静态NAT(StaticNAT)
![](/images/network-all/static-nat.png)

一个私有IP固定映射一个公有IP地址，提供内网服务器的对外访问服务
#### 动态地址NAT(PooledNAT)

私有IP映射地址池中的公有IP，映射关系是动态的，临时的

#### 网络地址端口转换NAPT（Port-LevelNAT）
![](/images/network-all/dynamic-nat.jpg)

私有IP地址和端口号与同一个公有地址加端口进行映射

## VPN

虚拟私人网络（英语：Virtual Private Network，缩写：VPN）是一种常用于连接中、大型企业或团体与团体间的私人网络的通讯方法。它利用隧道协议（Tunneling Protocol）来达到保密、发送端认证、消息准确性等私人消息安全效果，这种技术可以用不安全的网络（例如：互联网）来发送可靠、安全的消息。需要注意的是，加密消息与否是可以控制的，如果是没有加密的虚拟专用网消息依然有被窃取的危险。

### 工作原理
以日常生活的例子来比喻，虚拟专用网就像：甲公司某部门的A想寄信去乙公司某部门的B。A已知B的地址及部门，但公司与公司之间的信不能注明部门名称。于是，A请自己的秘书把指定B所属部门的信（A可以选择是否以密码与B通信）放在寄去乙公司地址的大信封中。当乙公司的秘书收到从甲公司寄到乙公司的信件后，该秘书便会把放在该大信封内的指定部门信件以公司内部邮件方式寄给B。同样地，B会以同样的方式回信给A。在以上例子中，A及B是身处不同公司（内部网）的计算机（或相关机器），透过一般邮寄方式（公用网络）寄信给对方，再由对方的秘书（例如：支持虚拟专用网的路由器或防火墙）以公司内部信件（内部网）的方式寄至对方本人。请注意，在虚拟专用网中，因应网络架构，秘书及收信人可以是同一人。许多现在的操作系统，例如Windows及Linux等因其所用传输协议，已有能力不用透过其它网络设备便能达到虚拟专用网连接。

传统VPN的特点是点对点拓扑，它们不支持或连接广播域，因此Microsoft Windows NetBIOS等服务可能无法完全支持或像在局域网（LAN）上那样工作。设计人员已经开发出VPN变体，例如虚拟专用LAN服务（VPLS）和第2层隧道协议（L2TP），以克服此限制。[1]


```sh
-------------------------------------------------------------------------------------
借助代理服务器	    P2P 网页代理 SSH VPN 代理自动配置 反向代理
不借助代理服务器     HTTPS IPv6 Hosts DNSCrypt 加密SNI
-------------------------------------------------------------------------------------
自由软件	       赛风 GoAgent → XX-Net GoProxy Shadowsocks
                  Outline VPN ShadowsocksR V2Ray VPN Gate 蓝灯 WireGuard INTANG
-------------------------------------------------------------------------------------
专有软件	       自由门 无界浏览 Hotspot Shield fqrouter 世界通 逍遥游 火凤凰 花园网 
                  Puff 西厢计划 Telex 自由浏览
浏览器插件	        uProxy 红杏
-------------------------------------------------------------------------------------
```

## 应用实例

### 分配网段
#### dokcer bridge
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

### 反向代理

#### nginx
Nginx是一款轻量级的Web 服务器/反向代理服务器及电子邮件（IMAP/POP3）代理服务器，在BSD-like 协议下发行。其特点是占有内存少，并发能力强，事实上nginx的并发能力确实在同类型的网页服务器中表现较好，中国大陆使用nginx网站用户有：百度、京东、新浪、网易、腾讯、淘宝等。

配置ngnix
```sh
cat /usr/local/webserver/nginx/conf/nginx.conf
```
```sh
user www www;
worker_processes 2; #设置值和CPU核心数一致
error_log /usr/local/webserver/nginx/logs/nginx_error.log crit; #日志位置和日志级别
pid /usr/local/webserver/nginx/nginx.pid;
#Specifies the value for maximum file descriptors that can be opened by this process.
worker_rlimit_nofile 65535;
events
{
  use epoll;
  worker_connections 65535;
}
http
{
  include mime.types;
  default_type application/octet-stream;
  log_format main  '$remote_addr - $remote_user [$time_local] "$request" '
               '$status $body_bytes_sent "$http_referer" '
               '"$http_user_agent" $http_x_forwarded_for';
  
#charset gb2312;
  server_names_hash_bucket_size 128;
  client_header_buffer_size 32k;
  large_client_header_buffers 4 32k;
  client_max_body_size 8m;
     
  sendfile on;
  tcp_nopush on;
  keepalive_timeout 60;
  tcp_nodelay on;
  fastcgi_connect_timeout 300;
  fastcgi_send_timeout 300;
  fastcgi_read_timeout 300;
  fastcgi_buffer_size 64k;
  fastcgi_buffers 4 64k;
  fastcgi_busy_buffers_size 128k;
  fastcgi_temp_file_write_size 128k;
  gzip on; 
  gzip_min_length 1k;
  gzip_buffers 4 16k;
  gzip_http_version 1.0;
  gzip_comp_level 2;
  gzip_types text/plain application/x-javascript text/css application/xml;
  gzip_vary on;
 
  #limit_zone crawler $binary_remote_addr 10m;
 #下面是server虚拟主机的配置
 server
  {
    listen 80;#监听端口
    server_name localhost;#域名
    index index.html index.htm index.php;
    root /usr/local/webserver/nginx/html;#站点目录
      location ~ .*\.(php|php5)?$
    {
      #fastcgi_pass unix:/tmp/php-cgi.sock;
      fastcgi_pass 127.0.0.1:9000;
      fastcgi_index index.php;
      include fastcgi.conf;
    }
    location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|ico)$
    {
      expires 30d;
  # access_log off;
    }
    location ~ .*\.(js|css)?$
    {
      expires 15d;
   # access_log off;
    }
    access_log off;
  }
}
```

检查配置文件
```sh
/usr/local/webserver/nginx/sbin/nginx -t
```

启动 Nginx
```sh
/usr/local/webserver/nginx/sbin/nginx
```
#### taefik

Traefik is a modern HTTP reverse proxy and load balancer that makes deploying microservices easy. Traefik integrates with your existing infrastructure components (Docker, Swarm mode, Kubernetes, Marathon, Consul, Etcd, Rancher, Amazon ECS, ...) and configures itself automatically and dynamically. Pointing Traefik at your orchestrator should be the only configuration step you need.


1 — Launch Traefik — Tell It to Listen to Docker¶
```yml
version: '3'

services:
  reverse-proxy:
    image: traefik # The official Traefik docker image
    command: --api --docker # Enables the web UI and tells Traefik to listen to docker
    ports:
      - "80:80"     # The HTTP port
      - "8080:8080" # The Web UI (enabled by --api)
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # So that Traefik can listen to the Docker events
```
```sh
docker-compose up -d reverse-proxy
```

2 — Launch a Service — Traefik Detects It and Creates a Route for You
```yml
  whoami:
    image: containous/whoami # A container that exposes an API to show its IP address
    labels:
      - "traefik.frontend.rule=Host:whoami.docker.localhost"
```
```go
docker-compose up -d whoami
```

For Test
```sh
curl -H Host:whoami.docker.localhost http://127.0.0.1
```

### 系统路由
#### IPtables
IPtables分为2部分，一部分位于内核中，用来存放规则，称为NetFilter。还有一段在用户空间中，用来定义规则，并将规则传递到内核中，这段在用户空间中的程序就叫做iptables。
所以对于用户空间来说，就是按照需要生成一条条规则，然后向内核中提交，存放到NetFilter，让这些规则在数据传输与处理的过程中起作用。

使用方式
```sh
Usage: iptables -[ACD] chain rule-specification [options]
       iptables -I chain [rulenum] rule-specification [options]
       iptables -R chain rulenum rule-specification [options]
       iptables -D chain rulenum [options]
       iptables -[LS] [chain [rulenum]] [options]
       iptables -[FZ] [chain] [options]
       iptables -[NX] chain
       iptables -E old-chain-name new-chain-name
       iptables -P chain target [options]
       iptables -h (print this help information)
```

可选指令
```sh
Commands:
Either long or short options are allowed.
  --append  -A chain		Append to chain
  --check   -C chain		Check for the existence of a rule
  --delete  -D chain		Delete matching rule from chain
  --delete  -D chain rulenum
				Delete rule rulenum (1 = first) from chain
  --insert  -I chain [rulenum]
				Insert in chain as rulenum (default 1=first)
  --replace -R chain rulenum
				Replace rule rulenum (1 = first) in chain
  --list    -L [chain [rulenum]]
				List the rules in a chain or all chains
  --list-rules -S [chain [rulenum]]
				Print the rules in a chain or all chains
  --flush   -F [chain]		Delete all rules in  chain or all chains
  --zero    -Z [chain [rulenum]]
				Zero counters in chain or all chains
  --new     -N chain		Create a new user-defined chain
  --delete-chain
            -X [chain]		Delete a user-defined chain
  --policy  -P chain target
				Change policy on chain to target
  --rename-chain
            -E old-chain new-chain
				Change chain name, (moving any references)
```

可选参数
```sh
Options:
    --ipv4	-4		Nothing (line is ignored by ip6tables-restore)
    --ipv6	-6		Error (line is ignored by iptables-restore)
[!] --protocol	-p proto	protocol: by number or name, eg. `tcp'
[!] --source	-s address[/mask][...]
				source specification
[!] --destination -d address[/mask][...]
				destination specification
[!] --in-interface -i input name[+]
				network interface name ([+] for wildcard)
 --jump	-j target
				target for rule (may load target extension)
  --goto      -g chain
                              jump to chain with no return
  --match	-m match
				extended match (may load extension)
  --numeric	-n		numeric output of addresses and ports
[!] --out-interface -o output name[+]
				network interface name ([+] for wildcard)
  --table	-t table	table to manipulate (default: `filter')
  --verbose	-v		verbose mode
  --wait	-w [seconds]	maximum wait to acquire xtables lock before give up
  --wait-interval -W [usecs]	wait time to try to acquire xtables lock
				default is 1 second
  --line-numbers		print line numbers when listing
  --exact	-x		expand numbers (display exact values)
[!] --fragment	-f		match second or further fragments only
  --modprobe=<command>		try to insert modules using this command
  --set-counters PKTS BYTES	set the counter during insert/append
[!] --version	-V		print package version.
```

命令选项输入顺序
```sh
iptables -t 表名 <-A/I/D/R> 规则链名 [规则号] <-i/o 网卡名> -p 协议名 <-s 源IP/源子网> --sport \
    源端口 <-d 目标IP/目标子网> --dport 目标端口 -j 动作
```

工作机制
规则链名包括(也被称为五个钩子函数（hook functions）)：

- INPUT链 ：处理输入数据包。
- OUTPUT链 ：处理输出数据包。
- FORWARD链 ：处理转发数据包。
- PREROUTING链 ：用于目标地址转换（DNAT）。
- POSTOUTING链 ：用于源地址转换（SNAT）。


防火墙的策略

防火墙策略一般分为两种，一种叫通策略，一种叫堵策略，通策略，默认门是关着的，必须要定义谁能进。堵策略则是，大门是洞开的，但是你必须有身份认证，否则不能进。所以我们要定义，让进来的进来，让出去的出去，所以通，是要全通，而堵，则是要选择。当我们定义的策略的时候，要分别定义多条功能，其中：定义数据包中允许或者不允许的策略，filter过滤的功能，而定义地址转换的功能的则是nat选项。为了让这些功能交替工作，我们制定出了“表”这个定义，来定义、区分各种不同的工作功能和处理方式。

我们现在用的比较多个功能有3个：

- 1 filter 定义允许或者不允许的，只能做在3个链上：INPUT ，FORWARD ，OUTPUT
- 2 nat 定义地址转换的，也只能做在3个链上：PREROUTING ，OUTPUT ，POSTROUTING
- 3 mangle功能:修改报文原数据，是5个链都可以做：PREROUTING，INPUT，FORWARD，OUTPUT，POSTROUTING

我们修改报文原数据就是来修改TTL的。能够实现将数据包的元数据拆开，在里面做标记/修改内容的。而防火墙标记，其实就是靠mangle来实现的。

小扩展:

- 对于filter来讲一般只能做在3个链上：INPUT ，FORWARD ，OUTPUT
- 对于nat来讲一般也只能做在3个链上：PREROUTING ，OUTPUT ，POSTROUTING
- 而mangle则是5个链都可以做：PREROUTING，INPUT，FORWARD，OUTPUT，POSTROUTING

iptables/netfilter（这款软件）是工作在用户空间的，它可以让规则进行生效的，本身不是一种服务，而且规则是立即生效的。而我们iptables现在被做成了一个服务，可以进行启动，停止的。启动，则将规则直接生效，停止，则将规则撤销。

iptables还支持自己定义链。但是自己定义的链，必须是跟某种特定的链关联起来的。在一个关卡设定，指定当有数据的时候专门去找某个特定的链来处理，当那个链处理完之后，再返回。接着在特定的链中继续检查。

注意：规则的次序非常关键，谁的规则越严格，应该放的越靠前，而检查规则的时候，是按照从上往下的方式进行检查的。

表名包括：

- raw ：高级功能，如：网址过滤。
- mangle ：数据包修改（QOS），用于实现服务质量。
- nat ：地址转换，用于网关路由器。
- filter ：包过滤，用于防火墙规则。

动作包括：

- ACCEPT ：接收数据包。
- DROP ：丢弃数据包。
- REDIRECT ：重定向、映射、透明代理。
- SNAT ：源地址转换。
- DNAT ：目标地址转换。
- MASQUERADE ：IP伪装（NAT），用于ADSL。
- LOG ：日志记录。
![](/images/network-all/iptables.png)


iptables ui管理工具

我们先安装一个界面UI EasyWall管理工具 (目前支持只debian， 笔者目前是deepin系统)
[https://github.com/jpylypiw/easywall/blob/master/INSTALL.md](https://github.com/jpylypiw/easywall/blob/master/INSTALL.md)

```sh
cd /usr/local
sudo git clone https://github.com/jpylypiw/easywall.git
cd easywall
sudo chmod +x install.sh
sudo bash install.sh
```

安装成功后log
```sh
(2/9) Creating configuration

(3/9) Making all scripts executable

(4/9) Setting up EasyWall core systemd process
Do you want to install easywall-core as a Daemon? [y,n]y
installing service ...
Created symlink /etc/systemd/system/multi-user.target.wants/easywall.service → /lib/systemd/system/easywall.service.

(5/9) Installing 3rd Party Products for EasyWall Web
------------------------------
You successfully installed EasyWall on your System!
Wasn't that easy?

So what now?

If you have installed EasyWall as a Daemon you simply have to type:
# systemctl start easywall
or
# service easywall start

If you want to run easywall manually you can enter:
# (sudo) python3 core/easywall.py

If you have any questions on starting EasyWall, just create a new GitHub Issue:
https://github.com/jpylypiw/easywall/issues/new
```

项目是使用flask，我们打开项目的配置。
```sh
[WEB]
username = 
password = 50133c38b13f4f89fea7987cc43aa5bb670ff9be986e754cd028d74f5aef54aa635fc8582a54738118ca901303e82a9e3594d44fa799fd10d0479b5caa30b226
bindip = 127.0.0.1
bindport = 12227
```

iptables使用范例

- 保存规则到配置文件中
```sh
cp /etc/sysconfig/iptables /etc/sysconfig/iptables.bak # 任何改动之前先备份，请保持这一优秀的习惯
iptables-save > /etc/sysconfig/iptables
cat /etc/sysconfig/iptables
```

- 列出已设置的规则
```sh
iptables -L [-t 表名] [链名]
```
    - 四个表名 raw，nat，filter，mangle
    - 五个规则链名 INPUT、OUTPUT、FORWARD、PREROUTING、POSTROUTING
    - filter表包含INPUT、OUTPUT、FORWARD三个规则链

```sh
iptables -L -t nat                  # 列出 nat 上面的所有规则 -t 参数指定，必须是 raw， nat，filter，mangle 中的一个
iptables -L -t nat  --line-numbers  # 规则带编号
iptables -L INPUT
iptables -L -nv                     # 查看，这个列表看起来更详细
```

```sh
double@double:/usr/local/easywall$ sudo iptables -L -nv
Chain INPUT (policy ACCEPT 241K packets, 148M bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain FORWARD (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 DOCKER-USER  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
    0     0 DOCKER-ISOLATION-STAGE-1  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  *      docker0  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
    0     0 DOCKER     all  --  *      docker0  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  docker0 !docker0  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  docker0 docker0  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  *      br-e8b91e143b98  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
    0     0 DOCKER     all  --  *      br-e8b91e143b98  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  br-e8b91e143b98 !br-e8b91e143b98  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  br-e8b91e143b98 br-e8b91e143b98  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  *      br-22b5e305afac  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
    0     0 DOCKER     all  --  *      br-22b5e305afac  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  br-22b5e305afac !br-22b5e305afac  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  br-22b5e305afac br-22b5e305afac  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  *      br-0c91047ea78b  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
    0     0 DOCKER     all  --  *      br-0c91047ea78b  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  br-0c91047ea78b !br-0c91047ea78b  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  br-0c91047ea78b br-0c91047ea78b  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  *      br-fa31ce4c002c  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
    0     0 DOCKER     all  --  *      br-fa31ce4c002c  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  br-fa31ce4c002c !br-fa31ce4c002c  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  br-fa31ce4c002c br-fa31ce4c002c  0.0.0.0/0            0.0.0.0/0           

Chain OUTPUT (policy ACCEPT 255K packets, 64M bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain DOCKER (5 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 ACCEPT     tcp  --  !docker0 docker0  0.0.0.0/0            172.17.0.2           tcp dpt:9000
    0     0 ACCEPT     tcp  --  !docker0 docker0  0.0.0.0/0            172.17.0.3           tcp dpt:27017
    0     0 ACCEPT     tcp  --  !docker0 docker0  0.0.0.0/0            172.17.0.4           tcp dpt:6379

Chain DOCKER-ISOLATION-STAGE-1 (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 DOCKER-ISOLATION-STAGE-2  all  --  docker0 !docker0  0.0.0.0/0            0.0.0.0/0           
    0     0 DOCKER-ISOLATION-STAGE-2  all  --  br-e8b91e143b98 !br-e8b91e143b98  0.0.0.0/0            0.0.0.0/0           
    0     0 DOCKER-ISOLATION-STAGE-2  all  --  br-22b5e305afac !br-22b5e305afac  0.0.0.0/0            0.0.0.0/0           
    0     0 DOCKER-ISOLATION-STAGE-2  all  --  br-0c91047ea78b !br-0c91047ea78b  0.0.0.0/0            0.0.0.0/0           
    0     0 DOCKER-ISOLATION-STAGE-2  all  --  br-fa31ce4c002c !br-fa31ce4c002c  0.0.0.0/0            0.0.0.0/0           
    0     0 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0           

Chain DOCKER-ISOLATION-STAGE-2 (5 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 DROP       all  --  *      docker0  0.0.0.0/0            0.0.0.0/0           
    0     0 DROP       all  --  *      br-e8b91e143b98  0.0.0.0/0            0.0.0.0/0           
    0     0 DROP       all  --  *      br-22b5e305afac  0.0.0.0/0            0.0.0.0/0           
    0     0 DROP       all  --  *      br-0c91047ea78b  0.0.0.0/0            0.0.0.0/0           
    0     0 DROP       all  --  *      br-fa31ce4c002c  0.0.0.0/0            0.0.0.0/0           
    0     0 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0           

Chain DOCKER-USER (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0   
```

- 清空当前的所有规则和计数

```sh
iptables -F  # 清空所有的防火墙规则
iptables -X  # 删除用户自定义的空链
iptables -Z  # 清空计数
```
- 配置允许ssh端口连接
```sh
iptables -A INPUT -s 192.168.1.0/24 -p tcp --dport 22 -j ACCEPT
# 22为你的ssh端口， -s 192.168.1.0/24表示允许这个网段的机器来连接，其它网段的ip地址是登陆不了你的机器的。 -j ACCEPT表示接受这样的请求
```

- 允许本地回环地址可以正常使用
```sh
iptables -A INPUT -i lo -j ACCEPT
#本地圆环地址就是那个127.0.0.1，是本机上使用的,它进与出都设置为允许
iptables -A OUTPUT -o lo -j ACCEPT
```

- 设置默认的规则
```sh
iptables -P INPUT DROP # 配置默认的不让进
iptables -P FORWARD DROP # 默认的不允许转发
iptables -P OUTPUT ACCEPT # 默认的可以出去
```

- 配置白名单
```sh
iptables -A INPUT -p all -s 192.168.1.0/24 -j ACCEPT  # 允许机房内网机器可以访问
iptables -A INPUT -p all -s 192.168.140.0/24 -j ACCEPT  # 允许机房内网机器可以访问
iptables -A INPUT -p tcp -s 183.121.3.7 --dport 3380 -j ACCEPT # 允许183.121.3.7访问本机的3380端口
```

- 开启相应的服务端口
```sh
iptables -A INPUT -p tcp --dport 80 -j ACCEPT # 开启80端口，因为web对外都是这个端口
iptables -A INPUT -p icmp --icmp-type 8 -j ACCEPT # 允许被ping
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT # 已经建立的连接得让它进来
```

- 清除已有规则
```sh
iptables -F INPUT  # 清空指定链 INPUT 上面的所有规则
iptables -X INPUT  # 删除指定的链，这个链必须没有被其它任何规则引用，而且这条上必须没有任何规则。
                   # 如果没有指定链名，则会删除该表中所有非内置的链。
iptables -Z INPUT  # 把指定链，或者表中的所有链上的所有计数器清零。
```

- 删除已添加的规则

添加一条规则
```sh
iptables -A INPUT -s 192.168.1.5 -j DROP
```

将所有iptables以序号标记显示，执行：

```sh
iptables -L -n --line-numbers
```
比如要删除INPUT里序号为8的规则，执行：

```sh
iptables -D INPUT 8
```

- 开放指定的端口
```sh
iptables -A INPUT -s 127.0.0.1 -d 127.0.0.1 -j ACCEPT               #允许本地回环接口(即运行本机访问本机)
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT    #允许已建立的或相关连的通行
iptables -A OUTPUT -j ACCEPT         #允许所有本机向外的访问
iptables -A INPUT -p tcp --dport 22 -j ACCEPT    #允许访问22端口
iptables -A INPUT -p tcp --dport 80 -j ACCEPT    #允许访问80端口
iptables -A INPUT -p tcp --dport 21 -j ACCEPT    #允许ftp服务的21端口
iptables -A INPUT -p tcp --dport 20 -j ACCEPT    #允许FTP服务的20端口
iptables -A INPUT -j reject       #禁止其他未允许的规则访问
iptables -A FORWARD -j REJECT     #禁止其他未允许的规则访问
```

- 屏蔽IP
```sh
iptables -A INPUT -p tcp -m tcp -s 192.168.0.8 -j DROP  # 屏蔽恶意主机（比如，192.168.0.8
iptables -I INPUT -s 123.45.6.7 -j DROP       #屏蔽单个IP的命令
iptables -I INPUT -s 123.0.0.0/8 -j DROP      #封整个段即从123.0.0.1到123.255.255.254的命令
iptables -I INPUT -s 124.45.0.0/16 -j DROP    #封IP段即从123.45.0.1到123.45.255.254的命令
iptables -I INPUT -s 123.45.6.0/24 -j DROP    #封IP段即从123.45.6.1到123.45.6.254的命令是
```

- 指定数据包出去的网络接口
只对 OUTPUT，FORWARD，POSTROUTING 三个链起作用。
```sh
iptables -A FORWARD -o eth0
```

- 查看已添加的规则
```sh
double@double:/usr/local/easywall$ sudo iptables -L -n -v
Chain INPUT (policy ACCEPT 253K packets, 156M bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain FORWARD (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 DOCKER-USER  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
    0     0 DOCKER-ISOLATION-STAGE-1  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  *      docker0  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
    0     0 DOCKER     all  --  *      docker0  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  docker0 !docker0  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  docker0 docker0  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  *      br-e8b91e143b98  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
    0     0 DOCKER     all  --  *      br-e8b91e143b98  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  br-e8b91e143b98 !br-e8b91e143b98  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  br-e8b91e143b98 br-e8b91e143b98  0.0.0.0/0            0.0.0.0/0           
```

- 启动网络转发规则
公网210.14.67.7让内网192.168.188.0/24上网
```sh
iptables -t nat -A POSTROUTING -s 192.168.188.0/24 -j SNAT --to-source 210.14.67.127
```

- 端口映射
本机的 2222 端口映射到内网 虚拟机的22 端口
```sh
iptables -t nat -A PREROUTING -d 210.14.67.127 -p tcp --dport 2222  -j DNAT --to-dest 192.168.188.115:22
```

- 字符串匹配
比如，我们要过滤所有TCP连接中的字符串test，一旦出现它我们就终止这个连接，我们可以这么做：
```sh
iptables -A INPUT -p tcp -m string --algo kmp --string "test" -j REJECT --reject-with tcp-reset
```

- 阻止Windows蠕虫的攻击
```sh
iptables -I INPUT -j DROP -p tcp -s 0.0.0.0/0 -m string --algo kmp --string "cmd.exe"
```

- 防止SYN洪水攻击
```sh
iptables -A INPUT -p tcp --syn -m limit --limit 5/second -j ACCEPT
```


参考链接
[https://baike.baidu.com/item/IP/224599?fr=aladdin](https://baike.baidu.com/item/IP/224599?fr=aladdin)
[https://blog.csdn.net/qq_31759205/article/details/80532439](https://blog.csdn.net/qq_31759205/article/details/80532439)
[https://baike.baidu.com/item/%E5%86%85%E7%BD%91%E7%A9%BF%E9%80%8F/8597835?fr=aladdin](https://baike.baidu.com/item/%E5%86%85%E7%BD%91%E7%A9%BF%E9%80%8F/8597835?fr=aladdin)
[https://www.jianshu.com/p/6af4eb08eac2](https://www.jianshu.com/p/6af4eb08eac2)
[https://zh.wikipedia.org/wiki/%E8%99%9B%E6%93%AC%E7%A7%81%E4%BA%BA%E7%B6%B2%E8%B7%AF](https://zh.wikipedia.org/wiki/%E8%99%9B%E6%93%AC%E7%A7%81%E4%BA%BA%E7%B6%B2%E8%B7%AF)
[https://wangchujiang.com/linux-command/c/iptables.html](https://wangchujiang.com/linux-command/c/iptables.html)
[https://docs.traefik.io/](https://docs.traefik.io/)


