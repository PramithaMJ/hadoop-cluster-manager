#!/bin/bash

# Hadoop Cluster Node Management Script
# This script helps you add, remove, and manage nodes in your Hadoop cluster

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
WORKERS_FILE="$HADOOP_CONF_DIR/workers"
BACKUP_DIR="$HADOOP_HOME/backups"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Functions
print_header() {
    echo -e "${CYAN}🔧 HADOOP CLUSTER NODE MANAGEMENT${NC}"
    echo -e "${CYAN}====================================${NC}"
    echo ""
}

print_usage() {
    echo -e "${YELLOW}Usage: $0 [COMMAND] [OPTIONS]${NC}"
    echo ""
    echo -e "${BLUE}Commands:${NC}"
    echo "  list              - List all current nodes"
    echo "  add <hostname>    - Add a new node to the cluster"
    echo "  remove <hostname> - Remove a node from the cluster"
    echo "  decommission <hostname> - Safely decommission a node"
    echo "  recommission <hostname> - Recommission a previously decommissioned node"
    echo "  status            - Show detailed cluster status"
    echo "  backup            - Backup current configuration"
    echo "  restore           - Restore from backup"
    echo "  convert-multi     - Convert single-node to multi-node setup"
    echo "  convert-single    - Convert multi-node to single-node setup"
    echo "  help              - Show this help message"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0 list"
    echo "  $0 add worker-node-1"
    echo "  $0 remove worker-node-2"
    echo "  $0 decommission worker-node-3"
    echo "  $0 status"
    echo ""
}

backup_config() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/hadoop_config_$timestamp.tar.gz"
    
    echo -e "${YELLOW}📦 Creating backup...${NC}"
    tar -czf "$backup_file" -C "$HADOOP_CONF_DIR" . 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Backup created: $backup_file${NC}"
    else
        echo -e "${RED}❌ Failed to create backup${NC}"
        return 1
    fi
}

list_nodes() {
    echo -e "${BLUE}📋 CURRENT CLUSTER NODES:${NC}"
    echo "=========================="
    
    if [ -f "$WORKERS_FILE" ]; then
        echo -e "${YELLOW}Workers file content:${NC}"
        cat "$WORKERS_FILE" | grep -v '^#' | grep -v '^$' | while read line; do
            echo "  • $line"
        done
        echo ""
    else
        echo -e "${YELLOW}⚠️  Workers file not found. Creating default...${NC}"
        echo "localhost" > "$WORKERS_FILE"
        echo "  • localhost (default)"
        echo ""
    fi
    
    echo -e "${BLUE}Live HDFS DataNodes:${NC}"
    $HADOOP_HOME/bin/hdfs dfsadmin -report 2>/dev/null | grep "Name:" | while read line; do
        node=$(echo $line | awk '{print $2}' | cut -d: -f1)
        echo "  • $node"
    done
    
    echo ""
    echo -e "${BLUE}Active YARN NodeManagers:${NC}"
    $HADOOP_HOME/bin/yarn node -list 2>/dev/null | grep -v "Total Nodes" | grep -v "Node-Id" | while read line; do
        if [ ! -z "$line" ]; then
            node_id=$(echo $line | awk '{print $1}')
            status=$(echo $line | awk '{print $2}')
            echo "  • $node_id ($status)"
        fi
    done
}

add_node() {
    local hostname=$1
    
    if [ -z "$hostname" ]; then
        echo -e "${RED}❌ Error: Hostname is required${NC}"
        echo "Usage: $0 add <hostname>"
        return 1
    fi
    
    echo -e "${YELLOW}➕ Adding node: $hostname${NC}"
    
    # Backup current configuration
    backup_config
    
    # Check if node already exists
    if grep -q "^$hostname$" "$WORKERS_FILE" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Node $hostname already exists in workers file${NC}"
        return 1
    fi
    
    # Add to workers file
    echo "$hostname" >> "$WORKERS_FILE"
    echo -e "${GREEN}✅ Added $hostname to workers file${NC}"
    
    # Update core-site.xml for multi-node setup
    update_core_site_multinode
    
    echo ""
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo "1. Ensure SSH passwordless access to $hostname"
    echo "2. Install and configure Hadoop on $hostname"
    echo "3. Copy configuration files to $hostname:"
    echo "   scp -r $HADOOP_CONF_DIR/* user@$hostname:$HADOOP_CONF_DIR/"
    echo "4. Refresh nodes: $HADOOP_HOME/bin/yarn rmadmin -refreshNodes"
    echo "5. Restart cluster or start services on new node"
    echo ""
}

remove_node() {
    local hostname=$1
    
    if [ -z "$hostname" ]; then
        echo -e "${RED}❌ Error: Hostname is required${NC}"
        echo "Usage: $0 remove <hostname>"
        return 1
    fi
    
    echo -e "${YELLOW}➖ Removing node: $hostname${NC}"
    
    # Backup current configuration
    backup_config
    
    # Check if node exists
    if ! grep -q "^$hostname$" "$WORKERS_FILE" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Node $hostname not found in workers file${NC}"
        return 1
    fi
    
    # Remove from workers file
    grep -v "^$hostname$" "$WORKERS_FILE" > "$WORKERS_FILE.tmp" && mv "$WORKERS_FILE.tmp" "$WORKERS_FILE"
    echo -e "${GREEN}✅ Removed $hostname from workers file${NC}"
    
    echo ""
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo "1. Decommission the node first: $0 decommission $hostname"
    echo "2. Refresh nodes: $HADOOP_HOME/bin/yarn rmadmin -refreshNodes"
    echo "3. Stop services on $hostname"
    echo "4. Remove Hadoop installation from $hostname (optional)"
    echo ""
}

decommission_node() {
    local hostname=$1
    
    if [ -z "$hostname" ]; then
        echo -e "${RED}❌ Error: Hostname is required${NC}"
        echo "Usage: $0 decommission <hostname>"
        return 1
    fi
    
    echo -e "${YELLOW}🚫 Decommissioning node: $hostname${NC}"
    
    # Backup current configuration
    backup_config
    
    # Create exclude file for decommissioning
    local exclude_file="$HADOOP_CONF_DIR/dfs.exclude"
    echo "$hostname" >> "$exclude_file"
    
    local yarn_exclude_file="$HADOOP_CONF_DIR/yarn.exclude"
    echo "$hostname" >> "$yarn_exclude_file"
    
    echo -e "${GREEN}✅ Added $hostname to exclude files${NC}"
    
    # Refresh nodes to start decommissioning
    echo -e "${YELLOW}🔄 Refreshing HDFS nodes...${NC}"
    $HADOOP_HOME/bin/hdfs dfsadmin -refreshNodes
    
    echo -e "${YELLOW}🔄 Refreshing YARN nodes...${NC}"
    $HADOOP_HOME/bin/yarn rmadmin -refreshNodes
    
    echo ""
    echo -e "${YELLOW}📝 Decommissioning process started${NC}"
    echo "Monitor progress with:"
    echo "  hdfs dfsadmin -report"
    echo "  yarn node -list -all"
    echo ""
    echo "When decommissioning is complete:"
    echo "  $0 remove $hostname"
    echo ""
}

recommission_node() {
    local hostname=$1
    
    if [ -z "$hostname" ]; then
        echo -e "${RED}❌ Error: Hostname is required${NC}"
        echo "Usage: $0 recommission <hostname>"
        return 1
    fi
    
    echo -e "${YELLOW}✅ Recommissioning node: $hostname${NC}"
    
    # Backup current configuration
    backup_config
    
    # Remove from exclude files
    local exclude_file="$HADOOP_CONF_DIR/dfs.exclude"
    local yarn_exclude_file="$HADOOP_CONF_DIR/yarn.exclude"
    
    if [ -f "$exclude_file" ]; then
        grep -v "^$hostname$" "$exclude_file" > "$exclude_file.tmp" && mv "$exclude_file.tmp" "$exclude_file"
        echo -e "${GREEN}✅ Removed $hostname from HDFS exclude file${NC}"
    fi
    
    if [ -f "$yarn_exclude_file" ]; then
        grep -v "^$hostname$" "$yarn_exclude_file" > "$yarn_exclude_file.tmp" && mv "$yarn_exclude_file.tmp" "$yarn_exclude_file"
        echo -e "${GREEN}✅ Removed $hostname from YARN exclude file${NC}"
    fi
    
    # Refresh nodes
    echo -e "${YELLOW}🔄 Refreshing nodes...${NC}"
    $HADOOP_HOME/bin/hdfs dfsadmin -refreshNodes
    $HADOOP_HOME/bin/yarn rmadmin -refreshNodes
    
    echo -e "${GREEN}✅ Node $hostname has been recommissioned${NC}"
    echo ""
}

update_core_site_multinode() {
    local core_site="$HADOOP_CONF_DIR/core-site.xml"
    
    # Check if we need to update for multi-node
    if grep -q "localhost:9000" "$core_site"; then
        echo -e "${YELLOW}🔧 Updating core-site.xml for multi-node setup...${NC}"
        
        # Get the hostname/IP of the master node
        local master_host=$(hostname)
        
        # Update core-site.xml
        sed -i.bak "s/localhost:9000/$master_host:9000/g" "$core_site"
        echo -e "${GREEN}✅ Updated fs.defaultFS to hdfs://$master_host:9000${NC}"
    fi
}

convert_to_multinode() {
    echo -e "${YELLOW}🔄 Converting to multi-node setup...${NC}"
    
    # Backup current configuration
    backup_config
    
    # Update core-site.xml
    update_core_site_multinode
    
    # Update yarn-site.xml
    local yarn_site="$HADOOP_CONF_DIR/yarn-site.xml"
    local master_host=$(hostname)
    
    if grep -q "localhost" "$yarn_site"; then
        sed -i.bak "s/localhost/$master_host/g" "$yarn_site"
        echo -e "${GREEN}✅ Updated YARN ResourceManager hostname to $master_host${NC}"
    fi
    
    echo -e "${GREEN}✅ Conversion to multi-node setup completed${NC}"
    echo ""
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo "1. Add worker nodes using: $0 add <hostname>"
    echo "2. Configure SSH passwordless access"
    echo "3. Copy configuration to all nodes"
    echo "4. Restart the cluster"
    echo ""
}

convert_to_singlenode() {
    echo -e "${YELLOW}🔄 Converting to single-node setup...${NC}"
    
    # Backup current configuration
    backup_config
    
    # Reset workers file
    echo "localhost" > "$WORKERS_FILE"
    echo -e "${GREEN}✅ Reset workers file to localhost only${NC}"
    
    # Update core-site.xml
    local core_site="$HADOOP_CONF_DIR/core-site.xml"
    sed -i.bak 's/hdfs:\/\/[^:]*:9000/hdfs:\/\/localhost:9000/g' "$core_site"
    echo -e "${GREEN}✅ Updated fs.defaultFS to hdfs://localhost:9000${NC}"
    
    # Update yarn-site.xml
    local yarn_site="$HADOOP_CONF_DIR/yarn-site.xml"
    sed -i.bak 's/<value>[^<]*<\/value>/<value>localhost<\/value>/g' "$yarn_site"
    echo -e "${GREEN}✅ Updated YARN ResourceManager hostname to localhost${NC}"
    
    echo -e "${GREEN}✅ Conversion to single-node setup completed${NC}"
    echo "Restart the cluster to apply changes"
    echo ""
}

show_status() {
    echo -e "${BLUE}📊 DETAILED CLUSTER STATUS:${NC}"
    echo "=========================="
    
    # Show configured nodes
    list_nodes
    
    echo ""
    echo -e "${BLUE}🔍 Configuration Analysis:${NC}"
    
    # Check core-site.xml
    local fs_default=$(grep -A1 "fs.defaultFS" "$HADOOP_CONF_DIR/core-site.xml" | grep "<value>" | sed 's/.*<value>\(.*\)<\/value>.*/\1/')
    echo "  • Default FS: $fs_default"
    
    # Check yarn-site.xml
    local rm_hostname=$(grep -A1 "yarn.resourcemanager.hostname" "$HADOOP_CONF_DIR/yarn-site.xml" | grep "<value>" | sed 's/.*<value>\(.*\)<\/value>.*/\1/')
    echo "  • ResourceManager: $rm_hostname"
    
    # Count nodes in workers file
    local worker_count=$(grep -v '^#' "$WORKERS_FILE" | grep -v '^$' | wc -l | tr -d ' ')
    echo "  • Configured workers: $worker_count"
    
    echo ""
    echo -e "${BLUE}🚀 Service Status:${NC}"
    ./cluster-status.sh
}

restore_backup() {
    echo -e "${YELLOW}📦 Available backups:${NC}"
    ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || {
        echo -e "${RED}❌ No backups found${NC}"
        return 1
    }
    
    echo ""
    echo -e "${YELLOW}Enter backup filename to restore (without path):${NC}"
    read backup_file
    
    if [ -f "$BACKUP_DIR/$backup_file" ]; then
        echo -e "${YELLOW}🔄 Restoring backup: $backup_file${NC}"
        
        # Backup current config before restore
        backup_config
        
        # Restore
        tar -xzf "$BACKUP_DIR/$backup_file" -C "$HADOOP_CONF_DIR"
        echo -e "${GREEN}✅ Backup restored successfully${NC}"
        echo "Restart the cluster to apply changes"
    else
        echo -e "${RED}❌ Backup file not found${NC}"
        return 1
    fi
}

# Main script logic
case "$1" in
    list)
        print_header
        list_nodes
        ;;
    add)
        print_header
        add_node "$2"
        ;;
    remove)
        print_header
        remove_node "$2"
        ;;
    decommission)
        print_header
        decommission_node "$2"
        ;;
    recommission)
        print_header
        recommission_node "$2"
        ;;
    status)
        print_header
        show_status
        ;;
    backup)
        print_header
        backup_config
        ;;
    restore)
        print_header
        restore_backup
        ;;
    convert-multi)
        print_header
        convert_to_multinode
        ;;
    convert-single)
        print_header
        convert_to_singlenode
        ;;
    help|--help|-h)
        print_header
        print_usage
        ;;
    *)
        print_header
        echo -e "${RED}❌ Invalid command: $1${NC}"
        echo ""
        print_usage
        exit 1
        ;;
esac
