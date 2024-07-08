#!/bin/bash
sudo apt-get update -y  &>/dev/null && echo "updated"

# install SSH Server
sudo apt install openssh-server -y &>/dev/null && echo "ssh Server OK"

# install SSH Client
sudo apt-get install openssh-client -y &>/dev/null && echo "ssh Client OK" 

# Start and enable ssh service 
sudo systemctl start ssh
sudo systemctl enable ssh

echo "Enjoy SSH Service" 
