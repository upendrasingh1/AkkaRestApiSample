#!/usr/bin/env bash
echo "Removing GSP Services and Zookeeper"
cd services
./remove_landscape.sh
cd ..

echo "Removing Cassandra"
cd persistence/scripts
./teardown_docker_cluster.sh 3
cd ../..