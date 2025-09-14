#!/bin/bash
get_formatted_date() {
  date +"%Y-%m-%y"
}

printInfo() {
  echo "$(get_formatted_date) [INFO]:"
}

printWarn() {
  echo "$(get_formatted_date) [WARN]:"
}

printError() {
  echo "$(get_formatted_date) [ERROR]:"
}

wait_for_healthy() {
  local container_name="$1"
  local timeout=60
  local interval=5
  local elapsed=0

  echo "⏳ Waiting up to $timeout seconds for container '$container_name' to become healthy..."

  while [ $elapsed -lt $timeout ]; do
    local status
    status=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null)

    if [ "$status" == "healthy" ]; then
      echo "✅ Container '$container_name' is healthy!"
      return 0
    elif [ -z "$status" ]; then
      echo "⚠️ Container '$container_name' not found or has no health check configured."
      return 2
    else
      echo "🔄 Status: $status (elapsed: ${elapsed}s)"
    fi

    sleep $interval
    elapsed=$((elapsed + interval))
  done

  echo "⏱️ Timeout reached. Container '$container_name' did not become healthy within $timeout seconds."
  return 0
}

# Check for all container's health at the end and reports if any unhealthy
check_containers_health() {
  local containers=("$@")
  local unhealthy=()

  echo "🔍 Checking health status of containers..."

  for container in "${containers[@]}"; do
    local status
    status=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null)

    if [ "$status" != "healthy" ]; then
      echo "$(printError) ❌ $container is not healthy (status: ${status:-unknown})"
      unhealthy+=("$container")
    else
      echo "✅ $container is healthy"
    fi
  done

  if [ ${#unhealthy[@]} -gt 0 ]; then
    echo -e "\n🚨 Unhealthy containers detected:"
    for bad in "${unhealthy[@]}"; do
      echo " - $bad"
    done
    return 1
  else
    echo "\n🎉 All containers are healthy!"
    return 0
  fi
}

find . -type f -name "*.sh" -exec chmod +x {} \;

# Check Docker daemon is running:
docker info > /dev/null || { echo "$(printError) ❌ Docker is not running"; exit 1; }
echo "$(printInfo) Docker is up and running..."

# Verify available memory and CPU:
echo "$(printInfo) Verify available memory and CPU:\n"
free -h
nproc

# Network Setup
docker network ls | grep spark-net || docker network create spark-net
echo "$(printInfo) Docker network spark-net is available"

# Volume Sanity
if docker volume ls | grep -q hdfs_namenode; then
  echo "$(printInfo) Bind mount host directory hdfs_namenode available"
else
  mkdir -p ./hdfs_namenode
  echo "$(printInfo) Bind mount host directory hdfs_namenode was unavailable and hence created one"
fi

if docker volume ls | grep -q hdfs_datanode; then
  echo "$(printInfo) Bind mount host directory hdfs_datanode available"
else
  mkdir -p ./hdfs_datanode
  echo "$(printInfo) Bind mount host directory hdfs_datanode was unavailable and hence created one"
fi

# bind mount for jupyter notebooks
if docker volume ls | grep -q notebooks; then
  echo "$(printInfo) Bind mount host directory notebooks available"
else
  mkdir -p ./notebooks
  echo "$(printInfo) Bind mount host directory notebooks was unavailable and hence created one"
fi



# List of container names to clean up
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

echo "$(printInfo) 🧹 Cleaning up existing containers..."

for container in "${containers[@]}"; do
  if docker ps -a --format '{{.Names}}' | grep -w "$container" > /dev/null; then
    echo "$(printInfo) Removing container: $container"
    docker rm -f "$container"
  fi
done

sleep 5

# Port Availability
for port in 9870 8088 10000 8080; do
  if lsof -i :$port; then
    echo "$(printError) ❌ Port $port is already in use"; exit 1;
  fi
done

echo "$(printInfo) Pre startup verification completed"

NAMENODE_URL="http://localhost:9870"
YARN_UI="http://localhost:8088"
SPARK_MASTER_UI="http://localhost:8080"
JUPYTER_URL="http://localhost:8888"

echo "$(printInfo) 🚀 Starting Hadoop (HDFS)..."
docker-compose -f docker-compose-hdfs.yml up -d
wait_for_healthy namenode
wait_for_healthy datanode

echo "$(printInfo) 🚀 Starting YARN..."
docker-compose -f docker-compose-yarn.yml up -d
wait_for_healthy resourcemanager
wait_for_healthy nodemanager

echo "$(printInfo) 🚀 Starting Hive..."
docker-compose -f docker-compose-composite-hive.yml up -d
wait_for_healthy hive-metastore-postgresql
wait_for_healthy hive-metastore
wait_for_healthy hive-server

echo "$(printInfo) 🚀 Starting Spark..."
docker-compose -f docker-compose-spark.yml up -d
wait_for_healthy spark-master
wait_for_healthy spark-worker-1
wait_for_healthy spark-worker-2

#echo "$(printInfo) 🚀 Starting Jupyter..."
docker-compose -f docker-compose-jupyter.yml up -d
wait_for_healthy jupyter

echo "$(printInfo) 📦 Active containers:"
docker ps --format '{{.Names}}'

for name in "${containers[@]}"; do
  docker ps --format '{{.Names}}' | grep -w "$name" > /dev/null || echo "$(printError) ❌ Container $name is not running"
done

curl -sSf ${NAMENODE_URL} > /dev/null || echo "$(printError) ❌ HDFS NameNode UI not reachable"
curl -sSf ${YARN_UI} > /dev/null || echo "$(printError) ❌ YARN ResourceManager UI not reachable"
curl -sSf ${SPARK_MASTER_UI} > /dev/null || echo "$(printError) ❌ Spark Master UI not reachable"

check_containers_health "${containers[@]}"

open ${NAMENODE_URL} 2>/dev/null || open ${NAMENODE_URL} && sleep 2
open ${YARN_UI} 2>/dev/null || open ${YARN_UI} && sleep 2
open ${SPARK_MASTER_UI} 2>/dev/null || open ${SPARK_MASTER_UI}
