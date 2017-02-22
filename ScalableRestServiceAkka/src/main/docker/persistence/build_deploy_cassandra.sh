#!/usr/bin/env bash
echo "Download Binaries..."
./download_binaries.sh

echo "Building Cassandra Images.................."
./scripts/build_images.sh

echo "Deploying 3 node Cassandra Cluster........."
./scripts/start_docker_cluster.sh dse opscenter 3