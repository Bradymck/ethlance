#!/bin/bash

echo "===== Ethlance One-Command Setup ====="
echo "This script will:"
echo "1. Check and install all prerequisites"
echo "2. Set up the environment"
echo "3. Deploy the contracts"
echo "4. Start all services"
echo "5. Open the application in your browser"
echo 

# First make all scripts executable
chmod +x setup.sh start.sh stop.sh test-setup.sh

# Run setup
./setup.sh

# Check exit status
if [ $? -ne 0 ]; then
  echo "Setup failed. Please check the logs."
  exit 1
fi

# Run start in background
./start.sh &
START_PID=$!

# Wait for services to be ready
echo "Waiting for all services to be ready..."
for i in {1..30}; do
  if curl -s http://localhost:6300/config > /dev/null; then
    echo "Config server is ready."
    break
  fi
  echo -n "."
  sleep 2
done

# Open browser
echo "Opening Ethlance in your browser..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  open http://localhost:6500/index.html
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  xdg-open http://localhost:6500/index.html
fi

echo "Ethlance is now running!"
echo "To stop all services when done, run:"
echo "./stop.sh"
