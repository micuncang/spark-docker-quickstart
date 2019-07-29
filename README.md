## 单宿主机多容器Spark部署

#### 基础知识

* Hadoop + Spark：需要对Hadoop/Spark集群部署有基本了解 [[1](https://hadoop.apache.org/docs/r3.1.2/hadoop-project-dist/hadoop-common/ClusterSetup.html)][[2](http://spark.apache.org/docs/latest/running-on-yarn.html)]
* Docker：需要熟练操作docker/docker-compose，需要理解docker镜像制作、网络模式、端口映射、数据挂载 [[1](https://docs.docker.com/get-started/)]
* DNS: 了解dnsmasq [[1](http://www.thekelleys.org.uk/dnsmasq/doc.html)][[2](https://github.com/jpillora/docker-dnsmasq)][[3](https://docs.docker.com/config/containers/container-networking/)]
* pipework + dhcp：需要理解网桥概念 [[1](https://github.com/jpetazzo/pipework)][[2](http://www.linuxdiyf.com/linux/31622.html)]
* Linux Shell Script：需要Linux Shell Script基础知识 [[1](http://linux.vbird.org/linux_basic/0340bashshell-scripts.php)]

#### 项目方案

> 项目目标是借助单台宿主机模拟多节点Hadoop/Spark集群，集群各节点拥有和宿主机相同网段IP，宿主机网络范围内其他设备可以提交任务至该集群。集群应考虑自由重启和重建。

* 设立网桥
* 容器启动网络模式设置为none
* 自建DNS Server为集群提供IP解析(集群外设备建议采用/etc/hosts方式、DNS Server优先考虑物理机)
* 由pipework + dhcp为所有容器设置动态IP

#### 如何使用

##### 设立网桥

> 以下IP地址、网卡为示例，需要根据实际情况进行调整

* 检查宿主机的IP地址(192.168.1.187/24)、网关(192.168.1.1)、网卡(eth0)
* ip link add dev br0 type bridge
* ip link set br0 up
* ip addr add 192.168.1.187/24 dev br0; \\  
  ip addr del 192.168.1.187/24 dev eth0; \\  
  brctl addif br0 eth0; \\  
  ip route del default; \\  
  ip route add default via 192.168.1.1 dev br0

##### 搭建DNS Server(Dokcer容器版本)

* git clone https://github.com/jpillora/docker-dnsmasq.git
* cd docker-dnsmasq
* docker build -t docker-dnsmasq .
* docker run \\  
  --name dnsmasq \\  
  --network none \\  
  -d \\  
  -v /opt/dnsmasq.conf:/etc/dnsmasq.conf \\  
  --log-opt "max-size=100m" \\  
  -e "HTTP_USER=foo" \\  
  -e "HTTP_PASS=bar" \\  
  --restart always \\  
  docker-dnsmasq
* pipework br0 dnsmasq dhclient
* 获取DNS Server IP地址：docker exec dnsmasq /bin/sh -c "ip route get 8.8.8.8" | awk '{print $7}'
* 访问：http://{DNS Server IP}:8080，账号/密码：foo/bar

##### 克隆项目到本地 

* git clone git@github.com:micuncang/spark-docker-quickstart.git 
* cd spark-docker-quickstart
* git remote remove origin

##### 构建Docker镜像

* cd image/
* wget https://downloads.lightbend.com/scala/2.13.0/scala-2.13.0.rpm
* docker build -t centos:spark-version .
* cd -

##### 初始化

* sh init.sh hadoop_tar_gz_path spark_tgz_path  docker_image local_base_dir dns_server

##### 集群重启与重建

> 利用本方式启动的容器最大程度模拟了物理机，理论上除不可抗拒因素外，应尽量避免集群重启。一般调整可直接进入容器内进行。

* TODO：当前容器采用none网络模式，容器重启后动态分配的IP会自动消失
