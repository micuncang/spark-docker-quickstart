#!/bin/bash

if [ $# -ne 5 ];
then
    echo "usage : run.sh hadoop_tar_gz_path spark_tgz_path  docker_image local_base_dir dns_server"
    exit 1
fi

dir=`pwd`

HADOOP_TAR_GZ_PATH=$1
SPARK_TGZ_PATH=$2
DOCKER_IMAGE=$3 
LOCAL_BASE_DIR=$4
DNS_SERVER=$5
SLAVE_SIZE=2

MASTER_CONTAINER_NAME=sparkmaster
SLAVE_CONTAINER_NAME_PREFIX=sparkslave

hadoop_version=`echo $HADOOP_TAR_GZ_PATH | xargs basename | awk -F'.tar.gz' '{print $1}'`
spark_version=`echo $SPARK_TGZ_PATH | xargs basename | awk -F'.tgz' '{print $1}'`
echo "Using $hadoop_version"
echo "Using $spark_version"

mkdir -p $LOCAL_BASE_DIR
/bin/bash $dir/docker-compose-generate.sh $HADOOP_TAR_GZ_PATH $SPARK_TGZ_PATH $DOCKER_IMAGE $LOCAL_BASE_DIR  $SLAVE_SIZE $MASTER_CONTAINER_NAME $SLAVE_CONTAINER_NAME_PREFIX $DNS_SERVER 
echo "Docker containers up......"
cd $LOCAL_BASE_DIR
docker-compose up -d
cd - > /dev/null

echo "Hadoop conf prepare......"
cd $dir/hadoop-conf 
mkdir -p conf
echo > conf/slaves
for((slave_index=1;slave_index<$SLAVE_SIZE+1;slave_index++)); do
  echo `docker container inspect -f '{{.Config.Hostname}}' $SLAVE_CONTAINER_NAME_PREFIX$slave_index` >>  conf/slaves
done
for conf_file in core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml; do
  awk '{sub(/docker-hadoop-master/, master_hostname)} {print $0}' master_hostname=`docker container inspect -f '{{.Config.Hostname}}' $MASTER_CONTAINER_NAME` $conf_file.template   > conf/$conf_file
done	
cp conf/* $LOCAL_BASE_DIR/hadoop/master/$hadoop_version/etc/hadoop/
for((slave_index=1;slave_index<$SLAVE_SIZE+1;slave_index++)); do
  cp conf/* $LOCAL_BASE_DIR/hadoop/slave$slave_index/$hadoop_version/etc/hadoop/
done
cd - > /dev/null

echo "Spark conf prepare......"
cd $dir/spark-conf
mkdir -p conf
echo > conf/slaves
for((slave_index=1;slave_index<$SLAVE_SIZE+1;slave_index++)); do
  echo `docker container inspect -f '{{.Config.Hostname}}' $SLAVE_CONTAINER_NAME_PREFIX$slave_index` >>  conf/slaves
done
for conf_file in spark-defaults.conf; do
  awk '{sub(/docker-hadoop-master/, master_hostname)} {print $0}' master_hostname=`docker container inspect -f '{{.Config.Hostname}}' $MASTER_CONTAINER_NAME` $conf_file.template   > conf/$conf_file
done
cp conf/* $LOCAL_BASE_DIR/spark/master/$spark_version/conf/
for((slave_index=1;slave_index<$SLAVE_SIZE+1;slave_index++)); do
  cp conf/* $LOCAL_BASE_DIR/spark/slave$slave_index/$spark_version/conf/
done
cd - > /dev/null

echo "Docker containers ssh&&.bashrc prepare......"
master_id_rsa_pub=`docker exec $MASTER_CONTAINER_NAME cat /root/.ssh/id_rsa.pub`
for((slave_index=1;slave_index<$SLAVE_SIZE+1;slave_index++)); do
  docker exec $SLAVE_CONTAINER_NAME_PREFIX$slave_index bash -c "echo '$master_id_rsa_pub' >> /root/.ssh/authorized_keys"
done
CONTAINER_HADOOP_HOME="/usr/share/hadoop/$hadoop_version"
CONTAINER_SPARK_HOME="/usr/share/spark/$spark_version"
docker exec $MASTER_CONTAINER_NAME bash -c "echo export HADOOP_HOME='$CONTAINER_HADOOP_HOME' >> /root/.bashrc"
docker exec $MASTER_CONTAINER_NAME bash -c "echo export SPARK_HOME='$CONTAINER_SPARK_HOME' >> /root/.bashrc"
docker exec $MASTER_CONTAINER_NAME bash -c "echo export HADOOP_CONF_DIR='$CONTAINER_HADOOP_HOME'/etc/hadoop >> /root/.bashrc"
docker exec $MASTER_CONTAINER_NAME bash -c "echo export PATH='$'PATH:'$'HADOOP_HOME/bin:'$'HADOOP_HOME/sbin >> /root/.bashrc"
for((slave_index=1;slave_index<$SLAVE_SIZE+1;slave_index++)); do
  docker exec $SLAVE_CONTAINER_NAME_PREFIX$slave_index bash -c "echo export HADOOP_HOME='$CONTAINER_HADOOP_HOME' >> /root/.bashrc"
  docker exec $SLAVE_CONTAINER_NAME_PREFIX$slave_index bash -c "echo export SPARK_HOME='$CONTAINER_SPARK_HOME' >> /root/.bashrc"
  docker exec $SLAVE_CONTAINER_NAME_PREFIX$slave_index bash -c "echo export HADOOP_CONF_DIR='$CONTAINER_HADOOP_HOME'/etc/hadoop >> /root/.bashrc"
  docker exec $SLAVE_CONTAINER_NAME_PREFIX$slave_index bash -c "echo export PATH='$'PATH:'$'HADOOP_HOME/bin:'$'HADOOP_HOME/sbin >> /root/.bashrc"
done

echo "Docker containers ip prepare......"
pipework br0 $MASTER_CONTAINER_NAME dhclient 
echo "DNS Server中待添加信息："
echo "  address=/"`docker inspect -f '{{.Config.Hostname}}' $MASTER_CONTAINER_NAME`"/"`docker exec $MASTER_CONTAINER_NAME /bin/sh -c 'ip route get 8.8.8.8' | awk '{print $7}'`
for((slave_index=1;slave_index<$SLAVE_SIZE+1;slave_index++)); do
  pipework br0 $SLAVE_CONTAINER_NAME_PREFIX$slave_index dhclient 
  echo "  address=/"`docker inspect -f '{{.Config.Hostname}}' $SLAVE_CONTAINER_NAME_PREFIX$slave_index`"/"`docker exec $SLAVE_CONTAINER_NAME_PREFIX$slave_index /bin/sh -c 'ip route get 8.8.8.8' | awk '{print $7}'`
done

read -p '初始化集群前请确认DNS Server中已经添加上述信息[Y/N]:' choice
if [ $choice == 'Y' -o $choice == 'y' ]; then
  echo "Hadoop init......"
  docker exec $MASTER_CONTAINER_NAME bash -c "source /root/.bashrc && '$CONTAINER_HADOOP_HOME'/bin/hdfs namenode -format"
  docker exec $MASTER_CONTAINER_NAME bash -c "source /root/.bashrc && sh '$CONTAINER_HADOOP_HOME'/sbin/start-all.sh && sh '$CONTAINER_HADOOP_HOME'/sbin/mr-jobhistory-daemon.sh start historyserver"
  
  echo "Spark init......"
  docker exec $MASTER_CONTAINER_NAME bash -c "source /root/.bashrc && '$CONTAINER_HADOOP_HOME'/bin/hadoop fs -mkdir /spark-jars"
  docker exec $MASTER_CONTAINER_NAME bash -c "source /root/.bashrc && '$CONTAINER_HADOOP_HOME'/bin/hadoop fs -put '$CONTAINER_SPARK_HOME'/jars/*.jar /spark-jars/ && sh '$CONTAINER_SPARK_HOME'/sbin/start-all.sh"
  
  echo 'good job :)'
fi

echo "Done."
