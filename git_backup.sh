#!/bin/bash

sudo git add .
sudo git status
echo -n "Enter version number: " [Minor Update]
CHANGE_MSG=$(cat .HA_VERSION)
#read CHANGE_MSG
sudo git commit -m "${CHANGE_MSG}"
git push origin master

exit
