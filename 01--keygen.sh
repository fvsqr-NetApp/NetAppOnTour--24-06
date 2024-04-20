#! /bin/sh
ssh-keygen -t ecdsa -q -f "$HOME/.ssh/id_ecdsa" -N ""
cat "$HOME/.ssh/id_ecdsa.pub"
