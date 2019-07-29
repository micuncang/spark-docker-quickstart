FROM centos

WORKDIR /root

LABEL maintainer=micuncang@gmail.com

COPY scala-2.13.0.rpm /tmp/ 
RUN yum -y install /tmp/scala-2.13.0.rpm && \
    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup && \
    curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.163.com/.help/CentOS7-Base-163.repo && \
    yum clean all && yum makecache && \
    yum -y install java openssh.x86_64 openssh-clients openssh-server.x86_64 net-tools.x86_64 which vim less telnet sudo initscripts wget bzip2 lsof && \
    wget https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    sh ~/Miniconda3-latest-Linux-x86_64.sh -b

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["/bin/bash"]
