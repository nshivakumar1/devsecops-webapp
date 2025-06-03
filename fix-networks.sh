#!/bin/bash

echo "🕸️  FIXING DOCKER NETWORKS FOR DEVSECOPS"
echo "======================================="

# Step 1: Find the actual monitoring network
echo "📡 Finding monitoring network..."
MONITORING_NETWORK=$(docker network ls --format "{{.Name}}" | grep monitoring | head -1)

if [ -z "$MONITORING_NETWORK" ]; then
    echo "❌ No monitoring network found. Creating one..."
    docker network create monitoring_default
    MONITORING_NETWORK="monitoring_default"
fi

echo "✅ Using network: $MONITORING_NETWORK"

# Step 2: Connect webapp to monitoring network
echo "🌐 Connecting webapp to monitoring network..."
docker network connect $MONITORING_NETWORK devsecops-webapp 2>/dev/null || echo "Webapp already connected or doesn't exist"

# Step 3: Connect Jenkins to monitoring network  
echo "🔧 Connecting Jenkins to monitoring network..."
docker network connect $MONITORING_NETWORK jenkins 2>/dev/null || echo "Jenkins already connected or doesn't exist"

# Step 4: Update Prometheus config to use the correct target
echo "📊 Updating Prometheus configuration..."
docker exec prometheus sh -c "cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - \"alert.rules.yml\"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'webapp'
    static_configs:
      - targets: ['devsecops-webapp:3000']
    scrape_interval: 5s
    metrics_path: '/metrics'
    
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
EOF"

# Step 5: Reload Prometheus config
echo "🔄 Reloading Prometheus configuration..."
curl -X POST http://localhost:9090/-/reload 2>/dev/null || echo "Prometheus reload failed, restarting container..."
docker restart prometheus

# Step 6: Wait and verify
echo "⏳ Waiting for services to be ready..."
sleep 20

# Step 7: Show final status
echo ""
echo "🎯 FINAL STATUS"
echo "==============="

echo "📋 Network connections:"
docker network inspect $MONITORING_NETWORK --format='{{range .Containers}}✅ {{.Name}} - {{.IPv4Address}}{{printf "\n"}}{{end}}'

echo ""
echo "🧪 Testing services:"

# Test webapp
if curl -s http://localhost:3000/health > /dev/null; then
    echo "✅ Webapp: http://localhost:3000 - UP"
else
    echo "❌ Webapp: http://localhost:3000 - DOWN"
fi

# Test Prometheus
if curl -s http://localhost:9090/-/healthy > /dev/null; then
    echo "✅ Prometheus: http://localhost:9090 - UP"
else
    echo "❌ Prometheus: http://localhost:9090 - DOWN"
fi

# Test Prometheus targets
echo ""
echo "🎯 Prometheus targets status:"
curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job): \(.health)"' 2>/dev/null || echo "Could not fetch targets"

echo ""
echo "🚀 NETWORK FIX COMPLETE!"
echo "Access Prometheus targets: http://localhost:9090/targets"