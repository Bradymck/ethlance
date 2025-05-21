#!/bin/bash

# Exit on error
set -e

echo "===== Ethlance Setup Script ====="

# Function to check if a command is available
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "ERROR: Required command '$1' not found."
    echo "Attempting to install $2..."
    case "$1" in
      docker)
        if [[ "$OSTYPE" == "darwin"* ]]; then
          echo "Please install Docker Desktop from https://www.docker.com/products/docker-desktop/"
          echo "After installing, run this script again."
          exit 1
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
          sudo apt-get update
          sudo apt-get install -y docker.io docker-compose
          sudo systemctl start docker
          sudo systemctl enable docker
          sudo usermod -aG docker $USER
          echo "Docker installed. You may need to log out and back in for group changes to take effect."
          echo "After logging back in, run this script again."
          exit 1
        else
          echo "Please install Docker manually for your OS."
          exit 1
        fi
        ;;
      node)
        setup_nodejs
        ;;
      npm)
        setup_nodejs
        ;;
      *)
        echo "Please install $2 before continuing."
        exit 1
        ;;
    esac
  fi
}

# Function to check and handle port conflicts
check_port_usage() {
  local port=$1
  local service=$2
  if lsof -i :$port -t >/dev/null 2>&1; then
    echo "Port $port is already in use by another process."
    echo "Attempting to free the port for $service..."
    pid=$(lsof -i :$port -t)
    if [ "$port" == "3000" ]; then
      echo "Port 3000 is required. Stopping process $pid using port $port..."
      kill -15 $pid 2>/dev/null || kill -9 $pid 2>/dev/null
      sleep 2
    else
      # For other ports, try to modify the port in configuration
      echo "Modifying configuration to use a different port."
      return 1
    fi
  fi
  return 0
}

# Function to ensure Docker is running
ensure_docker_running() {
  if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon is not running. Attempting to start it..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      echo "Attempting to start Docker Desktop..."
      open -a Docker
      # Wait for Docker to start
      echo "Waiting for Docker to start..."
      for i in {1..30}; do
        if docker info >/dev/null 2>&1; then
          echo "Docker is now running."
          return 0
        fi
        echo -n "."
        sleep 2
      done
      echo "\nTimeout waiting for Docker to start. Please start Docker Desktop manually."
      exit 1
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      echo "Attempting to start Docker service..."
      sudo systemctl start docker
      sleep 5
      if ! docker info >/dev/null 2>&1; then
        echo "Failed to start Docker service. Please start it manually."
        exit 1
      fi
      echo "Docker service started successfully."
    else
      echo "Please start Docker manually and run the script again."
      exit 1
    fi
  fi
}

# Function to set up Node.js properly
setup_nodejs() {
  required_version="16"
  
  # Check if nvm is installed
  if command -v nvm >/dev/null 2>&1; then
    echo "Using nvm to manage Node.js version..."
    nvm install $required_version
    nvm use $required_version
  elif command -v node >/dev/null 2>&1; then
    # Check node version
    current_version=$(node -v | cut -d 'v' -f2 | cut -d'.' -f1)
    if [ "$current_version" -lt "$required_version" ]; then
      echo "Node.js version $current_version is installed, but version $required_version+ is required."
      echo "Installing nvm to manage Node.js versions..."
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
      nvm install $required_version
      nvm use $required_version
    else
      echo "Node.js version $current_version is installed and meets requirements."
    fi
  else
    echo "Node.js is not installed. Installing via nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    nvm install $required_version
    nvm use $required_version
  fi
}

# Function to deploy contracts with retry logic
deploy_contracts() {
  attempts=0
  max_attempts=3
  
  while [ $attempts -lt $max_attempts ]; do
    echo "Attempting to deploy smart contracts (attempt $((attempts+1))/$max_attempts)..."
    if npx truffle migrate --network ganache --reset; then
      echo "Smart contracts deployed successfully."
      return 0
    else
      attempts=$((attempts+1))
      if [ $attempts -lt $max_attempts ]; then
        echo "Contract deployment failed. Restarting Ganache and retrying in 5 seconds..."
        docker-compose -f docker-compose-simple.yml restart ganache
        sleep 5
      fi
    fi
  done
  
  echo "Failed to deploy contracts after $max_attempts attempts."
  echo "Do you want to continue without contract deployment? (y/n)"
  read -r response
  if [[ "$response" != "y" ]]; then
    echo "Exiting setup."
    exit 1
  fi
  return 1
}

# Function to compile CSS with fallback
compile_css() {
  echo "Compiling CSS..."
  if command -v bb >/dev/null 2>&1; then
    bb compile-css
  else
    echo "Installing Babashka for CSS compilation..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      brew install borkdude/brew/babashka
    else
      curl -sLO https://github.com/babashka/babashka/releases/download/v0.8.156/babashka-0.8.156-linux-amd64.tar.gz
      tar -xzf babashka-0.8.156-linux-amd64.tar.gz
      sudo mv bb /usr/local/bin
    fi
    bb compile-css
  fi
}

# Check essential prerequisites
echo "Checking prerequisites..."
check_command "docker" "Docker"
check_command "docker-compose" "Docker Compose"

# Ensure Docker is running
ensure_docker_running

# Setup Node.js if needed
setup_nodejs

# Create logs directory
mkdir -p logs
echo "Created logs directory."

# Create config directory if it doesn't exist
mkdir -p config

# Check critical ports before starting services
echo "Checking port availability..."
check_port_usage 8545 "Ganache"
check_port_usage 6300 "Config Server"
check_port_usage 6500 "UI Server"
check_port_usage 3000 "Server"  # This port must be free based on user rules

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

echo "Installing all dependencies..."
# Root dependencies
npm install || yarn install

# UI dependencies
echo "Installing UI dependencies..."
cd ui && npm install || yarn install
cd ..

# Server dependencies
echo "Installing server dependencies..."
cd server && npm install || yarn install
cd ..

echo "Installing LESS compiler if not present..."
if ! command -v lessc &> /dev/null; then
    npm install -g less
fi

echo "Setting up infrastructure..."
docker-compose -f docker-compose-simple.yml up -d

echo "Waiting for infrastructure to be ready..."
sleep 10

echo "Testing connection to Ganache..."
attempts=0
max_attempts=3
while [ $attempts -lt $max_attempts ]; do
  if curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://localhost:8545 > /dev/null; then
    echo "Successfully connected to Ganache."
    break
  else
    attempts=$((attempts+1))
    if [ $attempts -eq $max_attempts ]; then
      echo "ERROR: Cannot connect to Ganache at http://localhost:8545 after $max_attempts attempts."
      echo "Restarting Docker containers and trying again..."
      docker-compose -f docker-compose-simple.yml down
      docker-compose -f docker-compose-simple.yml up -d
      sleep 15
      if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://localhost:8545 > /dev/null; then
        echo "ERROR: Still cannot connect to Ganache. Please check Docker and network settings."
        exit 1
      fi
      break
    else
      echo "Cannot connect to Ganache. Retrying in 5 seconds..."
      sleep 5
    fi
  fi
done

# Deploy smart contracts with retry logic
deploy_contracts

# Compile CSS with fallback mechanisms
compile_css

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
