#!/bin/bash

# Hadoop Cluster Status Check Script
# This script provides a comprehensive overview of your Hadoop cluster

echo "🔍 HADOOP CLUSTER STATUS REPORT"
echo "========================================"
echo "Generated on: $(date)"
echo ""

# Check if Hadoop services are running
echo "📊 RUNNING HADOOP SERVICES:"
echo "----------------------------"
HADOOP_PROCESSES=$(ps aux | grep -E "(namenode|datanode|resourcemanager|nodemanager|secondarynamenode)" | grep -v grep | wc -l | tr -d ' ')
echo "Total Hadoop processes running: $HADOOP_PROCESSES"

if [ $HADOOP_PROCESSES -gt 0 ]; then
    echo ""
    echo "Active services:"
    ps aux | grep -E "(namenode|datanode|resourcemanager|nodemanager|secondarynamenode)" | grep -v grep | grep -o -E "(namenode|datanode|resourcemanager|nodemanager|secondarynamenode)" | sort | uniq | while read service; do
        echo "  ✅ $service"
    done
else
    echo "  ❌ No Hadoop services are running"
fi

echo ""
echo "🗂️  HDFS CLUSTER STATUS:"
echo "-------------------------"
$HADOOP_HOME/bin/hdfs dfsadmin -report 2>/dev/null | grep -E "(Live datanodes|Total Nodes|Configured Capacity|DFS Used|DFS Remaining)" | head -6

echo ""
echo "🧮 YARN CLUSTER STATUS:"
echo "------------------------"
YARN_NODES=$($HADOOP_HOME/bin/yarn node -list 2>/dev/null | grep -c "Node-Id")
echo "YARN Active Nodes: $YARN_NODES"

echo ""
echo "🌐 WEB INTERFACES:"
echo "-------------------"
echo "  • NameNode Web UI:        http://localhost:9870"
echo "  • ResourceManager Web UI: http://localhost:8088"
echo "  • DataNode Web UI:        http://localhost:9864"
echo "  • NodeManager Web UI:     http://localhost:8042"
echo "  • Job History Server:     http://localhost:19888"

echo ""
echo "📈 CLUSTER SUMMARY:"
echo "--------------------"
if [ $HADOOP_PROCESSES -eq 5 ]; then
    echo "  Status: ✅ HEALTHY - All core services running"
    echo "  Cluster Type: Single-node (Pseudo-distributed)"
    echo "  HDFS Nodes: 1 (localhost)"
    echo "  YARN Nodes: 1 (localhost)"
elif [ $HADOOP_PROCESSES -gt 0 ]; then
    echo "  Status: ⚠️  PARTIAL - Some services may be down"
    echo "  Running services: $HADOOP_PROCESSES/5"
else
    echo "  Status: ❌ DOWN - No Hadoop services running"
    echo "  💡 Run 'start-all.sh' to start the cluster"
fi

echo ""
echo "🔧 QUICK COMMANDS:"
echo "-------------------"
echo "  Start cluster:  start-all.sh"
echo "  Stop cluster:   stop-all.sh"
echo "  Check HDFS:     hdfs dfs -ls /"
echo "  HDFS report:    hdfs dfsadmin -report"
echo "  YARN nodes:     yarn node -list"
echo ""
