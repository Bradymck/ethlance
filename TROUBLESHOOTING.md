# Ethlance Troubleshooting Guide

This guide covers common issues that may arise during the setup and running of Ethlance, along with their solutions.

## Docker Issues

### Docker containers won't start

**Symptoms:**
* `docker-compose up` fails with permission errors
* Docker commands need sudo

**Solutions:**
* Add your user to the docker group: 
  ```bash
  sudo usermod -aG docker $USER
  # Then log out and log back in
  ```
* Check if the Docker daemon is running:
  ```bash
  sudo systemctl status docker
  # If not running:
  sudo systemctl start docker
  ```

### Port conflicts

**Symptoms:**
* Error message: "port is already allocated" 
* Services fail to start

**Solutions:**
* Find what's using the port:
  ```bash
  lsof -i :<port_number>
  # For example:
  lsof -i :8545  # For Ganache
  lsof -i :6300  # For config server
  ```
* Stop the conflicting service or modify the docker-compose.yml to use different ports

## Ganache Issues

### Can't connect to Ganache

**Symptoms:**
* Smart contract deployment fails
* Web3 connection errors in the UI

**Solutions:**
* Verify Ganache is running:
  ```bash
  curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545
  ```
* Restart the container:
  ```bash
  docker-compose -f docker-compose-simple.yml restart ganache
  ```
* Check for firewall issues:
  ```bash
  # Temporarily disable firewall to test
  sudo ufw disable
  # Don't forget to re-enable after testing
  sudo ufw enable
  ```

## Node.js & npm Issues

### Node version conflicts

**Symptoms:**
* Error messages about incompatible Node.js version
* npm install fails with strange errors

**Solutions:**
* Install nvm to manage Node versions:
  ```bash
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
  source ~/.bashrc  # Or restart your terminal
  nvm install 16
  nvm use 16
  ```
* Verify Node.js version:
  ```bash
  node -v  # Should be 16.x or newer
  ```

### npm dependency errors

**Symptoms:**
* npm install fails with "unexpected end of JSON input" or similar
* Package-lock.json conflicts

**Solutions:**
* Clear npm cache:
  ```bash
  npm cache clean --force
  ```
* Try using yarn instead:
  ```bash
  npm install -g yarn
  yarn install
  ```
* Delete node_modules and reinstall:
  ```bash
  rm -rf node_modules
  rm package-lock.json
  npm install
  ```

## Configuration Issues

### Config server not starting

**Symptoms:**
* UI fails to load configuration
* Console errors about missing config

**Solutions:**
* Check if config-server.js exists and has the right content
* Make sure the correct URLs are set in the config-server.js file
* Verify that port 6300 is not being used by another process

### Incorrect hostnames in configuration

**Symptoms:**
* UI connects to wrong URLs
* CORS errors when accessing services

**Solutions:**
* Fix hostname references:
  ```bash
  # Replace all d0x-vm references with localhost
  find ui/src -type f -name "*.cljs" -exec sed -i 's/d0x-vm/localhost/g' {} \;
  ```
* Verify your configuration in config-server.js

## Database Issues

### PostgreSQL connection failures

**Symptoms:**
* Database connection errors
* SQL-related errors in logs

**Solutions:**
* Verify PostgreSQL is running:
  ```bash
  docker-compose -f docker-compose-simple.yml ps | grep postgres
  ```
* Check connection details:
  ```bash
  # Try connecting to the database
  docker exec -it ethlance-postgres-1 psql -U postgres
  ```
* Reset the database container:
  ```bash
  docker-compose -f docker-compose-simple.yml stop postgres
  docker-compose -f docker-compose-simple.yml rm -f postgres
  docker-compose -f docker-compose-simple.yml up -d postgres
  ```

## UI Issues

### UI not building or starting

**Symptoms:**
* shadow-cljs fails to build or start
* JavaScript errors in the browser console

**Solutions:**
* Check if shadow-cljs is installed:
  ```bash
  npx shadow-cljs --version
  ```
* Clear the shadow-cljs cache:
  ```bash
  rm -rf .shadow-cljs
  cd ui && npm install
  ```
* Manually rebuild CSS:
  ```bash
  bb compile-css
  ```

### Blank page or infinite loading spinner

**Symptoms:**
* UI shows blank white page
* Loading spinner never stops

**Solutions:**
* Check browser console for errors
* Verify Ganache is running and deployed contracts exist
* Make sure config server is responding:
  ```bash
  curl http://localhost:6300/config
  ```
* Check if UI server is running:
  ```bash
  lsof -i :6500
  ```

## Smart Contract Issues

### Contract deployment failures

**Symptoms:**
* Truffle migration fails
* Web3 errors in browser console

**Solutions:**
* Reset Ganache and deploy again:
  ```bash
  docker-compose -f docker-compose-simple.yml restart ganache
  sleep 5
  npx truffle migrate --network ganache --reset
  ```
* Check Ganache logs:
  ```bash
  docker-compose -f docker-compose-simple.yml logs ganache
  ```
* Verify truffle-config.js has correct network settings

## If All Else Fails

### Complete Reset

Sometimes the easiest solution is to start fresh:

```bash
# Stop all services
./stop.sh

# Clean up Docker
docker-compose -f docker-compose-simple.yml down -v

# Clear all build artifacts
rm -rf .shadow-cljs
rm -rf ui/resources/public/js
rm -rf ui/resources/public/css
rm -rf node_modules
rm -rf ui/node_modules
rm -rf server/node_modules

# Start over
./setup.sh
./start.sh
```

### Getting Help

If you're still stuck:

1. Check the [GitHub issues](https://github.com/district0x/ethlance/issues) for similar problems
2. Create a detailed issue with steps to reproduce the problem
3. Join the [district0x Discord](https://discord.gg/sS2AWYm) for community support
