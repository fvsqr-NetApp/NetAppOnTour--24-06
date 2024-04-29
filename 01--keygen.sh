#!/bin/sh
set -x

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
  namespace=retrogames
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
  namespace=retrogames
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
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}

  location /tetris {
    proxy_pass http://ip_tetris:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
EOF

  service nginx restart
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
  nginx_listen=$localport
  #ssh_tunnel $ip $user $remoteport $localport
  
  #deploy_tetris
  #deploy_mines
  proxy
}

do_install
