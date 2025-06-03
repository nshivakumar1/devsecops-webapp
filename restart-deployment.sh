#!/bin/bash

echo "🧹 COMPLETE DEVSECOPS DEPLOYMENT RESTART"
echo "=========================================="

# Step 1: Stop all running containers
echo "📛 Stopping all containers..."
docker stop $(docker ps -q) 2>/dev/null || echo "No containers to stop"

# Step 2: Remove project-related containers
echo "🗑️  Removing DevSecOps containers..."
docker rm -f prometheus grafana cadvisor node-exporter jenkins devsecops-webapp 2>/dev/null || echo "Some containers already removed"

# Step 3: Remove project networks
echo "🕸️  Removing networks..."
docker network rm monitoring_monitoring_default monitoring_default 2>/dev/null || echo "Networks already removed"

# Step 4: Clean up volumes (optional - uncomment if you want fresh data)
# echo "💾 Cleaning volumes..."
# docker volume rm monitoring_prometheus_data monitoring_grafana_data jenkins_jenkins_data 2>/dev/null || echo "Volumes already removed"

# Step 5: Clean up unused resources
echo "🧽 Cleaning up unused resources..."
docker system prune -f

echo "✅ Cleanup complete!"
echo ""
echo "🚀 STARTING DEPLOYMENT..."
echo "========================="

# Step 6: Start monitoring stack first
echo "📊 Starting monitoring stack..."
cd monitoring
docker-compose -f docker-compose.monitoring.yml up -d

# Wait for monitoring services to be ready
echo "⏳ Waiting for monitoring services to start..."
sleep 30

# Step 7: Verify monitoring stack
echo "🔍 Checking monitoring services..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(prometheus|grafana|cadvisor|node-exporter)"

# Step 8: Check network creation
echo "🕸️  Verifying network creation..."
docker network ls | grep monitoring

# Step 9: Start webapp
echo "🌐 Starting webapp..."
cd ..
docker-compose up --build -d

# Step 10: Start Jenkins
echo "🔧 Starting Jenkins..."
cd jenkins
docker-compose -f docker-compose.jenkins.yml up -d

# Step 11: Wait for everything to be ready
echo "⏳ Waiting for all services to be ready..."
sleep 45

# Step 12: Final verification
echo ""
echo "🎯 DEPLOYMENT STATUS"
echo "==================="

echo "📋 All containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🕸️  Network connections:"
docker network inspect monitoring_monitoring_default --format='{{range .Containers}}✅ {{.Name}} - {{.IPv4Address}}{{printf "\n"}}{{end}}' 2>/dev/null || echo "❌ Network not found"

echo ""
echo "🧪 TESTING SERVICES..."
echo "====================="

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

# Test Grafana
if curl -s http://localhost:3001/api/health > /dev/null; then
    echo "✅ Grafana: http://localhost:3001 - UP"
else
    echo "❌ Grafana: http://localhost:3001 - DOWN"
fi

# Test cAdvisor
if curl -s http://localhost:8081/healthz > /dev/null; then
    echo "✅ cAdvisor: http://localhost:8081 - UP"
else
    echo "❌ cAdvisor: http://localhost:8081 - DOWN"
fi

# Test Jenkins (may take longer to start)
if curl -s http://localhost:8080 > /dev/null; then
    echo "✅ Jenkins: http://localhost:8080 - UP"
else
    echo "⏳ Jenkins: http://localhost:8080 - STARTING (may take 2-3 minutes)"
fi

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "======================"
echo "📊 Access your services:"
echo "   • Webapp:     http://localhost:3000"
echo "   • Grafana:    http://localhost:3001 (admin/admin123)"
echo "   • Prometheus: http://localhost:9090"
echo "   • cAdvisor:   http://localhost:8081"
echo "   • Jenkins:    http://localhost:8080"
echo ""
echo "🔑 To get Jenkins password:"
echo "   docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
echo ""
echo "📈 To generate traffic for metrics:"
echo "   while true; do curl -s http://localhost:3000/api/time > /dev/null; sleep 2; done"