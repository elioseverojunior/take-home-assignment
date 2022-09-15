#!/bin/sh

# PreStop Script for Graceful Shooting Down
echo "Stopping container now..." && kill -n SIGINT 1 > /proc/1/fd/1
