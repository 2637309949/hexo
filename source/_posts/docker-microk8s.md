---
title: 本地单机安装完善的k8s
date: 2019-08-31 17:17:26
categories: 
- Docker
tags:
	- k8s
	- network
---

在应用开发或者学习k8s时我们会频繁的接触k8s环境，如果在线上操作那么会有那么一些不方便，这里我们使用MicroK8（built by the dedicated Kubernetes team at Canonical ），作为相对完善的本地开发k8s以及学习，MicroK8基本包括了常用的组件（官方貌似说跟踪上游版本，并同步提供应有的插件）

<!-- more -->

## MicroK8介绍

MicroK8-最小，最快，完全一致的Kubernetes，可跟踪上游版本并使聚类变得微不足道。使用MicroK8进行离线开发，原型设计和测试。在VM上使用它作为CI / CD的小型，廉价，可靠的k8s。为IoT制作出色的kubernetes。为k8s开发物联网应用程序并将它们部署到laptop上的MicroK8s上。


## 安装MicroK8 

### Snap介绍
[https://snapcraft.io/docs/getting-started](https://snapcraft.io/docs/getting-started)

A snap is a bundle of your app and its dependencies that works without modification across many different Linux distributions. Snaps are discoverable and installable from the Snap Store, an app store with an audience of millions. (简单的说它是类打包工具，管理执行应用，现在很多系统都推出了应用管理工具，包括版本的管理，让我们更好的管理以及下载对应的工具，不用我们到处找应用bin然后安装再配置环境信息。)

### 安装Snap

```sh
sudo apt update
sudo apt install snapd
```

```sh
snap install hello-world
```

其他的使用可以参考上面的官方链接，snap也提供了很多应用，是个不错的linux工具。


### 安装MicroK8

```
snap install microk8s --classic
# snap install microk8s --edge --classic
```

```sh
double@double:~$ sudo snap info  microk8s
name:      microk8s
summary:   Kubernetes for workstations and appliances
publisher: canonical
contact:   https://github.com/ubuntu/microk8s
description: |
  MicroK8s is a small, fast, secure, single node Kubernetes that installs on
  just about any Linux box. Use it for offline development, prototyping,
  testing, or use it on a VM as a small, cheap, reliable k8s for CI/CD. It's
  also a great k8s for appliances - develop your IoT apps for k8s and deploy
  them to MicroK8s on your boxes.
snap-id: EaXqgt1lyCaxKaQCU349mlodBkDCXRcg
commands:
  - microk8s.config
  - microk8s.ctr
  - microk8s.disable
  - microk8s.enable
  - microk8s.inspect
  - microk8s.istioctl
  - microk8s.kubectl
  - microk8s.linkerd
  - microk8s.reset
  - microk8s.start
  - microk8s.status
  - microk8s.stop
services:
  microk8s.daemon-apiserver:          simple, enabled, inactive
  microk8s.daemon-apiserver-kicker:   simple, enabled, active
  microk8s.daemon-containerd:         simple, enabled, active
  microk8s.daemon-controller-manager: simple, enabled, active
  microk8s.daemon-etcd:               simple, enabled, active
  microk8s.daemon-kubelet:            simple, enabled, active
  microk8s.daemon-proxy:              simple, enabled, active
  microk8s.daemon-scheduler:          simple, enabled, active
tracking:                             stable
installed:                            v1.15.2 (743) 192MB classic
refreshed:                            2019-08-05 20:55:38 +0800 CST
channels:                                                   
  stable:                             v1.15.2         (743) 192MB classic
  candidate:                          v1.15.3         (778) 171MB classic
  beta:                               v1.15.3         (778) 171MB classic
  edge:                               v1.15.3         (804) 171MB classic
  1.10/stable:                        v1.10.13        (546) 222MB classic
  1.10/candidate:                     v1.10.13        (546) 222MB classic
  1.10/beta:                          v1.10.13        (546) 222MB classic
  1.10/edge:                          v1.10.13        (546) 222MB classic
  1.11/stable:                        v1.11.10        (557) 258MB classic
  1.11/candidate:                     v1.11.10        (557) 258MB classic
  1.11/beta:                          v1.11.10        (557) 258MB classic
  1.11/edge:                          v1.11.10        (557) 258MB classic
  1.12/stable:                        v1.12.9         (612) 259MB classic
  1.12/candidate:                     v1.12.9         (612) 259MB classic
  1.12/beta:                          v1.12.9         (612) 259MB classic
  1.12/edge:                          v1.12.9         (612) 259MB classic
  1.13/stable:                        v1.13.6         (581) 237MB classic
```

默认版本是最新的，我们可以对应版本snap refresh --channel=1.11/stable microk8s


## 使用MicroK8

### 启动microk8s
```sh
double@double:~$ microk8s.start
Started.
Enabling pod scheduling
```

### 停止microk8s
```sh
double@double:~$ microk8s.stop
Stopped.
```

### 查看status

```sh
double@double:~$ microk8s.status
microk8s is not running. Use microk8s.inspect for a deeper inspection.
```
```sh
double@double:~$ microk8s.inspect
Inspecting services
  Service snap.microk8s.daemon-containerd is running
  Service snap.microk8s.daemon-apiserver is running
  Service snap.microk8s.daemon-proxy is running
  Service snap.microk8s.daemon-kubelet is running
  Service snap.microk8s.daemon-scheduler is running
  Service snap.microk8s.daemon-controller-manager is running
  Service snap.microk8s.daemon-etcd is running
  Copy service arguments to the final report tarball
Inspecting AppArmor configuration
Gathering system info
  Copy network configuration to the final report tarball
  Copy processes list to the final report tarball
  Copy snap list to the final report tarball
  Inspect kubernetes cluster
```

### 查看k8s集群

```sh
double@double:~$ microk8s.kubectl get nodes
NAME     STATUS   ROLES    AGE     VERSION
double   Ready    <none>   4m14s   v1.15.2
double@double:~$ microk8s.kubectl get service
NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.152.183.1   <none>        443/TCP   4m19s
```

### 开启插件
MicroK8s在Kubernetes上游安装了一个准系统。这意味着只是api-server，controller-manager，scheduler，kubelet，cni，kube-proxy已经安装和运行。其他服务如kube-dns，dashboard可以使用运行microk8s.enable命令开启。

```sh
double@double:~$ microk8s.enable dns dashboard
Enabling DNS
Applying manifest
serviceaccount/coredns created
configmap/coredns created
deployment.apps/coredns created
service/kube-dns created
clusterrole.rbac.authorization.k8s.io/coredns created
clusterrolebinding.rbac.authorization.k8s.io/coredns created
Restarting kubelet
DNS is enabled
Applying manifest
secret/kubernetes-dashboard-certs created
serviceaccount/kubernetes-dashboard created
role.rbac.authorization.k8s.io/kubernetes-dashboard-minimal created
rolebinding.rbac.authorization.k8s.io/kubernetes-dashboard-minimal created
deployment.apps/kubernetes-dashboard created
service/kubernetes-dashboard created
service/monitoring-grafana created
service/monitoring-influxdb created
service/heapster created
deployment.extensions/monitoring-influxdb-grafana-v4 created
serviceaccount/heapster created
clusterrolebinding.rbac.authorization.k8s.io/heapster created
configmap/heapster-config created
configmap/eventer-config created
deployment.extensions/heapster-v1.5.2 created

If RBAC is not enabled access the dashboard using the default token retrieved with:

token=$(microk8s.kubectl -n kube-system get secret | grep default-token | cut -d " " -f1)
microk8s.kubectl -n kube-system describe secret $token

In an RBAC enabled setup (microk8s.enable RBAC) you need to create a user with restricted
permissions as shown in https://github.com/kubernetes/dashboard/wiki/Creating-sample-user
```

查看dashboard状态
```sh
double@double:~$ microk8s.status
microk8s is running
addons:
knative: disabled
jaeger: disabled
fluentd: disabled
gpu: disabled
storage: disabled
registry: disabled
rbac: disabled
ingress: disabled
dns: enabled
metrics-server: disabled
linkerd: disabled
prometheus: disabled
istio: disabled
dashboard: enabled
```

查看secret

```sh
double@double:~$ microk8s.kubectl -n kube-system get secret
NAME                               TYPE                                  DATA   AGE
coredns-token-7n2bw                kubernetes.io/service-account-token   3      9m1s
default-token-l5dff                kubernetes.io/service-account-token   3      16m
heapster-token-t724g               kubernetes.io/service-account-token   3      8m55s
kubernetes-dashboard-certs         Opaque                                0      8m55s
kubernetes-dashboard-token-zs4cm   kubernetes.io/service-account-token   3      8m55s
double@double:~$ microk8s.kubectl -n kube-system describe secret kubernetes-dashboard-token-zs4cm
Name:         kubernetes-dashboard-token-zs4cm
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: kubernetes-dashboard
              kubernetes.io/service-account.uid: 661b8cb4-92ce-4bc5-94d4-b751cc7572ee

Type:  kubernetes.io/service-account-token

Data
====
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZC10b2tlbi16czRjbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjY2MWI4Y2I0LTkyY2UtNGJjNS05NGQ0LWI3NTFjYzc1NzJlZSIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlLXN5c3RlbTprdWJlcm5ldGVzLWRhc2hib2FyZCJ9.mrgVXC1Sso4AbVUmDywoA1ywVYk9j0HzQ2et5pvqbj0wiYC8qAe5nurSPa-hOvLILHfBEbhWPiT3cEyFaPESuOAgOyAzfwumtU1xVEEHwhYZ76qvaGTkdnUceGjG7PpaMaeSqTkkq3v9xRJ7EbTDi4Xfn0JgafbIu7q0zT8QzaZboCBVLgNWRTOU_XXHNug0Dbf5h_P2E0zO4u-LVC-YjWJ76jxqYnv9nx5YAumv4kvQCsb5l_HWhSdLRNRMHxE9hY0FRckIKY5SMOSpIpKo_57b0umkQw8Sd2AZjHJEGcAgMw-2AOe46O__ZexEUPa5bCKcdrl6eq0FE0-wnBqCow
ca.crt:     1099 bytes
```

### Proxy
由于k8s网络接口不在本机同一个网络，我们proxy一下，其实也就是nat
```sh
microk8s.kubectl proxy --accept-hosts=.* --address=0.0.0.0 &
```

打开网址，用我们上面的kubernetes-dashboard-token登录
http://127.0.0.1:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

可以看到效果
![](/images/microk8s/dashboard.png)

公司里用的rancher，体验比k8s官方提供的相对好用些。。。

尝试使用rancher管理microk8s

导出microk8s配置
```sh
microk8s.kubectl config view --raw > $HOME/.microk8s/config
```

本地安装rancher
```sh
sudo docker run -d --restart=unless-stopped -v /home/double/docker/data/srv/volume/rancher:/var/lib/rancher/ -p 8888:80 -p 3043:443 rancher/rancher:stable
```

界面点击通过import方式创建集群，接着
记得要本地IP去apply yml，不然会出现下面的问题（qaq，这个问题在stackover找了半天，最后自已查出来的，emm..,这就是用就rancher ui的后果，很多细节都忘了）
```sh
double@double:~/docker/data/srv/volume/rancher$ microk8s.kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user admin
double@double:~/docker/data/srv/volume/rancher$ microk8s.kubectl apply -f https://192.168.43.137:3043/v3/import/pqwt69qtmplvlqw9qfsctxpvvtgx9zvt5ht6cxhmtph64p5gxfljf8.yaml
Unable to connect to the server: x509: certificate signed by unknown authority
double@double:~/docker/data/srv/volume/rancher$ curl --insecure -sfL https://192.168.43.137:3043/v3/import/pqwt69qtmplvlqw9qfsctxpvvtgx9zvt5ht6cxhmtph64p5gxfljf8.yaml | microk8s.kubectl apply -f -
clusterrole.rbac.authorization.k8s.io/proxy-clusterrole-kubeapiserver created
clusterrolebinding.rbac.authorization.k8s.io/proxy-role-binding-kubernetes-master created
namespace/cattle-system created
serviceaccount/cattle created
clusterrolebinding.rbac.authorization.k8s.io/cattle-admin-binding created
secret/cattle-credentials-e628770 created
clusterrole.rbac.authorization.k8s.io/cattle-admin created
deployment.extensions/cattle-cluster-agent created
The DaemonSet "cattle-node-agent" is invalid: spec.template.spec.containers[0].securityContext.privileged: Forbidden: disallowed by cluster policy
```

看到报错Forbidden: disallowed by cluster policy

解决方式
Add --allow-privileged=true to:

kubelet config
```sh
# 注意：在1.15之后的kubelet已经去掉--allow-privileged，https://github.com/ubuntu/microk8s/issues/583
sudo vim /var/snap/microk8s/current/args/kubelet
```

kube-apiserver config
```sh
sudo vim /var/snap/microk8s/current/args/kube-apiserver
```
Restart services:
```sh
sudo systemctl restart snap.microk8s.daemon-kubelet.service
sudo systemctl restart snap.microk8s.daemon-apiserver.service
```

查看pod
```sh
double@double:~$ microk8s.kubectl get pods --all-namespaces
NAMESPACE            NAME                                              READY   STATUS             RESTARTS   AGE
cattle-system        cattle-cluster-agent-54d5bd5bb6-kgj8d             0/1     CrashLoopBackOff   20         10h
cattle-system        cattle-node-agent-zvzrx                           1/1     Running            0          9h
container-registry   registry-6c99589dc-2bzvh                          1/1     Running            4          14h
kube-system          coredns-f7867546d-skmmz                           1/1     Running            3          13h
kube-system          heapster-v1.5.2-844b564688-g7554                  4/4     Running            6          13h
kube-system          hostpath-provisioner-65cfd8595b-hjmc6             1/1     Running            3          14h
kube-system          kubernetes-dashboard-7d75c474bb-p5rqn             1/1     Running            3          13h
kube-system          monitoring-influxdb-grafana-v4-6b6954958c-ssc98   2/2     Running            6          13h
```

还是没启动，通过describe查看
```sh
double@double:~$ microk8s.kubectl describe pod cattle-cluster-agent-54d5bd5bb6-kgj8d -n cattle-system
Name:           cattle-cluster-agent-54d5bd5bb6-kgj8d
Namespace:      cattle-system
...
...
Events:
  Type     Reason          Age                     From             Message
  ----     ------          ----                    ----             -------
  Warning  BackOff         9h (x85 over 10h)       kubelet, double  Back-off restarting failed container
  Warning  FailedMount     19m                     kubelet, double  MountVolume.SetUp failed for volume "cattle-credentials" : couldn't propagate object cache: timed out waiting for the condition
  Warning  FailedMount     19m                     kubelet, double  MountVolume.SetUp failed for volume "cattle-token-2w8t9" : couldn't propagate object cache: timed out waiting for the condition
  Normal   SandboxChanged  19m                     kubelet, double  Pod sandbox changed, it will be killed and re-created.
```

问题出在挂载上了，找不出具体原因，在microk8s/issues提交报告。。。

我们继续查找。。。。


最后发现其实是我们在apply这个yml文件时，因为这个yml是从rancher下载下来的，查看里面的CATTLE_SERVER居然是127.0.0.1，这个明显不对（QAQ，不同网段至少指定IP，不然NAT不过去），马上改成本机的IP，然后部署

![](/images/microk8s/dashbord.png)

![](/images/microk8s/rancher.png)




### 移除MicroK8s
```sh
microk8s.reset
snap remove microk8s
```

### 插件列表

- dns: Deploy CoreDNS. This add-on may be required by others thus we recommend you always enable it. In environments where the external dns servers 8.8.8.8 and 8.8.4.4 are blocked you will need to update the upstream dns servers in microk8s.kubectl -n kube-system edit configmap/coredns after enabling the add-on.

- dashboard: Deploy Kubernetes dashboard as well as Grafana and InfluxDB. To access Grafana point your browser to the url reported by microk8s.kubectl cluster-info. Access the dashboard with the default token found with microk8s.kubectl -n kube-system get secret and microk8s.kubectl -n kube-system describe secret default-token-{xxxx}.

- storage: Create a default storage class. This storage class makes use of the hostpath-provisioner pointing to a directory on the host. Persistent volumes are created under ${SNAP_COMMON}/default-storage. Upon disabling this add-on you will be asked if you want to delete the persistent volumes created.

- ingress: Create an ingress controller.

- gpu: Expose GPU(s) to MicroK8s by enabling the nvidia runtime and nvidia-device-plugin-daemonset. Requires NVIDIA drivers to be already installed on the host system.

- istio: Deploy the core Istio services. You can use the microk8s.istioctl command to manage your deployments.

- registry: Deploy a private image registry and expose it on localhost:32000. The storage add-on will be enabled as part of this add-on. See the registry documentation for more details.

- metrics-server: Deploy the Metrics Server.

- prometheus: Deploy the Prometheus Operator v0.25.

- fluentd: Deploy the Elasticsearch-Kibana-Fluentd logging and monitoring solution.

- jaeger: Deploy the Jaeger Operator v1.8.2 in the “simplest” configuration.

- linkerd: Deploy linkerd2 Linkerd service mesh. By default proxy auto inject is not enabled. To enable auto proxy injection, simply use microk8s.enable linkerd:proxy-auto-inject. If you need to pass more arguments, separate them with ; and enclose the addons plus arguments with double quotes. For example: microk8s.enable "linkerd:proxy-auto-inject;tls=optional;skip-outbound-ports=1234,3456". Use microk8s.linkerd command to interact with Linkerd.

- rbac: Enable RBAC (Role-Based Access Control) authorisation mode. Note that other add-ons may not work with RBAC enabled.

- knative: Enable Knative with microk8s.enable knative.

- helm: Enable helm with microk8s.enable helm.

- cilium: use network policies by enabling the Cilium network plugin with microk8s.enable cilium.

### 问题诊断

pod没有启动
1. ContainerCreating
```sh
double@double:~$ microk8s.kubectl get pods --all-namespaces
NAMESPACE     NAME                                              READY   STATUS              RESTARTS   AGE
kube-system   coredns-f7867546d-dsdnc                           0/1     ContainerCreating   0          20m
kube-system   heapster-v1.5.2-6b794f77c8-7vm8h                  0/4     ContainerCreating   0          20m
kube-system   kubernetes-dashboard-7d75c474bb-frp44             0/1     ContainerCreating   0          20m
kube-system   monitoring-influxdb-grafana-v4-6b6954958c-hb6b4   0/2     ContainerCreating   0          20m
```
用describe看看情况
```sh
double@double:~$ microk8s.kubectl describe pod --all-namespaces
Name:                 coredns-f7867546d-dsdnc
...
...
Events:
  Type     Reason                  Age                   From               Message
  ----     ------                  ----                  ----               -------
  Normal   Scheduled               22m                   default-scheduler  Successfully assigned kube-system/coredns-f7867546d-dsdnc to double
  Warning  FailedCreatePodSandBox  21m                   kubelet, double    Failed create pod sandbox: rpc error: code = Unknown desc = failed to get sandbox image "k8s.gcr.io/pause:3.1": failed to pull image "k8s.gcr.io/pause:3.1": failed to resolve image "k8s.gcr.io/pause:3.1": no available registry endpoint: failed to do request: Head https://k8s.gcr.io/v2/pause/manifests/3.1: dial tcp [2404:6800:4008:c00::52]:443: i/o timeout
  Warning  FailedCreatePodSandBox  17m (x5 over 20m)     kubelet, double    Failed create pod sandbox: rpc error: code = Unknown desc = failed to get sandbox image "k8s.gcr.io/pause:3.1": failed to pull image "k8s.gcr.io/pause:3.1": failed to resolve image "k8s.gcr.io/pause:3.1": no available registry endpoint: failed to do request: Head https://k8s.gcr.io/v2/pause/manifests/3.1: dial tcp [2404:6800:4008:c00::52]:443: i/o timeout
  Warning  FailedCreatePodSandBox  14m (x5 over 16m)     kubelet, double    Failed create pod sandbox: rpc error: code = Unknown desc = failed to get sandbox image "k8s.gcr.io/pause:3.1": failed to pull image "k8s.gcr.io/pause:3.1": failed to resolve image "k8s.gcr.io/pause:3.1": no available registry endpoint: failed to do request: Head https://k8s.gcr.io/v2/pause/manifests/3.1: dial tcp [2404:6800:4008:c01::52]:443: i/o timeout
  Warning  FailedCreatePodSandBox  12m (x2 over 13m)     kubelet, double    Failed create pod sandbox: rpc error: code = Unknown desc = failed to get sandbox image "k8s.gcr.io/pause:3.1": failed to pull image "k8s.gcr.io/pause:3.1": failed to resolve image "k8s.gcr.io/pause:3.1": no available registry endpoint: failed to do request: Head https://k8s.gcr.io/v2/pause/manifests/3.1: dial tcp [2404:6800:4008:c01::52]:443: i/o timeout
  Warning  FailedCreatePodSandBox  3m50s (x12 over 11m)  kubelet, double    Failed create pod sandbox: rpc error: code = Unknown desc = failed to get sandbox image "k8s.gcr.io/pause:3.1": failed to pull image "k8s.gcr.io/pause:3.1": failed to resolve image "k8s.gcr.io/pause:3.1": no available registry endpoint: failed to do request: Head https://k8s.gcr.io/v2/pause/manifests/3.1: dial tcp [2404:6800:4008:c00::52]:443: i/o timeout
  Warning  FailedCreatePodSandBox  15s (x4 over 2m20s)   kubelet, double    Failed create pod sandbox: rpc error: code = Unknown desc = failed to get sandbox image "k8s.gcr.io/pause:3.1": failed to pull image "k8s.gcr.io/pause:3.1": failed to resolve image "k8s.gcr.io/pause:3.1": no available registry endpoint: failed to do request: Head https://k8s.gcr.io/v2/pause/manifests/3.1: dial tcp [2404:6800:4008:c00::52]:443: i/o timeout
```

手动创建该镜像（或者使用mirrorgooglecontainers/pause:3.1）
```sh
docker pull anjia0532/pause:3.1
docker tag anjia0532/pause:3.1 k8s.gcr.io/pause:3.1
docker rmi anjia0532/pause:3.1
```

导入microk8s的docker本地registry（如果是非microk8s的，可以不用，因为microk8s内部用的跟主机的不是同一个registry）
```sh
docker save k8s.gcr.io/pause > pause.tar
microk8s.ctr -n k8s.io image import pause.tar 
microk8s.ctr -n k8s.io image ls
```

重新部署Pod
```sh
microk8s.disable dashboard dns
microk8s.enable dashboard dns
```

参考链接
[https://microk8s.io/docs/](https://microk8s.io/docs/)
[https://virtualizationreview.com/articles/2019/01/30/microk8s-part-2-how-to-monitor-and-manage-kubernetes.aspx](https://virtualizationreview.com/articles/2019/01/30/microk8s-part-2-how-to-monitor-and-manage-kubernetes.aspx)


