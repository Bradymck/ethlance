const http = require('http');

// Configuration to serve
const getConfig = () => {
  return {
    "web3-provider": "ws://localhost:8545",
    "graphql-url": "http://localhost:6300/graphql",
    "ipfs-gateway": "http://localhost:8080/ipfs/"
  };
};

// Create a simple HTTP server
const server = http.createServer((req, res) => {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS, POST');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }
  
  // Handle POST requests to /graphql as a workaround
  if (req.method === 'POST' && req.url === '/graphql') {
    let body = '';
    
    req.on('data', (chunk) => {
      body += chunk.toString();
    });
    
    req.on('end', () => {
      try {
        // This is a mock GraphQL response
        res.setHeader('Content-Type', 'application/json');
        res.writeHead(200);
        res.end(JSON.stringify({ data: {} }));
      } catch (error) {
        console.error('Error handling GraphQL request:', error);
        res.writeHead(500);
        res.end(JSON.stringify({ errors: [{ message: 'Internal Server Error' }] }));
      }
    });
    return;
  }
  
  // Only handle GET requests to /config
  if (req.method === 'GET' && req.url === '/config') {
    try {
      const config = getConfig();
      res.setHeader('Content-Type', 'application/json');
      res.writeHead(200);
      res.end(JSON.stringify(config));
    } catch (error) {
      console.error('Error serving configuration:', error);
      res.writeHead(500);
      res.end(JSON.stringify({ error: 'Internal Server Error' }));
    }
  } else if (req.method === 'GET' && req.url === '/graphql') {
    res.setHeader('Content-Type', 'application/json');
    res.writeHead(200);
    res.end(JSON.stringify({ data: {} }));
  } else {
    res.writeHead(404);
    res.end(JSON.stringify({ error: 'Not Found' }));
  }
});

const PORT = 6300;
server.listen(PORT, () => {
  console.log(`Configuration and GraphQL mock server running at http://localhost:${PORT}`);
});
