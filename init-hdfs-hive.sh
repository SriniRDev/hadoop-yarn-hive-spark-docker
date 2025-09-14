#!/bin/bash

# Wait for HDFS to exit safe mode
until hdfs dfsadmin -safemode get | grep -q "Safe mode is OFF"; do
  echo "Waiting for HDFS to exit safe mode..."
  sleep 5
done

# Create Hive directories
hdfs dfs -mkdir -p /tmp /user/hive/warehouse
hdfs dfs -chmod -R 777 /tmp /user/hive

# Start HiveServer2
echo "Starting HiveServer2..."
/opt/hive/bin/hive --service hiveserver2
