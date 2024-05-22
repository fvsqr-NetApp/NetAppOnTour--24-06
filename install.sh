#!/bin/sh

namespace=retrogames

nginx_listen=8000
ip_mines=""
ip_tetris=""

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
  
  kubectl get nodes
  kubectl create ns $namespace > /dev/null

  cd /tmp
  git clone https://github.com/fvsqr-NetApp/tetris-gamev2.git tetris 2> /dev/null
  cd tetris && git pull
  kubectl apply -f k8s -n $namespace

  kubectl rollout status deployment tetris -n $namespace

  ip=$(kubectl get services --namespace $namespace nginx --output jsonpath='{.status.loadBalancer.ingress[0].ip}')

  echo $ip

  ip_tetris=$ip
}

deploy_mines() {
  export KUBECONFIG=/home/user/kubeconfigs/rke1/kube_config_cluster.yml
  echo $KUBECONFIG

  kubectl get nodes
  kubectl create ns $namespace > /dev/null

  cd /tmp
  git clone https://github.com/fvsqr-NetApp/mines.git mines 2> /dev/null
  cd mines && git pull
  kubectl apply -f k8s -n $namespace

  kubectl rollout status deployment mines -n $namespace

  ip=$(kubectl get services --namespace $namespace mines --output jsonpath='{.status.loadBalancer.ingress[0].ip}')

  echo $ip

  ip_mines=$ip
}

proxy() {
  apt update && apt install -y nginx
  echo "Tetris: $ip_tetris"
  echo "Mines: $ip_mines"
  echo "Nginx: $nginx_listen"

  cat << EOF > /etc/nginx/conf.d/retrogames.conf
server {
  listen       $nginx_listen;

  location / {
    proxy_pass http://$ip_mines:3300;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
  }

  location /tetris {
    proxy_pass http://$ip_tetris:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
  }

  location /react-tetris {
    proxy_pass http://$ip_tetris:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
  }

  location /quotes {
    proxy_pass http://$ip_tetris:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
  }

  location /sockjs-node {
    proxy_pass http://$ip_tetris:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
EOF

  service nginx restart
}

copy_quotes() {
  apt update && apt install -y nfs-common
  mkdir -p /mnt/testdir

  export KUBECONFIG=/home/user/kubeconfigs/rke1/kube_config_cluster.yml
 
  volume_name=$(kubectl get pvc -n $namespace | awk '{ print $3 }' | grep pvc | tr - _)

  echo "Trident volume name for apps: $volume_name" 
 
  mount -t nfs 192.168.0.131:/trident_$volume_name /mnt/testdir
 
  cp -p /tmp/tetris/quotes/texts/* /mnt/testdir
}

enable_arp_on_vol() {
  export KUBECONFIG=/home/user/kubeconfigs/rke1/kube_config_cluster.yml
 
  volume_name=$(kubectl get pvc -n $namespace | awk '{ print $3 }' | grep pvc | tr - _)
  
  ssh -t cluster1 "vol modify -volume trident_$volume_name -anti-ransomware-state enabled"
}

do_install() {
  ssh_key
  read -p "Ready to continue? (Y/N): " confirm < /dev/tty
  if [ "$confirm" != "${confirm#[Yy]}" ] ;then 
    echo "ok, let's start the installation..."
  else
    echo "Installation aborted"
    exit 1
  fi
  echo
  read -p "IP of the SSH Proxy Server: " ip < /dev/tty
  read -p "user name of the SSH Proxy Server: " user < /dev/tty
  read -p "Remote port to use: " remoteport < /dev/tty
  read -p "Local port to use: " localport < /dev/tty
  nginx_listen=$localport
  ssh_tunnel $ip $user $remoteport $localport
  
  deploy_tetris
  deploy_mines
  proxy
  copy_quotes
  enable_arp_on_vol
}

do_install
