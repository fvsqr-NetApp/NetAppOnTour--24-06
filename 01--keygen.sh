#! /bin/bash

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
echo "Press any key, when done..."
bash -c "read -r -n 1"
echo
echo "What's the IP of the SSH Proxy Server?"
read -r ip
echo $ip

echo "What's the user name of the SSH Proxy Server?"
read -r user
echo $user

bash -c "ssh -o ExitOnForwardFailure=yes -o ConnectTimeout=3 -o TCPKeepAlive=yes -o ServerAliveInterval=5 -o ServerAliveCountMax=5 -N -R 8000:localhost:8000 $user@$ip" &> /dev/null & disown;
netstat -anp | grep LISTEN | grep 8000
