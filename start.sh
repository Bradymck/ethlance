#!/bin/bash

# Exit on error
set -e

echo "===== Starting Ethlance ====="

# Function to check if a command is available
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "ERROR: Required command '$1' not found."
    echo "Please install $2 before continuing."
    exit 1
  fi
}

# Function to check if setup has been completed
check_setup() {
  if [ ! -f "server/config-server.js" ]; then
    echo "ERROR: Configuration server file not found."
    echo "Please run ./setup.sh first to complete the setup process."
    exit 1
  fi
  
  if [ ! -f "config/server-config-dev.edn" ] || [ ! -f "config/ui-config-dev.edn" ]; then
    echo "ERROR: Configuration files not found."
    echo "Please run ./setup.sh first to complete the setup process."
    exit 1
  fi
}

# Check essential prerequisites
check_command "docker" "Docker"
check_command "docker-compose" "Docker Compose"
check_command "node" "Node.js"
check_command "npx" "npm"

# Check if setup has been completed
check_setup

# Create logs directory if it doesn't exist
mkdir -p logs

# Check if containers are running, start if not
if ! docker ps | grep -q ethlance-ganache-1; then
  echo "Starting infrastructure containers..."
  docker-compose -f docker-compose-simple.yml up -d
  echo "Waiting for containers to be ready..."
  sleep 10
  
  # Test Ganache connection
  echo "Testing connection to Ganache..."
  if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://localhost:8545 > /dev/null; then
    echo "ERROR: Cannot connect to Ganache at http://localhost:8545"
    echo "Please check that Docker containers are running properly."
    exit 1
  fi
else
  echo "Infrastructure containers already running."
  
  # Still test connection
  if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://localhost:8545 > /dev/null; then
    echo "WARNING: Cannot connect to Ganache at http://localhost:8545"
    echo "Containers may be running but Ganache is not responding."
    echo "Continue anyway? (y/n)"
    read -r response
    if [[ "$response" != "y" ]]; then
      echo "Exiting."
      exit 1
    fi
  fi
fi

# Start config server in background
echo "Starting configuration server..."
node server/config-server.js > logs/config-server.log 2>&1 &
CONFIG_SERVER_PID=$!
echo $CONFIG_SERVER_PID > .config-server.pid
echo "Configuration server started with PID $CONFIG_SERVER_PID"

# Wait for config server to start
sleep 2
echo "Testing configuration server..."
if ! curl -s http://localhost:6300/config > /dev/null; then
  echo "WARNING: Configuration server may not be running correctly."
  echo "Check logs/config-server.log for details."
  echo "Continue anyway? (y/n)"
  read -r response
  if [[ "$response" != "y" ]]; then
    echo "Exiting. Stopping config server..."
    kill $CONFIG_SERVER_PID 2>/dev/null || true
    rm .config-server.pid 2>/dev/null || true
    exit 1
  fi
fi

# Start UI
echo "Starting UI (this will keep running in the foreground)..."
echo "Access Ethlance at http://localhost:6500/index.html"
cd ui && npx shadow-cljs watch dev-ui
