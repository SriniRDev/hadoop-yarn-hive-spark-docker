# hadoop-yarn-hive-spark-docker

- [Prequisites](#prequisites)
- [Starting and Stopping cluster](#starting-and-stopping-cluster)
- [Handy UI Urls](#handy-ui-urls)
- [Test same spark-hdfs-hive integration](#test-same-spark-hdfs-hive-integration)
  - [set up hive database and table](#set-up-hive-database-and-table)
  - [Verify if hdfs and hive are reachable from spark](#verify-if-hdfs-and-hive-are-reachable-from-spark)
  - [Verify if hdfs and hive are reachable from pyspark](#verify-if-hdfs-and-hive-are-reachable-from-pyspark)
- [Jupyter notebook example](#jupyter-notebook-example)
  - [Using jupyter lab notebook](#using-jupyter-lab-notebook)
  - [Using jupyter notebook in VSCode](#using-jupyter-notebook-in-vscode)
---

### Prequisites
- Install Docker Engine
- Download [apache-hive-2.3.2-bin.tar.gz](https://archive.apache.org/dist/hive/hive-2.3.2/) and copy the file to under lib directory present in this current working directory. This dependency is used to integrate spark with hive. 
- Below three dependencies are needed if you want to run `spark-shell`/`pyspark` or `spark-submit`, `beeline` from host machine or using jupyter notebook.
  - Download [spark-3.1.1-bin-hadoop3.2.tgz](https://archive.apache.org/dist/spark/spark-3.1.1/spark-3.1.1-bin-hadoop3.2.tgz)
  - Download [pyspark-3.1.1.tar.gz](https://archive.apache.org/dist/spark/spark-3.1.1/pyspark-3.1.1.tar.gz)
  - Download [hadoop-3.2.1.tar.gz](https://archive.apache.org/dist/hadoop/common/hadoop-3.2.1/hadoop-3.2.1.tar.gz)

Eventually, lib folder contents should be as below:
```shell
$ ls -l ./lib
apache-hive-2.3.2-bin.tar.gz
emp.txt
hadoop-3.2.1.tar.gz
postgresql-42.7.7.jar
pyspark-3.1.1.tar.gz
spark-3.1.1-bin-hadoop3.2.tgz
```
---
### Starting and Stopping cluster
Run below commands to start and stop the cluster:  
  - On `sh` compatible shell
    ```shell
     sh start-docker-hadoop-cluster.sh
     sh stop-docker-hadoop-cluster.sh
    ```

  - On `bash` compatible shell
    ```shell
      bash start-docker-hadoop-cluster.sh
      bash stop-docker-hadoop-cluster.sh
    ```
---
### Handy UI Urls:  
| Resource | UI Link |
|---|---|
|Namenode UI | http://localhost:9870 |
|Yarn UI | http://localhost:8088 |
|Spark Master UI | http://localhost:8080 |  
|Jupyter UI | http://localhost:8888 | 

---

### Test same spark-hdfs-hive integration
#### set up hive database and table
```shell
# Login to hive-server container
docker exec -it hive-server /bin/bash

# Initiate beeline session in hive-server container
beeline -u "jdbc:hive2://localhost:10000"
```
```sql
-- Create hive database named 'crm'
CREATE DATABASE IF NOT EXISTS crm
COMMENT 'This is a database for employee data'
LOCATION '/user/hive/warehouse/crm.db';

-- Create hive table 'emp' in 'crm' database
CREATE EXTERNAL TABLE crm.emp(
  empid int,
  empname string
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/hive/warehouse/crm.db/emp'
;
```
Copy sample data file to `crm.emp` tables hdfs location
```shell
# from host(local machine) copy the sample file ./lib/emp.txt into ./hdfs_namenode/
# Now this file will be available on name node container in the location '/hadoop/dfs/name/'
cp ./lib/emp.txt into ./hdfs_namenode/

# Login to namenode container
docker exec -it namenode /bin/bash
cd /hadoop/dfs/name/
ls -l

# copy this file to crm.emp table's hdfs location
hdfs dfs -put /hadoop/dfs/name/emp.txt /user/hive/warehouse/crm.db/emp/

# verify the file
hdfs dfs -ls /user/hive/warehouse/crm.db/emp/
```

Verify if hdfs and hive are reachable from spark
```shell
# Login to spark-master container
docker exec -it spark-master /bin/bash

# Start spark shell
spark-shell --master spark://spark-master:7077
```
```scala
// Read file from hdfs into spark
val df = spark.read.csv("hdfs://namenode:8020/user/hive/warehouse/crm.db/emp/emp.txt")
df.show(false)

// Verify spark sql implementation: should be 'hive'
spark.conf.get("spark.sql.catalogImplementation")

// List databases from hive
spark.catalog.listDatabases().show()

// Read table from hive into spark
val h = spark.table("crm.emp")
h.show(10, false)

```

Verify if hdfs and hive are reachable from pyspark
```shell
# Login to spark-master container
docker exec -it spark-master /bin/bash

# Start spark shell
pyspark --master spark://spark-master:7077
```
```python
# Read file from hdfs into spark
df = spark.read.csv("hdfs://namenode:8020/user/hive/warehouse/crm.db/emp/emp.txt")
df.show(False)

# Verify spark sql implementation: should be 'hive'
spark.conf.get("spark.sql.catalogImplementation")

# List databases from hive
spark.catalog.listDatabases().show()

# Read table from hive into spark
h = spark.table("crm.emp")
h.show(10, False)

```
---

### Jupyter notebook example
How get jupyter server url:
```shell
docker logs jupyter

# look in the logs for the the jupyter lab URL which looks like:
http://127.0.0.1:8888/lab?token=a12345678901234567890......
```
### Using jupyter lab notebook
Open the above link and it will take you to the lab. select notebook and use the code below to verify the setup.

### Using jupyter notebook in VSCode
1. Open VSCode in a WSL  
1. create an ipynb file  
1. Select Kernel -> select 'Existing Jupyter Server URL'  
1. Paste the link taken from jupyter container log -> Enter  
1. It shows 127.0.0.1 -> Enter  
1. Select the python environment listed from the jupyter server  

```python
from pyspark.sql import SparkSession

# Initialize SparkSession with Hive support
spark = SparkSession.builder \
    .appName("VSCode-Jupyter-Test") \
    .master("spark://spark-master:7077") \
    .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:8020") \
    .enableHiveSupport() \
    .getOrCreate()

# Log the Spark version
print(f"Spark version: {spark.version}")

spark.conf.get("spark.sql.catalogImplementation") # should show 'hive'

# Show current databases
spark.sql("SHOW DATABASES").show()

spark.table("crm.emp").show(10, False) # db and table should be already created and available in hive

```
