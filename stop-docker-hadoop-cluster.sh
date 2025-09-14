#!/bin/bash

# Logging functions
get_formatted_date() {
  date +"%Y-%m-%y"
}

printInfo() {
  echo "$(get_formatted_date) [INFO]: $1"
}

printWarn() {
  echo "$(get_formatted_date) [WARN]: $1"
}

printError() {
  echo "$(get_formatted_date) [ERROR]: $1"
}

# List of containers to remove
containers=(
  namenode
  datanode
  resourcemanager
  nodemanager
  hive-metastore-postgresql
  hive-metastore
  hive-server
  spark-master
  spark-worker-1
  spark-worker-2
  jupyter
)

printInfo "Starting container removal process..."

for container in "${containers[@]}"; do
  printInfo "Attempting to remove container: $container"
  docker rm -f "$container" &> /dev/null

  if docker ps -a --format '{{.Names}}' | grep -wq "$container"; then
    printError "❌ Failed to remove container: $container"
  else
    printInfo "✅ Successfully removed container: $container"
  fi
done

printInfo "Container cleanup complete."

sleep 5

# Port Availability
for port in 9870 8088 10000 8080; do
  if lsof -i :$port; then
    printError "❌ Port $port is still in use"; exit 1;
  fi
done

printInfo "✅ All ports are released."

