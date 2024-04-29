#!/bin/sh
set -x

do_install() {
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
  read -p "Ready to continue? (Y/N): " confirm
  if [ "$confirm" != "${confirm#[Yy]}" ] ;then 
    exit 1
  fi
  echo
  read -p "IP of the SSH Proxy Server: " ip
  read -p "user name of the SSH Proxy Server: " user
  
  nohup bash -c "ssh -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes -o ConnectTimeout=3 -o TCPKeepAlive=yes -o ServerAliveInterval=5 -o ServerAliveCountMax=5 -N -R 8000:localhost:8000 $user@$ip" >/dev/null 2>&1 &;

  lsof -i tcp:8000
}

do_install
