# Hadoop-YARN-Hive-Spark Docker Cluster

A lightweight Docker setup for running a local Hadoop + YARN + Hive + Spark cluster with optional Jupyter support.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Starting and Stopping the Cluster](#starting-and-stopping-the-cluster)
- [Handy UI URLs](#handy-ui-urls)
- [Testing Spark-HDFS-Hive Integration](#testing-spark-hdfs-hive-integration)
  - [Set up Hive Database and Table](#set-up-hive-database-and-table)
  - [Verify Access from Spark](#verify-access-from-spark)
  - [Verify Access from PySpark](#verify-access-from-pyspark)
- [Jupyter Notebook Usage](#jupyter-notebook-usage)
  - [Using Jupyter Lab](#using-jupyter-lab)
  - [Using VSCode Jupyter](#using-vscode-jupyter)

---

## Prerequisites

1. **Install Docker Engine**
2. **For Windows**: Enable WSL  
3. **Download the following files and place them in the `./lib/` directory:**

| Dependency | Download Link |
|------------|----------------|
| Apache Hive 2.3.2 | [apache-hive-2.3.2-bin.tar.gz](https://archive.apache.org/dist/hive/hive-2.3.2/) |
| Spark 3.1.1 (Hadoop 3.2) | [spark-3.1.1-bin-hadoop3.2.tgz](https://archive.apache.org/dist/spark/spark-3.1.1/spark-3.1.1-bin-hadoop3.2.tgz) |
| PySpark 3.1.1 | [pyspark-3.1.1.tar.gz](https://archive.apache.org/dist/spark/spark-3.1.1/pyspark-3.1.1.tar.gz) |
| Hadoop 3.2.1 | [hadoop-3.2.1.tar.gz](https://archive.apache.org/dist/hadoop/common/hadoop-3.2.1/hadoop-3.2.1.tar.gz) |

**Example `.lib/` folder:**

```bash
$ ls -l ./lib
apache-hive-2.3.2-bin.tar.gz
emp.txt
hadoop-3.2.1.tar.gz
postgresql-42.7.7.jar
pyspark-3.1.1.tar.gz
spark-3.1.1-bin-hadoop3.2.tgz
```

---

## Starting and Stopping the Cluster

Run the following commands from your project directory:

<details>
<summary>For <code>sh</code> compatible shells:</summary>

```bash
sh start-docker-hadoop-cluster.sh
sh stop-docker-hadoop-cluster.sh
```
</details>

<details>
<summary>For <code>bash</code> compatible shells:</summary>

```bash
bash start-docker-hadoop-cluster.sh
bash stop-docker-hadoop-cluster.sh
```
</details>

---

## Handy UI URLs

| Resource | URL |
|----------|-----|
| **NameNode UI** | [http://localhost:9870](http://localhost:9870) |
| **YARN ResourceManager UI** | [http://localhost:8088](http://localhost:8088) |
| **Spark Master UI** | [http://localhost:8080](http://localhost:8080) |
| **Jupyter Lab** | [http://localhost:8888](http://localhost:8888) |

---

## Testing Spark-HDFS-Hive Integration

### Set up Hive Database and Table

<details>
<summary>Step-by-step</summary>

```bash
# Access the Hive server container
docker exec -it hive-server /bin/bash

# Start Beeline (Hive CLI)
beeline -u "jdbc:hive2://localhost:10000"
```

```sql
-- Create Hive database
CREATE DATABASE IF NOT EXISTS crm
COMMENT 'Employee database'
LOCATION '/user/hive/warehouse/crm.db';

-- Create Hive table
CREATE EXTERNAL TABLE crm.emp(
  empid INT,
  empname STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/hive/warehouse/crm.db/emp';
```

```bash
# Copy sample file to HDFS
cp ./lib/emp.txt ./hdfs_namenode/

docker exec -it namenode /bin/bash
cd /hadoop/dfs/name/
hdfs dfs -put emp.txt /user/hive/warehouse/crm.db/emp/
hdfs dfs -ls /user/hive/warehouse/crm.db/emp/
```

</details>

---

### Verify Access from Spark

<details>
<summary>Run in <code>spark-shell</code></summary>

```bash
docker exec -it spark-master /bin/bash
spark-shell --master spark://spark-master:7077
```

```scala
// Read file from HDFS
val df = spark.read.csv("hdfs://namenode:8020/user/hive/warehouse/crm.db/emp/emp.txt")
df.show(false)

// Verify Hive is the catalog
spark.conf.get("spark.sql.catalogImplementation")

// List Hive databases
spark.catalog.listDatabases().show()

// Query Hive table
val
