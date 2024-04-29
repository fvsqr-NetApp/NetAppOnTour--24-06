#!/bin/sh
set -x

ssh_key() {
  ssh-keygen -t ecdsa -q -f "$HOME/.ssh/id_ecdsa" -N "" > /dev/null
  
  
  echo
  echo
  echo "  ###############################################################"
  echo "  # Copy the output to the clipboard and open a ssh session     #"
  echo "  # from your local machine to the 'SSH Proxy Server. Open file #"
  echo "  # ~/.ssh/authorized_keys                                      #"
  echo "  # and append a line with the content from the clipboard.      #"
  echo "  ###############################################################"
  echo
  cat "$HOME/.ssh/id_ecdsa.pub"
  echo
  echo
}

ssh_tunnel() {
  ip=$1
  user=$2
  remoteport=$3
  localport=$4
  
  nohup bash -c "ssh -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes -o ConnectTimeout=3 -o TCPKeepAlive=yes -o ServerAliveInterval=5 -o ServerAliveCountMax=5 -N -R $remoteport:localhost:$localport $user@$ip" >/dev/null 2>&1 &

  sleep 4
  lsof -i:ssh | grep $ip

  established=$(lsof -i:ssh | awk -v p="$ip" '$0 ~ p')

  if [ -z "$established" ]
  then
      echo "SSH Connection not established. Installation aborted!"
      exit 1
  fi
}

deploy_tetris() {
  export KUBECONFIG=/home/user/kubeconfigs/rke1/kube_config_cluster.yml
  echo $KUBECONFIG
  namespace=retrogames
  kubectl get nodes
  kubectl create ns $namespace

  cd /tmp
  git clone https://github.com/fvsqr-NetApp/tetris-gamev2.git tetris 2> /dev/null
  kubectl apply -f tetris/k8s -n $namespace

  kubectl rollout status deployment tetris -n $namespace
}

do_install() {
  #ssh_key
  #read -p "Ready to continue? (Y/N): " confirm < /dev/tty
  #if [ "$confirm" != "${confirm#[Yy]}" ] ;then 
  #  echo "ok, let's start the installation..."
  #else
  #  echo "Installation aborted"
  #  exit 1
  #fi
  #echo
  #read -p "IP of the SSH Proxy Server: " ip < /dev/tty
  #read -p "user name of the SSH Proxy Server: " user < /dev/tty
  #read -p "Remote port to use: " remoteport < /dev/tty
  #read -p "Local port to use: " localport < /dev/tty
  
  #ssh_tunnel $ip $user $remoteport $localport
  
  deploy_tetris
}

do_install
