const express = require('express');
const client = require('prom-client');
const path = require('path');

const app = express();
const port = 3000;

// Prometheus metrics
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route'],
  registers: [register]
});

// Middleware for metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestsTotal.labels(req.method, req.route?.path || req.path, res.statusCode).inc();
    httpRequestDuration.labels(req.method, req.route?.path || req.path).observe(duration);
  });
  
  next();
});

// Serve static files
app.use(express.static('public'));

// Dynamic content routes
app.get('/api/time', (req, res) => {
  res.json({ 
    timestamp: new Date().toISOString(),
    server_time: new Date().toLocaleString(),
    uptime: process.uptime()
  });
});

app.get('/api/stats', (req, res) => {
  res.json({
    memory_usage: process.memoryUsage(),
    cpu_usage: process.cpuUsage(),
    version: process.version,
    platform: process.platform
  });
});

app.get('/api/random', (req, res) => {
  res.json({
    random_number: Math.floor(Math.random() * 1000),
    quote: "DevSecOps in action!",
    generated_at: new Date().toISOString()
  });
});

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Main route
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(port, '0.0.0.0', () => {
  console.log(`DevSecOps webapp running on port ${port}`);
});