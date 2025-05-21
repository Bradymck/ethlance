#!/bin/bash

# Exit on any error
set -e

echo "===== Ethlance Setup Script ====="

# Function to check if a command is available
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "ERROR: Required command '$1' not found."
    echo "Please install $2 before continuing."
    exit 1
  fi
}

# Check essential prerequisites
echo "Checking prerequisites..."
check_command "docker" "Docker"
check_command "docker-compose" "Docker Compose"
check_command "node" "Node.js"
check_command "npm" "npm"

# Create logs directory
mkdir -p logs
echo "Created logs directory."

# Create config directory if it doesn't exist
mkdir -p config

# Create server configuration file if it doesn't exist
if [ ! -f config/server-config-dev.edn ]; then
  echo "Creating server configuration file..."
  cat > config/server-config-dev.edn << 'EOL'
{:district/db {:adapter "postgresql"
                  :database-name "postgres"
                  :username "postgres"
                  :password "postgres"
                  :server-name "localhost"
                  :port-number 5432}
 :ipfs {:host "localhost"
       :gateway "http://localhost:8080/ipfs/"
       :endpoint "http://localhost:5001"}
 :web3 {:url "http://localhost:8545"}
 :logging {:level :info
          :console? true}
 :graphql {:port 6300
          :path "/graphql"
          :graphiql true
          :resources-opts {:dev-config {:schema-path "./schemas/ethlance.graphql"}}}
 :web3-events {:retry-interval 1000
              :try-interval 1000
              :log-events-task-opts {:disable-using-graph-listening? true}}}
EOL
fi

# Create UI configuration file if it doesn't exist
if [ ! -f config/ui-config-dev.edn ]; then
  echo "Creating UI configuration file..."
  cat > config/ui-config-dev.edn << 'EOL'
{:web3-provider "ws://localhost:8545"
 :graphql-url "http://localhost:6300/graphql"
 :ipfs-gateway "http://localhost:8080/ipfs/"}
EOL
fi

echo "Installing dependencies..."
npm install

echo "Installing LESS compiler if not present..."
if ! command -v lessc &> /dev/null; then
    npm install -g less
fi

echo "Setting up infrastructure..."
docker-compose -f docker-compose-simple.yml up -d

echo "Waiting for infrastructure to be ready..."
sleep 10

echo "Testing connection to Ganache..."
if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://localhost:8545 > /dev/null; then
  echo "ERROR: Cannot connect to Ganache at http://localhost:8545"
  echo "Please check that Docker containers are running properly."
  exit 1
fi

echo "Deploying smart contracts..."
npx truffle migrate --network ganache --reset

echo "Compiling CSS..."
bb compile-css

echo "Creating config-server.js if it doesn't exist..."
if [ ! -f server/config-server.js ]; then
  cat > server/config-server.js << 'EOL'
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
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
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
  console.log(`Configuration server running at http://localhost:${PORT}`);
});
EOL
fi

# Fix any d0x-vm references
echo "Updating configuration to use localhost instead of d0x-vm..."
find ui/src -type f -name "*.cljs" -exec sed -i '' 's/d0x-vm/localhost/g' {} \;

echo "Setup complete! Use start.sh to launch Ethlance."
