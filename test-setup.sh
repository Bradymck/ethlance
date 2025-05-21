#!/bin/bash

# Exit on error
set -e

echo "===== Ethlance Setup Verification ====="
echo "This script will verify your Ethlance setup and check for common issues."
echo

# Function to check if a command is available
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "❌ Required command '$1' not found. Please install $2."
    return 1
  else
    echo "✅ Found $1 $(command -v "$1")"
    return 0
  fi
}

# Function to check if a service is running on a port
check_port() {
  if nc -z localhost "$1" &> /dev/null; then
    echo "✅ Port $1 is open and service is running"
    return 0
  else
    echo "❌ No service detected on port $1"
    return 1
  fi
}

# Function to check Docker container status
check_container() {
  if docker ps | grep -q "$1"; then
    echo "✅ Container $1 is running"
    return 0
  else
    echo "❌ Container $1 is not running"
    return 1
  fi
}

# Create a temporary directory for testing
TEMP_DIR=$(mktemp -d)
echo "Created temporary test directory: $TEMP_DIR"

# Track overall status
OVERALL_STATUS=0

echo
echo "1. Checking required tools..."
check_command "docker" "Docker" || OVERALL_STATUS=1
check_command "docker-compose" "Docker Compose" || OVERALL_STATUS=1
check_command "node" "Node.js" || OVERALL_STATUS=1
check_command "npm" "npm" || OVERALL_STATUS=1
check_command "curl" "curl" || OVERALL_STATUS=1
check_command "nc" "netcat" || OVERALL_STATUS=1

echo
echo "2. Checking required files..."
[ -f "setup.sh" ] && echo "✅ setup.sh exists" || { echo "❌ setup.sh is missing"; OVERALL_STATUS=1; }
[ -f "start.sh" ] && echo "✅ start.sh exists" || { echo "❌ start.sh is missing"; OVERALL_STATUS=1; }
[ -f "stop.sh" ] && echo "✅ stop.sh exists" || { echo "❌ stop.sh is missing"; OVERALL_STATUS=1; }
[ -f "server/config-server.js" ] && echo "✅ config-server.js exists" || { echo "❌ config-server.js is missing"; OVERALL_STATUS=1; }
[ -f "docker-compose-simple.yml" ] && echo "✅ docker-compose-simple.yml exists" || { echo "❌ docker-compose-simple.yml is missing"; OVERALL_STATUS=1; }

echo
echo "3. Checking Docker containers..."
check_container "ethlance-ganache" || OVERALL_STATUS=1
check_container "ethlance-ipfs" || OVERALL_STATUS=1
check_container "ethlance-postgres" || OVERALL_STATUS=1

echo
echo "4. Checking network services..."
check_port 8545 || OVERALL_STATUS=1  # Ganache
check_port 5001 || OVERALL_STATUS=1  # IPFS API
check_port 8080 || OVERALL_STATUS=1  # IPFS Gateway
check_port 5432 || OVERALL_STATUS=1  # PostgreSQL
check_port 6300 || OVERALL_STATUS=1  # Config Server
check_port 6500 || { echo "⚠️ UI server not detected on port 6500. This is OK if you haven't started the UI yet."; }

echo
echo "5. Testing Ganache RPC connection..."
if curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545 | grep -q "result"; then
  echo "✅ Successfully connected to Ganache"
else
  echo "❌ Failed to connect to Ganache"
  OVERALL_STATUS=1
fi

echo
echo "6. Testing configuration server..."
if curl -s http://localhost:6300/config | grep -q "web3-provider"; then
  echo "✅ Configuration server is responding with valid config"
else
  echo "❌ Configuration server is not responding correctly"
  OVERALL_STATUS=1
fi

echo
echo "7. Checking smart contract deployment..."
# Test for contract deployment - relies on truffle artifacts
if [ -d "resources/public/contracts/build" ] && [ "$(ls -A resources/public/contracts/build)" ]; then
  echo "✅ Contract artifacts found"
else
  echo "❌ Contract artifacts missing - contracts may not be deployed"
  OVERALL_STATUS=1
fi

echo
echo "8. Testing CSS compilation..."
if [ -d "ui/resources/public/css" ] && [ "$(ls -A ui/resources/public/css)" ]; then
  echo "✅ CSS files found"
else
  echo "❌ CSS files missing - run 'bb compile-css'"
  OVERALL_STATUS=1
fi

# Clean up
rm -rf "$TEMP_DIR"

echo
echo "===== Setup Verification Summary ====="
if [ $OVERALL_STATUS -eq 0 ]; then
  echo "✅ ALL CHECKS PASSED! Your Ethlance environment appears to be correctly set up."
  echo "You can now access the Ethlance UI at: http://localhost:6500/index.html"
else
  echo "❌ SOME CHECKS FAILED. Please review the issues above."
  echo "For detailed troubleshooting help, see TROUBLESHOOTING.md"
fi

exit $OVERALL_STATUS
