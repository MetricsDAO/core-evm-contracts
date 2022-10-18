#!/bin/sh

# Change to the correct directory
cd /app;
# cd /workspaces/core-evm-contracts/

# Run hardhat
npm run localnodetest;

# Keep node alive
set -e
if [ "${1#-}" != "${1}" ] || [ -z "$(command -v "${1}")" ]; then
  set -- node "$@"
fi
exec "$@"