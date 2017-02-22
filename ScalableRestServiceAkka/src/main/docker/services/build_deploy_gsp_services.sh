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

echo "Compile the platform binaries..."
mvn -f ../../../../pom.xml clean package

echo "Build frontend image from the project"
eval $(docker-machine env node-1)
CURL_CA_BUNDLE= docker-compose -f gsp_platform_seed.yml build frontend

echo "Build backend image from the project"
CURL_CA_BUNDLE= docker-compose -f gsp_platform_seed.yml build backend

echo "Build akkaseed image from the project"
CURL_CA_BUNDLE= docker-compose -f gsp_platform_seed.yml build akkaseed

#echo "Compile proxy"
cd /root/proxy
#cd docker-flow-proxy
#export PATH=$PATH:/usr/local/go/bin
#export GOPATH=/usr/local/go/
#go get -d -v -t && go test --cover -v ./... --run UnitTest && go build -v -o docker-flow-proxy
docker build -t proxy .
cd /root/work/tally-gsp-demo/src/main/docker/services

echo "Build haproxy image from the project"
#CURL_CA_BUNDLE= docker-compose -f gsp_platform_seed.yml build proxy

echo "Export images to tar files"
docker save frontend > /tmp/frontend.tar;docker save backend > /tmp/backend.tar;docker save proxy > /tmp/proxy.tar;docker save akkaseed > /tmp/akkaseed.tar

echo "Force enabling "
ssh root@$KV_IP 'update-ca-trust force-enable';ssh root@$MASTER_IP 'update-ca-trust force-enable';ssh root@$SLAVE_IP1 'update-ca-trust force-enable';ssh root@$SLAVE_IP2 'update-ca-trust force-enable'

echo "Exporting the exported tar files to docker swarm"
scp /tmp/akkaseed.tar root@$KV_IP:/root;scp /tmp/akkaseed.tar root@$MASTER_IP:/root;scp /tmp/akkaseed.tar root@$SLAVE_IP1:/root;scp /tmp/akkaseed.tar root@$SLAVE_IP2:/root; \
scp /tmp/proxy.tar root@$KV_IP:/root;scp /tmp/proxy.tar root@$MASTER_IP:/root;scp /tmp/proxy.tar root@$SLAVE_IP1:/root;scp /tmp/proxy.tar root@$SLAVE_IP2:/root; \
scp /tmp/frontend.tar root@$KV_IP:/root;scp /tmp/frontend.tar root@$MASTER_IP:/root;scp /tmp/frontend.tar root@$SLAVE_IP1:/root;scp /tmp/frontend.tar root@$SLAVE_IP2:/root; \
scp /tmp/backend.tar root@$KV_IP:/root;scp /tmp/backend.tar root@$MASTER_IP:/root;scp /tmp/backend.tar root@$SLAVE_IP1:/root;scp /tmp/backend.tar root@$SLAVE_IP2:/root; \
scp /etc/pki/ca-trust/source/anchors/devdockerCA.crt root@$KV_IP:/etc/pki/ca-trust/source/anchors;scp /etc/pki/ca-trust/source/anchors/devdockerCA.crt root@$MASTER_IP:/etc/pki/ca-trust/source/anchors;scp /etc/pki/ca-trust/source/anchors/devdockerCA.crt root@$SLAVE_IP1:/etc/pki/ca-trust/source/anchors;scp /etc/pki/ca-trust/source/anchors/devdockerCA.crt root@$SLAVE_IP2:/etc/pki/ca-trust/source/anchors

echo "Install the certificates"
ssh root@$KV_IP 'update-ca-trust extract';ssh root@$MASTER_IP 'update-ca-trust extract';ssh root@$SLAVE_IP1 'update-ca-trust extract';ssh root@$SLAVE_IP2 'update-ca-trust extract'

echo "Restart the docker"
ssh root@$KV_IP 'service docker restart';ssh root@$MASTER_IP 'service docker restart';ssh root@$SLAVE_IP1 'service docker restart';ssh root@$SLAVE_IP2 'service docker restart'

echo "For sanity once again removing all the images"
ssh root@$KV_IP 'docker rmi akkaseed;docker rmi proxy;docker rmi backend; docker rmi frontend';ssh root@$MASTER_IP 'docker rmi akkaseed;docker rmi proxy;docker rmi backend; docker rmi frontend';ssh root@$SLAVE_IP1 'docker rmi akkaseed;docker rmi proxy;docker rmi backend; docker rmi frontend';ssh root@$SLAVE_IP2 'docker rmi akkaseed;docker rmi proxy;docker rmi backend; docker rmi frontend'

echo "Loading images on the machines"
ssh root@$KV_IP 'docker load < akkaseed.tar;docker load < proxy.tar;docker load < backend.tar;docker load < frontend.tar';ssh root@$MASTER_IP 'docker load < akkaseed.tar;docker load < proxy.tar;docker load < backend.tar;docker load < frontend.tar';ssh root@$SLAVE_IP1 'docker load < akkaseed.tar;docker load < proxy.tar;docker load < backend.tar;docker load < frontend.tar';ssh root@$SLAVE_IP2 'docker load < akkaseed.tar;docker load < proxy.tar;docker load < backend.tar;docker load < frontend.tar'

eval $(docker-machine env node-1)
docker node ls
docker network create --driver overlay --subnet=10.0.9.0/24 my-net
#docker login -u GSPREPO -p tally123 https://ec2-35-154-15-160.ap-south-1.compute.amazonaws.com

echo "First set up Monitoring Services...."
echo "Starting elastic search..."
ssh root@$KV_IP 'sysctl -w vm.max_map_count=262144;'

#docker service create --name elasticsearch \
#    --constraint=node.role==manager \
#    --network my-net \
#    -p 9200:9200 \
#    --reserve-memory 800m \
#    elasticsearch:latest

#wait_for_service elasticsearch

echo "Deploying logstash and all the nodes...."
ssh root@$KV_IP 'rm -rf /root/docker/logstash;rmdir /root/docker/logstash; mkdir -p /root/docker/logstash;yum -y install wget;pushd /root/docker/logstash; wget https://raw.githubusercontent.com/vfarcic/cloud-provisioning/master/conf/logstash.conf; popd'; \
ssh root@$MASTER_IP 'rm -rf /root/docker/logstash;rmdir /root/docker/logstash; mkdir -p /root/docker/logstash;yum -y install wget;pushd /root/docker/logstash; wget https://raw.githubusercontent.com/vfarcic/cloud-provisioning/master/conf/logstash.conf; popd'; \
ssh root@$SLAVE_IP1 'rm -rf /root/docker/logstash;rmdir /root/docker/logstash; mkdir -p /root/docker/logstash;yum -y install wget;pushd /root/docker/logstash; wget https://raw.githubusercontent.com/vfarcic/cloud-provisioning/master/conf/logstash.conf; popd'; \
ssh root@$SLAVE_IP2 'rm -rf /root/docker/logstash;rmdir /root/docker/logstash; mkdir -p /root/docker/logstash;yum -y install wget;pushd /root/docker/logstash; wget https://raw.githubusercontent.com/vfarcic/cloud-provisioning/master/conf/logstash.conf; popd'

#docker service create --name logstash \
#    --mount "type=bind,source=/root/docker/logstash,target=/conf" \
#    --network my-net \
#    -e LOGSPOUT=ignore \
#    --reserve-memory 100m \
#    logstash:latest logstash -f /conf/logstash.conf

#wait_for_service logstash

#docker service create --name kibana \
#    -p 5601:5601 \
#    --network my-net \
#    -e ELASTICSEARCH_URL=http://elasticsearch:9200 \
#    --reserve-memory 50m \
#    --label com.df.notify=true \
#    --label com.df.distribute=true \
#    --label com.df.servicePath=/app/kibana,/bundles,/elasticsearch,/api,/plugins,/app/timelion \
#    --label com.df.port=5601 \
#    kibana:latest

#wait_for_service kibana

#docker service create --name logspout \
#    --network my-net \
#    --mode global \
#    --mount "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock" \
#    -e SYSLOG_FORMAT=rfc3164 \
#    gliderlabs/logspout syslog://logstash:51415

#wait_for_service logspout

#echo "Start the zookeeper..."
#docker service create --name zookeeper \
#  -p 2181 \
#  -e ZOO_MY_ID=1 \
#  -e ZOO_SERVERS=server.1=zookeeper:2888:3888 \
#  --network my-net \
#  zookeeper

#echo "Locate zookeeper container and create path /ClusterSystem manually..and pressany key"
#read -p 'Input: ' input

docker service create --name swarm-listener \
    --network my-net \
    --mount "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock" \
    -e DF_NOTIF_CREATE_SERVICE_URL=http://proxy:8080/v1/docker-flow-proxy/reconfigure \
    -e DF_NOTIF_REMOVE_SERVICE_URL=http://proxy:8080/v1/docker-flow-proxy/remove \
    --constraint 'node.role==manager' \
    vfarcic/docker-flow-swarm-listener
sleep 4

docker service create --name proxy \
    -p 80:80 \
    -p 443:443 \
    -p 8080:8080 \
    --network my-net \
    -e MODE=swarm \
    -e LISTENER_ADDRESS=swarm-listener \
    proxy

docker service create --name akkaseed \
  --hostname akkaseed \
  -p 2552 \
  --network my-net \
  akkaseed

docker service create --name backend \
  --network my-net \
  backend

#sleep 2

docker service create --name frontend \
  -p 8080 \
  --network my-net \
  --label com.df.notify=true \
  --label com.df.distribute=true \
  --label com.df.servicePath=/addition \
  --label com.df.port=8080 \
  frontend

#docker stack up --compose-file=docker-compose.yml mystack

sleep 2

echo "To start vizualization service"
docker service create \
  --name=viz \
  --publish=5000:8080/tcp \
  --constraint 'node.role==manager' \
  --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  manomarks/visualizer
sleep 8

docker service create \
    --publish 9008:9000 \
    --limit-cpu 0.5 \
    --name portainer-swarm \
    --constraint=node.role==manager \
    --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
    portainer/portainer \
    -H unix:///var/run/docker.sock

#docker \
#  service create --name cadvisor \
#  --mode global \
#  --network my-net \
#  --label com.docker.stack.namespace=monitoring \
#  --container-label com.docker.stack.namespace=monitoring \
#  --mount type=bind,src=/,dst=/rootfs:ro \
#  --mount type=bind,src=/var/run,dst=/var/run:rw \
#  --mount type=bind,src=/sys,dst=/sys:ro \
#  --mount type=bind,src=/var/lib/docker/,dst=/var/lib/docker:ro \
#  google/cadvisor:v0.24.1
#wait_for_service cadvisor

#docker \
#  service create --name node-exporter \
#  --mode global \
#  --network my-net \
#  --label com.docker.stack.namespace=monitoring \
#  --container-label com.docker.stack.namespace=monitoring \
#  --mount type=bind,source=/proc,target=/host/proc \
#  --mount type=bind,source=/sys,target=/host/sys \
#  --mount type=bind,source=/,target=/rootfs \
#  --mount type=bind,source=/etc/hostname,target=/etc/host_hostname \
#  -e HOST_HOSTNAME=/etc/host_hostname \
#  basi/node-exporter \
#  -collector.procfs /host/proc \
#  -collector.sysfs /host/sys \
#  -collector.filesystem.ignored-mount-points "^/(sys|proc|dev|host|etc)($|/)" \
#  --collector.textfile.directory /etc/node-exporter/ \
#  --collectors.enabled="conntrack,diskstats,entropy,filefd,filesystem,loadavg,mdadm,meminfo,netdev,netstat,stat,textfile,time,vmstat,ipvs"

#wait_for_service node-exporter

#docker \
#  service create --name alertmanager \
#  --network my-net \
#  --label com.docker.stack.namespace=monitoring \
#  --container-label com.docker.stack.namespace=monitoring \
#  --publish 9093:9093 \
#  -e "SLACK_API=https://hooks.slack.com/services/TOKEN-HERE" \
#  -e "LOGSTASH_URL=http://logstash:8080/" \
#  basi/alertmanager \
#    -config.file=/etc/alertmanager/config.yml

#wait_for_service alertmanager

#docker \
#  service create \
#  --name prometheus \
#  --network my-net \
#  --label com.docker.stack.namespace=monitoring \
#  --container-label com.docker.stack.namespace=monitoring \
#  --publish 9090:9090 \
#  basi/prometheus-swarm \
#    -config.file=/etc/prometheus/prometheus.yml \
#    -storage.local.path=/prometheus \
#    -web.console.libraries=/etc/prometheus/console_libraries \
#    -web.console.templates=/etc/prometheus/consoles \
#    -alertmanager.url=http://alertmanager:9093

#wait_for_service prometheus

#docker \
#  service create \
#  --name grafana \
#  --network my-net \
#  --label com.docker.stack.namespace=monitoring \
#  --container-label com.docker.stack.namespace=monitoring \
#  --publish 3000:3000 \
#  -e "PROMETHEUS_ENDPOINT=http://prometheus:9090" \
#   basi/grafana

#wait_for_service grafana
curl "$(docker-machine ip node-1):8080/v1/docker-flow-proxy/reconfigure?serviceName=frontend&servicePath=/addition&port=8080&distribute=true"
echo "Services initializing..."
sleep 20





