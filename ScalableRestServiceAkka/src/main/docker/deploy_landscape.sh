#!/usr/bin/env bash
echo "Building and deploying persistence images....."
cd persistence
./build_deploy_cassandra.sh
cd ..

echo "Building and Deploying GSP Services"
cd services
./build_deploy_gsp_services.sh

cd ..
echo "Deployment Complete"