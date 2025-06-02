#!/bin/bash

# Hadoop Cluster Control Script
# Usage: ./hadoop-control.sh [start|stop|restart|status]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
HADOOP_HOME="$SCRIPT_DIR/hadoop"

# Check if Hadoop is installed
if [ ! -d "$HADOOP_HOME" ]; then
    echo -e "${RED}❌ Error: Hadoop not found at $HADOOP_HOME${NC}"
    echo -e "${YELLOW}💡 Please run the installation first following README.md${NC}"
    exit 1
fi

# Function to print colored output
print_status() {
    echo -e "${BLUE}🔧 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to check if a process is running
check_process() {
    local process_name="$1"
    if jps | grep -q "$process_name"; then
        return 0  # Process is running
    else
        return 1  # Process is not running
    fi
}

# Function to start Hadoop services
start_hadoop() {
    print_status "Starting Hadoop Cluster..."
    
    # Check if services are already running
    if check_process "NameNode" && check_process "DataNode"; then
        print_warning "HDFS services are already running"
    else
        print_status "Starting HDFS services..."
        $HADOOP_HOME/sbin/start-dfs.sh
        
        # Wait a moment for services to start
        sleep 3
        
        if check_process "NameNode" && check_process "DataNode"; then
            print_success "HDFS services started successfully"
        else
            print_error "Failed to start HDFS services"
        fi
    fi
    
    # Start YARN services
    if check_process "ResourceManager" && check_process "NodeManager"; then
        print_warning "YARN services are already running"
    else
        print_status "Starting YARN services..."
        $HADOOP_HOME/sbin/start-yarn.sh
        
        # Wait a moment for services to start
        sleep 3
        
        if check_process "ResourceManager" && check_process "NodeManager"; then
            print_success "YARN services started successfully"
        else
            print_error "Failed to start YARN services"
        fi
    fi
    
    echo ""
    print_success "Hadoop cluster startup completed!"
    
    # Show running services
    show_status
}

# Function to stop Hadoop services
stop_hadoop() {
    print_status "Stopping Hadoop Cluster..."
    
    # Stop YARN services
    if check_process "ResourceManager" || check_process "NodeManager"; then
        print_status "Stopping YARN services..."
        $HADOOP_HOME/sbin/stop-yarn.sh
        sleep 2
        print_success "YARN services stopped"
    else
        print_warning "YARN services were not running"
    fi
    
    # Stop HDFS services
    if check_process "NameNode" || check_process "DataNode"; then
        print_status "Stopping HDFS services..."
        $HADOOP_HOME/sbin/stop-dfs.sh
        sleep 2
        print_success "HDFS services stopped"
    else
        print_warning "HDFS services were not running"
    fi
    
    echo ""
    print_success "Hadoop cluster shutdown completed!"
    
    # Show final status
    show_status
}

# Function to restart Hadoop services
restart_hadoop() {
    print_status "Restarting Hadoop Cluster..."
    stop_hadoop
    echo ""
    sleep 2
    start_hadoop
}

# Function to show cluster status
show_status() {
    print_status "Checking Hadoop Cluster Status..."
    echo ""
    
    # Check Java processes
    local running_services=()
    local stopped_services=()
    
    # List of expected services
    local services=("NameNode" "DataNode" "SecondaryNameNode" "ResourceManager" "NodeManager")
    
    for service in "${services[@]}"; do
        if check_process "$service"; then
            running_services+=("$service")
        else
            stopped_services+=("$service")
        fi
    done
    
    # Display running services
    if [ ${#running_services[@]} -gt 0 ]; then
        echo -e "${GREEN}🟢 Running Services:${NC}"
        for service in "${running_services[@]}"; do
            echo -e "   ✅ $service"
        done
    fi
    
    # Display stopped services
    if [ ${#stopped_services[@]} -gt 0 ]; then
        echo -e "${RED}🔴 Stopped Services:${NC}"
        for service in "${stopped_services[@]}"; do
            echo -e "   ❌ $service"
        done
    fi
    
    echo ""
    
    # Overall status
    if [ ${#running_services[@]} -eq 5 ]; then
        print_success "Cluster Status: FULLY OPERATIONAL (${#running_services[@]}/5 services running)"
        echo ""
        echo -e "${BLUE}🌐 Web Interfaces:${NC}"
        echo -e "   📊 NameNode UI:      http://localhost:9870"
        echo -e "   📈 ResourceManager:  http://localhost:8088"
        echo -e "   💾 DataNode UI:      http://localhost:9864"
        echo -e "   📋 NodeManager UI:   http://localhost:8042"
    elif [ ${#running_services[@]} -gt 0 ]; then
        print_warning "Cluster Status: PARTIALLY RUNNING (${#running_services[@]}/5 services running)"
    else
        print_error "Cluster Status: STOPPED (0/5 services running)"
    fi
}

# Function to show usage
show_usage() {
    echo -e "${BLUE}Hadoop Cluster Control Script${NC}"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start    Start all Hadoop services (HDFS + YARN)"
    echo "  stop     Stop all Hadoop services"
    echo "  restart  Stop and start all services"
    echo "  status   Show current cluster status"
    echo "  help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start     # Start the cluster"
    echo "  $0 stop      # Stop the cluster"
    echo "  $0 status    # Check what's running"
    echo ""
}

# Main script logic
case "${1:-help}" in
    "start")
        start_hadoop
        ;;
    "stop")
        stop_hadoop
        ;;
    "restart")
        restart_hadoop
        ;;
    "status")
        show_status
        ;;
    "help"|"--help"|"-h")
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
