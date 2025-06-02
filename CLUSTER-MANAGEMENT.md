# Hadoop Cluster Node Management - Quick Reference

## Script Location
```bash
./manage-cluster-nodes.sh
```

## Available Commands

### 📋 Information Commands
```bash
./manage-cluster-nodes.sh list              # List all current nodes
./manage-cluster-nodes.sh status            # Show detailed cluster status
./manage-cluster-nodes.sh help              # Show help message
```

### ➕ Adding Nodes
```bash
./manage-cluster-nodes.sh add worker-node-1     # Add a new worker node
./manage-cluster-nodes.sh add 192.168.1.100     # Add node by IP address
```

### ➖ Removing Nodes
```bash
./manage-cluster-nodes.sh decommission worker-node-1  # Safely decommission first
./manage-cluster-nodes.sh remove worker-node-1        # Then remove from cluster
```

### 🔄 Node Management
```bash
./manage-cluster-nodes.sh recommission worker-node-1  # Bring back a decommissioned node
```

### 🏗️ Cluster Conversion
```bash
./manage-cluster-nodes.sh convert-multi     # Convert single-node to multi-node
./manage-cluster-nodes.sh convert-single    # Convert multi-node to single-node
```

### 💾 Backup & Restore
```bash
./manage-cluster-nodes.sh backup            # Backup current configuration
./manage-cluster-nodes.sh restore           # Restore from backup
```

## Typical Workflows

### Adding a New Worker Node
1. `./manage-cluster-nodes.sh add worker-node-2`
2. Set up SSH passwordless access to worker-node-2
3. Install Hadoop on worker-node-2
4. Copy configuration files to worker-node-2
5. Refresh cluster: `yarn rmadmin -refreshNodes`
6. Start services on worker-node-2

### Safely Removing a Node
1. `./manage-cluster-nodes.sh decommission worker-node-2`
2. Wait for decommissioning to complete
3. `./manage-cluster-nodes.sh remove worker-node-2`
4. Stop services on worker-node-2

### Converting Single-node to Multi-node
1. `./manage-cluster-nodes.sh convert-multi`
2. Add worker nodes as needed
3. Configure SSH and copy files to workers
4. Restart cluster

## Important Files Modified
- `$HADOOP_HOME/etc/hadoop/workers`
- `$HADOOP_HOME/etc/hadoop/core-site.xml`
- `$HADOOP_HOME/etc/hadoop/yarn-site.xml`
- `$HADOOP_HOME/etc/hadoop/dfs.exclude` (for decommissioning)
- `$HADOOP_HOME/etc/hadoop/yarn.exclude` (for decommissioning)

## Backup Location
- Backups stored in: `$HADOOP_HOME/backups/`
- Format: `hadoop_config_YYYYMMDD_HHMMSS.tar.gz`

## Monitoring Commands
```bash
hdfs dfsadmin -report                    # Check HDFS status
yarn node -list                         # Check YARN nodes
yarn rmadmin -refreshNodes              # Refresh node list
hdfs dfsadmin -refreshNodes             # Refresh HDFS nodes
```
