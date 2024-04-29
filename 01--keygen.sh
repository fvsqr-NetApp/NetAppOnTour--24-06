#! /bin/sh
set -x

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
apt update && apt install -Y confirm 
read -p "Ready to continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
echo
read -p "IP of the SSH Proxy Server: " ip
read -p "user name of the SSH Proxy Server: " user

bash -c "ssh -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes -o ConnectTimeout=3 -o TCPKeepAlive=yes -o ServerAliveInterval=5 -o ServerAliveCountMax=5 -N -R 8000:localhost:8000 $user@$ip" &> /dev/null & disown;
lsof -i tcp:8000
