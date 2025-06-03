#!/bin/bash

echo "🛑 DEVSECOPS DEPLOYMENT SHUTDOWN"
echo "================================"

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CONTAINERS=("devsecops-webapp" "jenkins" "prometheus" "grafana" "cadvisor" "node-exporter")
NETWORKS=("devsecops-webapp_monitoring_default" "monitoring_monitoring_default" "monitoring_default")
VOLUMES=("prometheus_data" "grafana_data" "jenkins_data" "monitoring_prometheus_data" "monitoring_grafana_data" "jenkins_jenkins_data")

# Default values
FORCE_STOP=false
REMOVE_VOLUMES=false
REMOVE_IMAGES=false
CLEANUP_SYSTEM=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_STOP=true
            echo -e "${YELLOW}⚠️ Force stop mode enabled${NC}"
            shift
            ;;
        -v|--volumes)
            REMOVE_VOLUMES=true
            echo -e "${YELLOW}⚠️ Volume removal enabled${NC}"
            shift
            ;;
        -i|--images)
            REMOVE_IMAGES=true
            echo -e "${YELLOW}⚠️ Image removal enabled${NC}"
            shift
            ;;
        -c|--cleanup)
            CLEANUP_SYSTEM=true
            echo -e "${YELLOW}⚠️ System cleanup enabled${NC}"
            shift
            ;;
        --all)
            FORCE_STOP=true
            REMOVE_VOLUMES=true
            REMOVE_IMAGES=true
            CLEANUP_SYSTEM=true
            echo -e "${RED}🚨 COMPLETE CLEANUP MODE ENABLED${NC}"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -f, --force     Force stop containers (docker kill)"
            echo "  -v, --volumes   Remove Docker volumes (WARNING: Data loss!)"
            echo "  -i, --images    Remove Docker images"
            echo "  -c, --cleanup   System cleanup (prune unused resources)"
            echo "      --all       Enable all cleanup options"
            echo "  -h, --help      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Graceful shutdown"
            echo "  $0 --force           # Force stop all containers"
            echo "  $0 --all             # Complete cleanup (DESTRUCTIVE)"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Safety confirmation for destructive operations
if [[ "$REMOVE_VOLUMES" == true ]] || [[ "$REMOVE_IMAGES" == true ]] || [[ "$CLEANUP_SYSTEM" == true ]]; then
    echo -e "${RED}🚨 WARNING: DESTRUCTIVE OPERATIONS ENABLED${NC}"
    echo -e "${YELLOW}This will permanently delete:${NC}"
    [[ "$REMOVE_VOLUMES" == true ]] && echo "  • Docker volumes (all monitoring data will be lost)"
    [[ "$REMOVE_IMAGES" == true ]] && echo "  • Docker images (will need to rebuild)"
    [[ "$CLEANUP_SYSTEM" == true ]] && echo "  • Unused Docker resources"
    echo ""
    echo -e "${BLUE}Type 'YES' to confirm destructive operations:${NC}"
    read -p "" CONFIRM
    if [[ "$CONFIRM" != "YES" ]]; then
        echo -e "${GREEN}✅ Aborting destructive operations. Only stopping containers.${NC}"
        REMOVE_VOLUMES=false
        REMOVE_IMAGES=false
        CLEANUP_SYSTEM=false
    fi
fi

# Function to stop containers gracefully
stop_containers_graceful() {
    echo -e "\n${BLUE}🔄 Step 1: Graceful Container Shutdown${NC}"
    echo "======================================"
    
    local stopped_count=0
    local total_count=${#CONTAINERS[@]}
    
    for container in "${CONTAINERS[@]}"; do
        if docker ps -q -f name="^${container}$" | grep -q .; then
            echo -e "${CYAN}🛑 Stopping ${container}...${NC}"
            if docker stop "$container" 2>/dev/null; then
                echo -e "${GREEN}  ✅ ${container} stopped gracefully${NC}"
                ((stopped_count++))
            else
                echo -e "${RED}  ❌ Failed to stop ${container} gracefully${NC}"
            fi
        else
            echo -e "${YELLOW}  ⚠️ ${container} not running${NC}"
        fi
    done
    
    echo -e "${GREEN}📊 Stopped ${stopped_count}/${total_count} containers gracefully${NC}"
}

# Function to force stop containers
stop_containers_force() {
    echo -e "\n${RED}⚡ Step 1b: Force Stop Containers${NC}"
    echo "================================="
    
    local killed_count=0
    
    for container in "${CONTAINERS[@]}"; do
        if docker ps -q -f name="^${container}$" | grep -q .; then
            echo -e "${RED}💀 Force killing ${container}...${NC}"
            if docker kill "$container" 2>/dev/null; then
                echo -e "${GREEN}  ✅ ${container} killed${NC}"
                ((killed_count++))
            else
                echo -e "${RED}  ❌ Failed to kill ${container}${NC}"
            fi
        fi
    done
    
    [[ $killed_count -gt 0 ]] && echo -e "${GREEN}📊 Force stopped ${killed_count} containers${NC}"
}

# Function to remove containers
remove_containers() {
    echo -e "\n${PURPLE}🗑️ Step 2: Removing Containers${NC}"
    echo "==============================="
    
    local removed_count=0
    
    for container in "${CONTAINERS[@]}"; do
        if docker ps -aq -f name="^${container}$" | grep -q .; then
            echo -e "${PURPLE}🗑️ Removing ${container}...${NC}"
            if docker rm "$container" 2>/dev/null; then
                echo -e "${GREEN}  ✅ ${container} removed${NC}"
                ((removed_count++))
            else
                echo -e "${RED}  ❌ Failed to remove ${container}${NC}"
            fi
        else
            echo -e "${YELLOW}  ⚠️ ${container} not found${NC}"
        fi
    done
    
    echo -e "${GREEN}📊 Removed ${removed_count} containers${NC}"
}

# Function to remove networks
remove_networks() {
    echo -e "\n${CYAN}🕸️ Step 3: Removing Networks${NC}"
    echo "============================="
    
    local removed_count=0
    
    for network in "${NETWORKS[@]}"; do
        if docker network ls -q -f name="^${network}$" | grep -q .; then
            echo -e "${CYAN}🕸️ Removing network ${network}...${NC}"
            if docker network rm "$network" 2>/dev/null; then
                echo -e "${GREEN}  ✅ Network ${network} removed${NC}"
                ((removed_count++))
            else
                echo -e "${RED}  ❌ Failed to remove network ${network}${NC}"
                echo -e "${YELLOW}     (Network may still be in use by other containers)${NC}"
            fi
        else
            echo -e "${YELLOW}  ⚠️ Network ${network} not found${NC}"
        fi
    done
    
    echo -e "${GREEN}📊 Removed ${removed_count} networks${NC}"
}

# Function to remove volumes
remove_volumes() {
    echo -e "\n${RED}💾 Step 4: Removing Volumes (DATA LOSS!)${NC}"
    echo "========================================="
    
    local removed_count=0
    
    for volume in "${VOLUMES[@]}"; do
        if docker volume ls -q -f name="^${volume}$" | grep -q .; then
            echo -e "${RED}💾 Removing volume ${volume}...${NC}"
            if docker volume rm "$volume" 2>/dev/null; then
                echo -e "${GREEN}  ✅ Volume ${volume} removed${NC}"
                ((removed_count++))
            else
                echo -e "${RED}  ❌ Failed to remove volume ${volume}${NC}"
                echo -e "${YELLOW}     (Volume may still be in use)${NC}"
            fi
        else
            echo -e "${YELLOW}  ⚠️ Volume ${volume} not found${NC}"
        fi
    done
    
    echo -e "${GREEN}📊 Removed ${removed_count} volumes${NC}"
    [[ $removed_count -gt 0 ]] && echo -e "${RED}⚠️ All monitoring data has been permanently deleted!${NC}"
}

# Function to remove images
remove_images() {
    echo -e "\n${PURPLE}🖼️ Step 5: Removing Images${NC}"
    echo "==========================="
    
    local images_to_remove=(
        "devsecops-webapp-webapp"
        "devsecops-webapp"
        "jenkins/jenkins:lts"
        "prom/prometheus:latest"
        "grafana/grafana:latest"
        "prom/node-exporter:latest"
        "gcr.io/cadvisor/cadvisor:latest"
    )
    
    local removed_count=0
    
    for image in "${images_to_remove[@]}"; do
        if docker images -q "$image" | grep -q .; then
            echo -e "${PURPLE}🖼️ Removing image ${image}...${NC}"
            if docker rmi "$image" 2>/dev/null; then
                echo -e "${GREEN}  ✅ Image ${image} removed${NC}"
                ((removed_count++))
            else
                echo -e "${RED}  ❌ Failed to remove image ${image}${NC}"
            fi
        else
            echo -e "${YELLOW}  ⚠️ Image ${image} not found${NC}"
        fi
    done
    
    echo -e "${GREEN}📊 Removed ${removed_count} images${NC}"
}

# Function to cleanup system
cleanup_system() {
    echo -e "\n${CYAN}🧹 Step 6: System Cleanup${NC}"
    echo "========================="
    
    echo -e "${CYAN}🧹 Removing unused containers...${NC}"
    docker container prune -f
    
    echo -e "${CYAN}🧹 Removing unused networks...${NC}"
    docker network prune -f
    
    echo -e "${CYAN}🧹 Removing unused images...${NC}"
    docker image prune -f
    
    if [[ "$REMOVE_VOLUMES" == false ]]; then
        echo -e "${CYAN}🧹 Removing unused volumes...${NC}"
        docker volume prune -f
    fi
    
    echo -e "${GREEN}✅ System cleanup completed${NC}"
}

# Function to show status
show_status() {
    echo -e "\n${BLUE}📊 Current Status${NC}"
    echo "================="
    
    echo -e "${CYAN}Running containers:${NC}"
    local running_containers=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "($(IFS='|'; echo "${CONTAINERS[*]}"))" || echo "None")
    echo "$running_containers"
    
    echo -e "\n${CYAN}Existing volumes:${NC}"
    local existing_volumes=$(docker volume ls --format "table {{.Name}}\t{{Driver}}" | grep -E "($(IFS='|'; echo "${VOLUMES[*]}"))" || echo "None")
    echo "$existing_volumes"
    
    echo -e "\n${CYAN}Existing networks:${NC}"
    local existing_networks=$(docker network ls --format "table {{.Name}}\t{{Driver}}" | grep -E "($(IFS='|'; echo "${NETWORKS[*]}"))" || echo "None")
    echo "$existing_networks"
}

# Function to show final summary
show_summary() {
    echo -e "\n${GREEN}🎯 SHUTDOWN SUMMARY${NC}"
    echo "==================="
    
    local remaining_containers=$(docker ps -q --filter "name=$(IFS='|'; echo "${CONTAINERS[*]}")" | wc -l)
    local remaining_volumes=$(docker volume ls -q --filter "name=$(IFS='|'; echo "${VOLUMES[*]}")" | wc -l)
    local remaining_networks=$(docker network ls -q --filter "name=$(IFS='|'; echo "${NETWORKS[*]}")" | wc -l)
    
    echo -e "${BLUE}Final Status:${NC}"
    echo "  • Containers remaining: $remaining_containers"
    echo "  • Volumes remaining: $remaining_volumes"
    echo "  • Networks remaining: $remaining_networks"
    
    if [[ $remaining_containers -eq 0 ]]; then
        echo -e "${GREEN}✅ All DevSecOps containers stopped${NC}"
    else
        echo -e "${YELLOW}⚠️ Some containers may still be running${NC}"
    fi
    
    echo -e "\n${BLUE}To restart the deployment:${NC}"
    echo "  ./restart_deployment.sh"
    
    echo -e "\n${GREEN}🎉 Shutdown completed!${NC}"
}

# Main execution
echo -e "${BLUE}🔍 Checking current deployment status...${NC}"
show_status

echo -e "\n${YELLOW}⏳ Starting shutdown sequence...${NC}"

# Step 1: Stop containers
if [[ "$FORCE_STOP" == true ]]; then
    stop_containers_force
else
    stop_containers_graceful
    
    # Check if any containers are still running and offer force stop
    local still_running=$(docker ps -q --filter "name=$(IFS='|'; echo "${CONTAINERS[*]}")" | wc -l)
    if [[ $still_running -gt 0 ]]; then
        echo -e "\n${YELLOW}⚠️ Some containers are still running. Force stop them? (y/N):${NC}"
        read -p "" FORCE_CONFIRM
        if [[ "$FORCE_CONFIRM" =~ ^[Yy]$ ]]; then
            stop_containers_force
        fi
    fi
fi

# Step 2: Remove containers
remove_containers

# Step 3: Remove networks
remove_networks

# Step 4: Remove volumes (if requested)
if [[ "$REMOVE_VOLUMES" == true ]]; then
    remove_volumes
fi

# Step 5: Remove images (if requested)
if [[ "$REMOVE_IMAGES" == true ]]; then
    remove_images
fi

# Step 6: System cleanup (if requested)
if [[ "$CLEANUP_SYSTEM" == true ]]; then
    cleanup_system
fi

# Final status and summary
show_summary

# Exit with appropriate code
local remaining_containers=$(docker ps -q --filter "name=$(IFS='|'; echo "${CONTAINERS[*]}")" | wc -l)
if [[ $remaining_containers -eq 0 ]]; then
    exit 0
else
    echo -e "${RED}⚠️ Some containers may still be running. Check manually if needed.${NC}"
    exit 1
fi