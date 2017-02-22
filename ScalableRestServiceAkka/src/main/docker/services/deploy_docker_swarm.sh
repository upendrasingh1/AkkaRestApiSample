#!/usr/bin/env bash
#Run this script from the client machine which has docker-machine installed
echo "Assuming we are logged in client machine and the vms have root credentials enabled
 and passwordless login is possible from client machine to all the participating vms"

echo "Map private IP of the participating vms exported.."
export KV_IP=172.31.15.183;export MASTER_IP=172.31.15.181;export SLAVE_IP1=172.31.15.182; export SLAVE_IP2=172.31.6.170

docker-machine create -d generic --generic-ip-address $KV_IP node-1
docker-machine create -d generic --generic-ip-address $MASTER_IP node-2
docker-machine create -d generic --generic-ip-address $SLAVE_IP1 node-3
docker-machine create -d generic --generic-ip-address $SLAVE_IP2 node-4

echo "Choose node-1 as manager of the docker swarm"
eval $(docker-machine env node-1)
docker swarm init \
    --advertise-addr $(docker-machine ip node-1) \
    --listen-addr $(docker-machine ip node-1):2377
TOKEN=$(docker swarm join-token -q worker)

echo "Choose remaining nodes as workers of the docker swarm and join the swarm"
eval $(docker-machine env node-2)
docker swarm join \
    --token $TOKEN \
    $(docker-machine ip node-1):2377
eval $(docker-machine env node-3)
docker swarm join \
    --token $TOKEN \
    $(docker-machine ip node-1):2377
eval $(docker-machine env node-4)
docker swarm join \
    --token $TOKEN \
    $(docker-machine ip node-1):2377

echo "Docker swarm is ready to host applications and services"

