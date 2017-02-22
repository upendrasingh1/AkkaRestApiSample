#!/usr/bin/env bash
echo "Building and Deploying Zookeeper"
sudo docker-compose -f gsp_zookeeper.yml up -d