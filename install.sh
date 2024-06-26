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

copy_ads() {
  ads_dir=/mnt/ads

  apt update && apt install -y nfs-common
  
  mkdir -p $ads_dir

  export KUBECONFIG=/home/user/kubeconfigs/rke1/kube_config_cluster.yml
 
  volume_name=$(kubectl get pvc -n $namespace | awk '{ print $3 }' | grep pvc | tr - _)

  echo "Trident volume name for apps: $volume_name" 
 
  mount -t nfs 192.168.0.131:/trident_$volume_name $ads_dir
 
  cp -p /tmp/tetris/quotes/texts/* $ads_dir

  mkdir -p $ads_dir/data
  unzip -o /tmp/tetris/ads_data_0.zip -d $ads_dir/data
  unzip -o /tmp/tetris/ads_data_1.zip -d $ads_dir/data
  unzip -o /tmp/tetris/ads_data_2.zip -d $ads_dir/data
}

enable_arp_on_vol() {
  svm_name=svm1
  
  export KUBECONFIG=/home/user/kubeconfigs/rke1/kube_config_cluster.yml
 
  volume_name=$(kubectl get pvc -n $namespace | awk '{ print $3 }' | grep pvc | tr - _)
  
  ssh -o StrictHostKeyChecking=no -t admin@cluster1.demo.netapp.com "vol modify -volume trident_$volume_name -anti-ransomware-state enabled"
  ssh -o StrictHostKeyChecking=no -t admin@cluster1.demo.netapp.com "security anti-ransomware volume attack-detection-parameters modify -volume trident_$volume_name -vserver $svm_name -never-seen-before-file-extn-count-notify-threshold 1 -high-entropy-data-surge-notify-percentage 10 -file-create-rate-surge-notify-percentage 10 -file-delete-rate-surge-notify-percentage 10 -file-rename-rate-surge-notify-percentage 10"
}

snapshot_initial() {
  snapshot_name=snap.initial
  svm_name=svm1

  export KUBECONFIG=/home/user/kubeconfigs/rke1/kube_config_cluster.yml
 
  volume_name=$(kubectl get pvc -n $namespace | awk '{ print $3 }' | grep pvc | tr - _)
  
  ssh -o StrictHostKeyChecking=no -t admin@cluster1.demo.netapp.com "volume snapshot create -vserver $svm_name -volume trident_$volume_name -snapshot $snapshot_name"
}

pre_encrypt() {
  ads_dir=/mnt/ads

  cd $ads_dir/data;
  while :
  do
        FILES=`find * -maxdepth 3 -type f \(  ! -iname "*.lckd"  ! -iname "*.key" \)`;
        for file in $FILES;
        do
                CWD=`pwd`
                encrypt_filename1=$CWD/$file.processing.lckd
				encrypt_filename2=$CWD/$file.lckd
                printf 'Encrypting:  %s\n' "$file"
				`mv $CWD/$file $encrypt_filename1 2> /dev/null` && `openssl enc -aes-256-cbc -salt -in $encrypt_filename1 -out $encrypt_filename2 -pass pass:AcnlPbOAfAw= 2> /dev/null` && `rm $encrypt_filename1 2> /dev/null`
				if [ -f "$encrypt_filename2" ]; then
                  echo ""
				  sleep 1
				else
                  echo "Encryption failed."
				fi
        done
        break
  done
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
  copy_ads
  enable_arp_on_vol
  snapshot_initial
  pre_encrypt
}

do_install
