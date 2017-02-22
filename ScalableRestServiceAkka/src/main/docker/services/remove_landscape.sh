#!/usr/bin/env bash
sudo docker-compose -f gsp_nginx.yml down
sudo docker-compose -f gsp_platform.yml down
sudo docker-compose -f gsp_zookeeper.yml down

