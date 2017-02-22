#!/usr/bin/env bash

function wait_for_service()
 if [ $# -ne 1 ]
  then
    echo usage $FUNCNAME "service";
    echo e.g: $FUNCNAME docker-proxy
  else
serviceName=$1

while true; do
    REPLICAS=$(docker service ls | grep -E "(^| )$serviceName( |$)" | awk '{print $3}')
    if [[ $REPLICAS == "1/1" || $REPLICAS == "global" ]]; then
        break
    else
        echo "Waiting for the $serviceName service... ($REPLICAS)"
        sleep 5
    fi
done
fi

echo "Stopping and removing all containers and images from the Configured Docker Swarm"
eval $(docker-machine env node-1)
docker service rm $(docker service ls -q)
docker stop $(docker ps -a -q);docker rm -f $(docker ps -a -q);docker rmi -f $(docker images -q)

eval $(docker-machine env node-2)
docker stop $(docker ps -a -q);docker rm -f $(docker ps -a -q);docker rmi -f $(docker images -q)

eval $(docker-machine env node-3)
docker stop $(docker ps -a -q);docker rm -f $(docker ps -a -q);docker rmi -f $(docker images -q)

eval $(docker-machine env node-4)
docker stop $(docker ps -a -q);docker rm -f $(docker ps -a -q);docker rmi -f $(docker images -q)

eval $(docker-machine env node-1)
docker network rm my-net

echo "Setting environment variables"
export KV_IP=172.31.15.183;export MASTER_IP=172.31.15.181;export SLAVE_IP1=172.31.15.182; export SLAVE_IP2=172.31.6.170

eval $(docker-machine env node-1)
docker node ls
docker network create --driver overlay --subnet=10.0.9.0/24 my-net
#docker login -u GSPREPO -p tally123 https://ec2-35-154-15-160.ap-south-1.compute.amazonaws.com

docker service create --name swarm-listener \
    --network my-net \
    --mount "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock" \
    -e DF_NOTIF_CREATE_SERVICE_URL=http://proxy:8080/v1/docker-flow-proxy/reconfigure \
    -e DF_NOTIF_REMOVE_SERVICE_URL=http://proxy:8080/v1/docker-flow-proxy/remove \
    --constraint 'node.role==manager' \
    vfarcic/docker-flow-swarm-listener
sleep 4

echo "To start vizualization service"
#docker service create \
#  --name=viz \
#  --publish=5000:8080/tcp \
#  --constraint 'node.role==manager' \
#  --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
#  manomarks/visualizer
#sleep 8

#docker service create \
#    --publish 9008:9000 \
#    --limit-cpu 0.5 \
#    --name portainer-swarm \
#    --constraint=node.role==manager \
#    --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
#    portainer/portainer \
#    -H unix:///var/run/docker.sock

docker \
  service create --name cadvisor \
  --mode global \
  --network my-net \
  --label com.docker.stack.namespace=monitoring \
  --container-label com.docker.stack.namespace=monitoring \
  --mount type=bind,src=/,dst=/rootfs:ro \
  --mount type=bind,src=/var/run,dst=/var/run:rw \
  --mount type=bind,src=/sys,dst=/sys:ro \
  --mount type=bind,src=/var/lib/docker/,dst=/var/lib/docker:ro \
  google/cadvisor:v0.24.1


docker \
  service create --name node-exporter \
  --mode global \
  --network my-net \
  --label com.docker.stack.namespace=monitoring \
  --container-label com.docker.stack.namespace=monitoring \
  --mount type=bind,source=/proc,target=/host/proc \
  --mount type=bind,source=/sys,target=/host/sys \
  --mount type=bind,source=/,target=/rootfs \
  --mount type=bind,source=/etc/hostname,target=/etc/host_hostname \
  -e HOST_HOSTNAME=/etc/host_hostname \
  basi/node-exporter \
  -collector.procfs /host/proc \
  -collector.sysfs /host/sys \
  -collector.filesystem.ignored-mount-points "^/(sys|proc|dev|host|etc)($|/)" \
  --collector.textfile.directory /etc/node-exporter/ \
  --collectors.enabled="conntrack,diskstats,entropy,filefd,filesystem,loadavg,mdadm,meminfo,netdev,netstat,stat,textfile,time,vmstat,ipvs"


docker \
  service create --name alertmanager \
  --network my-net \
  --label com.docker.stack.namespace=monitoring \
  --container-label com.docker.stack.namespace=monitoring \
  --publish 9093:9093 \
  -e "SLACK_API=https://hooks.slack.com/services/TOKEN-HERE" \
  -e "LOGSTASH_URL=http://requestb.in/135bazt1/" \
  basi/alertmanager \
    -config.file=/etc/alertmanager/config.yml


docker \
  service create \
  --name prometheus \
  --network my-net \
  --label com.docker.stack.namespace=monitoring \
  --container-label com.docker.stack.namespace=monitoring \
  --publish 9090:9090 \
  basi/prometheus-swarm \
    -config.file=/etc/prometheus/prometheus.yml \
    -storage.local.path=/prometheus \
    -web.console.libraries=/etc/prometheus/console_libraries \
    -web.console.templates=/etc/prometheus/consoles \
    -alertmanager.url=http://alertmanager:9093


docker \
  service create \
  --name grafana \
  --network my-net \
  --label com.docker.stack.namespace=monitoring \
  --container-label com.docker.stack.namespace=monitoring \
  --publish 3000:3000 \
  -e "PROMETHEUS_ENDPOINT=http://prometheus:9090" \
   basi/grafana

docker \
  service create \
  --name python \
  --network my-net \
  --label com.docker.stack.namespace=monitoring \
  --container-label com.docker.stack.namespace=monitoring \
  python

echo "Services initializing..."
sleep 10





