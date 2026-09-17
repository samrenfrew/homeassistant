#!/bin/bash

git add .
git status
CHANGE_MSG=$(cat .HA_VERSION)
git commit -m "${CHANGE_MSG}"
git push origin main

exit
