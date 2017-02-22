#!/usr/bin/env bash
echo "Building and Deploying Nginx"
sudo docker-compose -f gsp_nginx.yml up -d