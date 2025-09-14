#!/bin/bash

set -e

MAX_RETRIES=30
RETRY_INTERVAL=5
MASTER_UI_URL="http://spark-master:8080"

echo "Waiting for Spark Master UI at $MASTER_UI_URL..."

for i in $(seq 1 $MAX_RETRIES); do
  if curl -s "$MASTER_UI_URL" | grep -q "Spark Master at"; then
    echo "[$(date)] Spark Master UI is available. Starting Spark Worker..."
    exec $SPARK_HOME/bin/spark-class org.apache.spark.deploy.worker.Worker --cores 2 --memory 3g "$SPARK_MASTER"
  fi
  echo "[$(date)] Attempt $i/$MAX_RETRIES: Spark Master UI not ready yet. Retrying in ${RETRY_INTERVAL}s..."
  sleep $RETRY_INTERVAL
done

echo "[$(date)] ERROR: Timeout waiting for Spark Master UI after $((MAX_RETRIES * RETRY_INTERVAL)) seconds."
exit 1
