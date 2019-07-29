#!/bin/bash

if [ ! -e ~/ok ]; then
  echo "export JAVA_HOME=/usr/lib/jvm/jre"  >> ~/.bashrc
  echo "export PATH=$PATH:$JAVA_HOME/bin"   >> ~/.bashrc
  echo "export PATH=/root/miniconda3/bin:$PATH"   >> ~/.bashrc
  
  ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ''
  cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  echo "Host *" > ~/.ssh/config
  echo " StrictHostKeyChecking no" >> ~/.ssh/config
  
  rm -f /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ed25519_key
  ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -P ''
  ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -P ''
  ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -P ''

  touch ~/ok
fi

/usr/sbin/sshd

exec "$@"
