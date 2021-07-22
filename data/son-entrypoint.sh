#!/bin/bash
set -e

BITCOIN_IP=$(dig +short bitcoind-node)

sed -i 's/.*bitcoin-node-ip.*/bitcoin-node-ip = '$BITCOIN_IP'/' /peerplays/witness_node_data_dir/config.ini

exec "$@"
