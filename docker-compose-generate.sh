HADOOP_TAR_GZ_PATH=$1
SPARK_TGZ_PATH=$2
DOCKER_IMAGE=$3

LOCAL_BASE_DIR=$4

SLAVE_SIZE=$5

MASTER_CONTAINER_NAME=$6
SLAVE_CONTAINER_NAME_PREFIX=$7

DNS_SERVER=$8

function init() {
  echo "Hadoop&Spark package prepare......"
  mkdir -p ${LOCAL_BASE_DIR}
  cd ${LOCAL_BASE_DIR}
  mkdir -p hadoop/master/data/hadoop/tmp/dir hadoop/master/sys/fs/cgroup
  mkdir -p spark/master
  tar zxvf ${HADOOP_TAR_GZ_PATH} -C hadoop/master > /dev/null 2>&1
  tar zxvf ${SPARK_TGZ_PATH} -C spark/master > /dev/null 2>&1
  for((init_slave=1;init_slave<=${SLAVE_SIZE};++init_slave)); do
    prefix=slave${init_slave}
    mkdir -p hadoop/${prefix}/data/hadoop/tmp/dir hadoop/${prefix}/sys/fs/cgroup
    mkdir -p spark/${prefix}
    tar zxvf ${HADOOP_TAR_GZ_PATH} -C hadoop/${prefix} > /dev/null 2>&1
    tar zxvf ${SPARK_TGZ_PATH} -C spark/${prefix} > /dev/null 2>&1
  done
}
init

function docker_compose_header() {
  echo "version: '3'"
}

function docker_compose_services_master() {
  echo "services:"
  echo "  $MASTER_CONTAINER_NAME:"
  echo "    image: \"${DOCKER_IMAGE}\""
  echo "    container_name: \"$MASTER_CONTAINER_NAME\""
  echo "    environment:" 
  echo "      - \"container=docker\"" 
  echo "    volumes:" 
  echo "      - \"${LOCAL_BASE_DIR}/hadoop/master:/usr/share/hadoop\"" 
  echo "      - \"${LOCAL_BASE_DIR}/hadoop/master/sys/fs/cgroup:/sys/fs/cgroup\"" 
  echo "      - \"${LOCAL_BASE_DIR}/spark/master:/usr/share/spark\"" 
  echo "    network_mode: \"none\""
  echo "    dns:"
  echo "      - $DNS_SERVER"
  #echo "    ports:" 
  #echo "      - \"50070:50070\"" 
  #echo "      - \"8088:8088\"" 
  #echo "      - \"19888:19888\"" 
  #echo "      - \"9000:9000\"" 
  #echo "      - \"8030:8030\"" 
  #echo "      - \"8031:8031\"" 
  #echo "      - \"8032:8032\"" 
  #echo "      - \"8033:8033\"" 
  #echo "      - \"8042:8042\"" 
  #echo "      - \"8180:8080\"" 
  #echo "      - \"7177:7077\"" 
  echo "    tty: true"
}

function docker_compose_services_slave() {
  echo "  $SLAVE_CONTAINER_NAME_PREFIX${1}:"
  echo "    image: \"${DOCKER_IMAGE}\""
  echo "    container_name: \"$SLAVE_CONTAINER_NAME_PREFIX${1}\""
  echo "    environment:" 
  echo "      - \"container=docker\"" 
  echo "    volumes:" 
  echo "      - \"${LOCAL_BASE_DIR}/hadoop/slave${1}:/usr/share/hadoop\"" 
  echo "      - \"${LOCAL_BASE_DIR}/hadoop/slave${1}/sys/fs/cgroup:/sys/fs/cgroup\"" 
  echo "      - \"${LOCAL_BASE_DIR}/spark/slave${1}:/usr/share/spark\"" 
  echo "    network_mode: \"none\""
  echo "    dns:"
  echo "      - $DNS_SERVER"
  echo "    tty: true"
}

cd ${LOCAL_BASE_DIR}
if [ -e docker-compose.yml ]; then
  rm -i docker-compose.yml 
fi

echo "Docker compose file generate......"
docker_compose_header                                     >> docker-compose.yml
docker_compose_services_master                            >> docker-compose.yml
for ((j=0;j<${SLAVE_SIZE};j++)); do
  let slave_index=$j+1
  docker_compose_services_slave ${slave_index}            >> docker-compose.yml
done
