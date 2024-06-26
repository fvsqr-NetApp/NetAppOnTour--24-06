#!/bin/sh

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

ssh_tunnel_ssh() {
  ip=$1
  user=$2
  remoteport=2242
  localport=22
  
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

ssh_tunnel_vnc() {
  ip=$1
  user=$2
  remoteport=5900
  localport=5900

  apt-get -y remove vino
  apt-get -y install x11vnc
  mkdir /etc/x11vnc
  x11vnc --storepasswd /etc/x11vnc/vncpwd

   cat << EOF > /lib/systemd/system/x11vnc.service
[Unit]
Description=Start x11vnc at startup.
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -auth guess -forever -noxdamage -repeat -rfbauth /etc/x11vnc/vncpwd -rfbport 5900 -shared

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable x11vnc.service
  systemctl start x11vnc.service
  
  
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

  ssh_tunnel_ssh $ip $user
  ssh_tunnel_vnc $ip $user
}

do_install
