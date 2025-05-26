#!/bin/bash

# Exit on error
set -e

# Create logs directory
mkdir -p logs

# Function to check if a command is available
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "ERROR: Required command '$1' not found."
    echo "Please install $2 before continuing."
    exit 1
  fi
}

# Function to check if a port is in use
check_port() {
  if lsof -i :$1 -t &>/dev/null; then
    echo "Port $1 is in use. Stopping process..."
    kill -9 $(lsof -i :$1 -t) &>/dev/null
    sleep 2
  fi
}

# Function to ensure Docker is running
ensure_docker_running() {
  if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon is not running. Please start Docker and try again."
    exit 1
  fi
}

# Function to compile CSS
compile_css() {
  if [ ! -f ui/resources/public/css/main.css ]; then
    echo "Compiling CSS..."
    bb compile-css > logs/css.log 2>&1 || {
      echo "Error compiling CSS. Check logs/css.log for details."
      exit 1
    }
  fi
}

# Function to start all services
start_services() {
  # Stop any existing services
  echo "Stopping any existing services..."
  check_port 6300  # GraphQL/Config server
  check_port 6500  # UI server 
  check_port 8545  # Ganache

  # Clean existing processes
  echo "Cleaning up existing processes..."
  ps aux | grep -E 'shadow-cljs|bb run-server|bb watch-ui|node server/config-server.js' | grep -v grep | awk '{print $2}' | xargs kill -9 &>/dev/null || true
  sleep 2

  # Start infrastructure
  echo "Starting infrastructure..."
  docker-compose -f docker-compose-simple.yml up -d

  # Start Ganache
  if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://localhost:8545 > /dev/null; then
    echo "Starting Ganache..."
    npx ganache --database.dbPath=./temp/ganache-db --logging.verbose \
      --wallet.mnemonic "easy leave proof verb wait patient fringe laptop intact opera slab shine" \
      --server.host 0.0.0.0 --server.port 8545 --miner.blockGasLimit 20000000 \
      --chain.allowUnlimitedContractSize true --miner.blockTime=0 \
      --chain.vmErrorsOnRPCResponse --chain.chainId 1 --chain.networkId 1 > logs/ganache.log 2>&1 &
    GANACHE_PID=$!
    echo "Ganache started with PID $GANACHE_PID"

    # Wait for Ganache
    echo "Waiting for Ganache..."
    for i in {1..30}; do
      echo -n "."
      if curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' http://localhost:8545 &>/dev/null; then
        echo -e "\nGanache is ready!"
        break
      fi
      sleep 1
      if [ $i -eq 30 ]; then
        echo -e "\nWarning: Ganache did not respond. Continuing anyway..."
      fi
    done
  else
    echo "Ganache already running"
  fi

  # Start config server
  echo "Starting configuration server..."
  node server/config-server.js > logs/config-server.log 2>&1 &
  CONFIG_SERVER_PID=$!
  echo "Configuration server started with PID $CONFIG_SERVER_PID"

  # Wait for config server
  echo "Waiting for config server..."
  for i in {1..15}; do
    echo -n "."
    if curl -s http://localhost:6300/config &>/dev/null; then
      echo -e "\nConfiguration server is ready!"
      CONFIG_READY=true
      break
    fi
    sleep 1
  done

  if [ -z "$CONFIG_READY" ]; then
    echo -e "\nConfiguration server not responding. Check logs/config-server.log for errors."
    exit 1
  fi

  # Compile CSS if needed
  compile_css

  # Start UI compiler
  echo "Starting UI compiler..."
  bb watch-ui > logs/ui-compiler.log 2>&1 &
  UI_COMPILER_PID=$!
  echo "UI compiler started with PID $UI_COMPILER_PID"

  # Wait for UI server
  echo "Waiting for UI server..."
  for i in {1..30}; do
    echo -n "."
    if curl -s http://localhost:6500 &>/dev/null; then
      echo -e "\nUI server is ready!"
      UI_READY=true
      break
    fi
    sleep 1
  done

  if [ -z "$UI_READY" ]; then
    echo -e "\nUI server not responding. Check logs/ui-compiler.log for errors."
    exit 1
  fi

  # Save PIDs for cleanup
  echo "$CONFIG_SERVER_PID $UI_COMPILER_PID" > .ethlance-pids

  echo -e "\n===== Ethlance is now running! ====="
  echo "Access the UI at: http://localhost:6500"
  echo "Configuration/GraphQL server: http://localhost:6300"
  echo ""
  echo "Active processes:"
  echo "- Configuration/GraphQL server: PID $CONFIG_SERVER_PID"
  echo "- UI compiler: PID $UI_COMPILER_PID"
  echo ""
  echo "To stop all services:"
  echo "kill -9 $CONFIG_SERVER_PID $UI_COMPILER_PID"
  echo ""
  echo "Press Ctrl+C to stop all services"

  # Keep script running
  tail -f logs/ui-compiler.log
}

# Function to stop all services
stop_services() {
  echo "Stopping all services..."
  
  # Kill processes from PID file
  if [ -f .ethlance-pids ]; then
    kill -9 $(cat .ethlance-pids) &>/dev/null || true
    rm .ethlance-pids
  fi

  # Stop Docker containers
  docker-compose -f docker-compose-simple.yml down

  # Clean up any remaining processes
  ps aux | grep -E 'shadow-cljs|bb run-server|bb watch-ui|node server/config-server.js' | grep -v grep | awk '{print $2}' | xargs kill -9 &>/dev/null || true
  
  echo "All services stopped."
}

# Function to setup the project
setup_project() {
  echo "===== Setting up Ethlance ====="
  
  # Check prerequisites
  check_command "docker" "Docker"
  check_command "docker-compose" "Docker Compose"
  check_command "node" "Node.js"
  check_command "npm" "NPM"
  
  # Ensure Docker is running
  ensure_docker_running
  
  # Install dependencies
  echo "Installing dependencies..."
  npm install || yarn install
  cd ui && npm install || yarn install
  cd ../server && npm install || yarn install
  cd ..
  
  # Setup infrastructure
  echo "Setting up infrastructure..."
  docker-compose -f docker-compose-simple.yml up -d
  
  echo "Setup complete!"
}

# Main script
case "${1:-start}" in
  start)
    echo "Starting Ethlance..."
    start_services
    ;;
  stop)
    echo "Stopping Ethlance..."
    stop_services
    ;;
  setup)
    echo "Setting up Ethlance..."
    setup_project
    ;;
  restart)
    echo "Restarting Ethlance..."
    stop_services
    sleep 2
    start_services
    ;;
  *)
    echo "Usage: $0 {start|stop|setup|restart}"
    echo "  start   - Start all Ethlance services (default)"
    echo "  stop    - Stop all running services"
    echo "  setup   - Set up the project for first use"
    echo "  restart - Restart all services"
    exit 1
    ;;
esac
