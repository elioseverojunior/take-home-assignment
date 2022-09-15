#!/bin/sh

# Init Container Script
date -u '+%Y-%m-%d_%H:%M:%S'

cat /app/server.config
cat /app/init.sql
cat /app/init.sh

secs=30;
while [ $secs -gt 0 ]; do
  echo -ne "Waiting for $secs\033[0K\r"
  sleep 1
  : $((secs--))
done
