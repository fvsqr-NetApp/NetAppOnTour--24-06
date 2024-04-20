#! /bin/sh
ssh-keygen -t ecdsa -q -f "$HOME/.ssh/id_ecdsa" -N ""


echo .
echo .
echo "  ###############################################################"
echo "  # Copy the output to the clipboard and open a ssh session     #"
echo "  # from your local machine to the 'SSH Proxy Server. Open file #"
echo "  # ~/.ssh/authorized_keys                                      #"
echo "  # and append a line with the content from the clipboard.      #"
echo "  ###############################################################"
echo .
cat "$HOME/.ssh/id_ecdsa.pub"
echo .
echo .
echo "Press any key, when done..."
read -r -n 1
