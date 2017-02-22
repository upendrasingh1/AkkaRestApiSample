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
export KV_IP=172.30.1.14;export MASTER_IP=172.30.1.200;export SLAVE_IP1=172.30.1.63; export SLAVE_IP2=172.30.1.88

eval $(docker-machine env node-1)

echo "Force enabling "
ssh root@$KV_IP 'update-ca-trust force-enable';ssh root@$MASTER_IP 'update-ca-trust force-enable';ssh root@$SLAVE_IP1 'update-ca-trust force-enable';ssh root@$SLAVE_IP2 'update-ca-trust force-enable'

echo "Exporting the exported tar files to docker swarm"
scp /etc/pki/ca-trust/source/anchors/devdockerwebCA2.crt root@$KV_IP:/etc/pki/ca-trust/source/anchors;scp /etc/pki/ca-trust/source/anchors/devdockerwebCA2.crt root@$MASTER_IP:/etc/pki/ca-trust/source/anchors;scp /etc/pki/ca-trust/source/anchors/devdockerwebCA2.crt root@$SLAVE_IP1:/etc/pki/ca-trust/source/anchors;scp /etc/pki/ca-trust/source/anchors/devdockerwebCA2.crt root@$SLAVE_IP2:/etc/pki/ca-trust/source/anchors

echo "Install the certificates"
ssh root@$KV_IP 'update-ca-trust extract';ssh root@$MASTER_IP 'update-ca-trust extract';ssh root@$SLAVE_IP1 'update-ca-trust extract';ssh root@$SLAVE_IP2 'update-ca-trust extract'

echo "Restart the docker"
ssh root@$KV_IP 'service docker restart';ssh root@$MASTER_IP 'service docker restart';ssh root@$SLAVE_IP1 'service docker restart';ssh root@$SLAVE_IP2 'service docker restart'

echo "Login into all the machines"
ssh root@$KV_IP 'docker login -u lssetup -p tally@123 https://ec2-35-154-15-160.ap-south-1.compute.amazonaws.com'; \
ssh root@$MASTER_IP 'docker login -u lssetup -p tally@123 https://ec2-35-154-15-160.ap-south-1.compute.amazonaws.com'; \
ssh root@$SLAVE_IP1 'docker login -u lssetup -p tally@123 https://ec2-35-154-15-160.ap-south-1.compute.amazonaws.com'; \
ssh root@$SLAVE_IP2 'docker login -u lssetup -p tally@123 https://ec2-35-154-15-160.ap-south-1.compute.amazonaws.com'

eval $(docker-machine env node-1)
docker node ls
docker network create --driver overlay --subnet=10.0.9.0/24 my-net
docker login -u lssetup -p tally@123 https://ec2-35-154-15-160.ap-south-1.compute.amazonaws.com

echo "First set up Monitoring Services...."
echo "Starting elastic search..."
ssh root@$KV_IP 'sysctl -w vm.max_map_count=262144;'
docker service create --name elasticsearch \
    --constraint=node.role==manager \
    --network my-net \
    -p 9200:9200 \
    --reserve-memory 800m \
    elasticsearch:latest

wait_for_service elasticsearch

echo "Deploying logstash and all the nodes...."
ssh root@$KV_IP 'rm -rf /root/docker/logstash;rmdir /root/docker/logstash; mkdir -p /root/docker/logstash;yum -y install wget;pushd /root/docker/logstash; wget https://raw.githubusercontent.com/vfarcic/cloud-provisioning/master/conf/logstash.conf; popd'; \
ssh root@$MASTER_IP 'rm -rf /root/docker/logstash;rmdir /root/docker/logstash; mkdir -p /root/docker/logstash;yum -y install wget;pushd /root/docker/logstash; wget https://raw.githubusercontent.com/vfarcic/cloud-provisioning/master/conf/logstash.conf; popd'; \
ssh root@$SLAVE_IP1 'rm -rf /root/docker/logstash;rmdir /root/docker/logstash; mkdir -p /root/docker/logstash;yum -y install wget;pushd /root/docker/logstash; wget https://raw.githubusercontent.com/vfarcic/cloud-provisioning/master/conf/logstash.conf; popd'; \
ssh root@$SLAVE_IP2 'rm -rf /root/docker/logstash;rmdir /root/docker/logstash; mkdir -p /root/docker/logstash;yum -y install wget;pushd /root/docker/logstash; wget https://raw.githubusercontent.com/vfarcic/cloud-provisioning/master/conf/logstash.conf; popd'

docker service create --name logstash \
    --mount "type=bind,source=/root/docker/logstash,target=/conf" \
    --network my-net \
    -e LOGSPOUT=ignore \
    --reserve-memory 100m \
    logstash:latest logstash -f /conf/logstash.conf

wait_for_service logstash

docker service create --name kibana \
    -p 5601:5601 \
    --network my-net \
    -e ELASTICSEARCH_URL=http://elasticsearch:9200 \
    --reserve-memory 50m \
    --label com.df.notify=true \
    --label com.df.distribute=true \
    --label com.df.servicePath=/app/kibana,/bundles,/elasticsearch,/api,/plugins,/app/timelion \
    --label com.df.port=5601 \
    kibana:latest

wait_for_service kibana

docker service create --name logspout \
    --network my-net \
    --mode global \
    --mount "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock" \
    -e SYSLOG_FORMAT=rfc3164 \
    gliderlabs/logspout syslog://logstash:51415

wait_for_service logspout


echo "Start the zookeeper..."
docker service create --name zookeeper \
  -p 2181 \
  -e ZOO_MY_ID=1 \
  -e ZOO_SERVERS=server.1=zookeeper:2888:3888 \
  --network my-net \
  --constraint 'node.role==manager' \
  --with-registry-auth \
  zookeeper
  #ec2-35-154-15-160.ap-south-1.compute.amazonaws.com/zookeeper:gsp
wait_for_service zookeeper

echo "Locate zookeeper container and create path /ClusterSystem manually..and pressany key"
read -p 'Input: ' input

docker service create --name swarm-listener \
    --network my-net \
    --mount "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock" \
    -e DF_NOTIF_CREATE_SERVICE_URL=http://proxy:8080/v1/docker-flow-proxy/reconfigure \
    -e DF_NOTIF_REMOVE_SERVICE_URL=http://proxy:8080/v1/docker-flow-proxy/remove \
    --constraint 'node.role==manager' \
    vfarcic/docker-flow-swarm-listener
sleep 4

wait_for_service swarm-listener

docker service create --name proxy \
    -p 80:80 \
    -p 443:443 \
    -p 8080:8080 \
    --network my-net \
    -e MODE=swarm \
    -e LISTENER_ADDRESS=swarm-listener \
    --log-driver syslog \
    vfarcic/docker-flow-proxy

wait_for_service proxy
docker service create --name backend \
    --network my-net \
    --with-registry-auth \
   ec2-35-154-15-160.ap-south-1.compute.amazonaws.com/backend-application:1.0-SNAPSHOT

sleep 4
wait_for_service backend

docker service create --name frontend \
    -p 8080 \
    --network my-net \
    --with-registry-auth \
    --label com.df.notify=true \
    --label com.df.distribute=true \
    --label com.df.servicePath=/gsp/app/tallygstn/authentication/authtoken \
    --label com.df.port=8080 \
    ec2-35-154-15-160.ap-south-1.compute.amazonaws.com/rest-frontend:1.0-SNAPSHOT

wait_for_service frontend

echo "To start vizualization and monitoring services"
#docker service create \
#  --name=viz \
#  --publish=5000:8080/tcp \
#  --constraint 'node.role==manager' \
#  --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
#  manomarks/visualizer
#sleep 8
#wait_for_service viz

 #docker service create \
 #   --publish 9008:9000 \
 #   --limit-cpu 0.5 \
 #   --name portainer-swarm \
 #   --constraint=node.role==manager \
 #   --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
 #   portainer/portainer \
 #   -H unix:///var/run/docker.sock
#wait_for_service portainer-swarm

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
wait_for_service cadvisor

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

wait_for_service node-exporter

docker \
  service create --name alertmanager \
  --network my-net \
  --label com.docker.stack.namespace=monitoring \
  --container-label com.docker.stack.namespace=monitoring \
  --publish 9093:9093 \
  -e "SLACK_API=https://hooks.slack.com/services/TOKEN-HERE" \
  -e "LOGSTASH_URL=http://logstash:8080/" \
  basi/alertmanager \
    -config.file=/etc/alertmanager/config.yml

wait_for_service alertmanager

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

wait_for_service prometheus

docker \
  service create \
  --name grafana \
  --network my-net \
  --label com.docker.stack.namespace=monitoring \
  --container-label com.docker.stack.namespace=monitoring \
  --publish 3000:3000 \
#  -e "GF_SERVER_ROOT_URL=http://grafana.${CLUSTER_DOMAIN}" \
#  -e "GF_SECURITY_ADMIN_PASSWORD=$GF_PASSWORD" \
  -e "PROMETHEUS_ENDPOINT=http://prometheus:9090" \
#  -e "ELASTICSEARCH_ENDPOINT=$ES_ADDRESS" \
#  -e "ELASTICSEARCH_USER=$ES_USERNAME" \
#  -e "ELASTICSEARCH_PASSWORD=$ES_PASSWORD" \
  basi/grafana

wait_for_service grafna

echo "Services initializing..."
sleep 10

docker service ls





