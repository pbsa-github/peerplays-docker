# Steem-in-a-box by @someguy123 adapted for Peerplays Blockchain

**Peerplays-in-a-box** is a toolkit for using the Peerplays [docker images](https://hub.docker.com/r/datasecuritynode/peerplays/tags/) published by @datasecuritynode.

It's purpose is to simplify the deployment of `peerplaysd` nodes.

Features:

 - Automatic docker installer
 - Easily update Peerplays (peerplaysd, cli_wallet etc.) with binary images
 - Easily build your own new versions of Peerplays by editing the docker files
 - Single command to download and install block_log from gtg's server
 - Easily adjust /dev/shm size
 - Automatically forwards port 9777 for seeds
 - Automatically installs a working example configuration for seeds, which can easily be customized for witnesses and full nodes
 - Quick access to common actions such as start, stop, replay, rebuild, local wallet, remote wallet, and much more
 - BOS-Auto: Install and spinup 
 
 
# Usage

To install a witness or seed node:

```bash
git clone https://gitlab.com/data-security-node/peerplays-docker.git
cd peerplays-docker
# If you don't already have a docker installation, this will install it for you
./run.sh install_docker

# This downloads/updates the docker image for Peerplays
./run.sh install

# If you are a witness, you need to adjust the configuration as needed
# e.g. witness name, private key, logging config, turn off p2p-endpoint etc.
# If you're running a seed, then don't worry about the config, it will just work
nano data/witness_node_data_dir/config.ini

# (optional) Setting the .env file up (see the env settings section of this readme)
# will help you to adjust settings for peerplays-in-a-box
nano .env

# Once you've configured your server, it's recommended to download the block log, as replays can be
# faster than p2p download
# ./run.sh dlblocks

# You'll also want to set the shared memory size (use sudo if not logged in as root). 
# Adjust 64G to whatever size is needed for your type of server and make sure to leave growth room.
# Please be aware that the shared memory size changes constantly. Ask in a witness chatroom if you're unsure.
./run.sh shm_size 64G

# It's recommended to set vm.swappiness to 1, which tells the system to avoid using swap 
# unless absolutely necessary. To persist on reboot, place in /etc/sysctl.conf
sysctl -w vm.swappiness=1

# Then after you've downloaded the blockchain, you can start peerplaysd in replay mode
./run.sh replay
# If you DON'T want to replay, use "start" instead
./run.sh start
```

You may want to persist the /dev/shm size (shared memory) across reboots. To do this, you can edit `/etc/fstab`, please be very careful, as any mistakes in this file will cause your system to become unbootable.

Simply add this to the bottom of the file on a new line. Be sure not to damage any other lines in the file. Adjust "64G" to whatever size you would like /dev/shm to be.

```
tmpfs   /dev/shm         tmpfs   nodev,nosuid,size=64G          0  0
```

# Full node (RPC)

To install a full RPC node - follow the same steps as above, but use `install_full` instead of `install`.

Remember to adjust the config, you'll need a higher shared memory size (potentially up to 1 TB), and various plugins.

For handling requests to your full node in docker, I recommend spinning up an nginx container, and connecting nginx to the peerplays node using a docker network.

Example:

```
docker network create rpc_default
# Assuming your RPC container is called "rpc1" instead of witness/seed
docker network connect rpc_default rpc1
docker network connect rpc_default nginx
```

Nginx will now be able to access the container RPC1 via `http://rpc1:8090` (assuming 8090 is the RPC port in your config). Then you can set up SSL and container port forwarding as needed for nginx.

# SON

To install a SON node - follow the same steps with some slight modifications:

```bash
# This downloads/updates the docker image for Peerplays SON
./run.sh install son

# If you are a witness, you need to adjust the configuration as needed
# Check out the config.son.example.ini file for SON configuration
nano data/witness_node_data_dir/config.ini

# (Manditory) make sure to speicfy the full path in BTC_REGTEST_CONF
# A sample bitcoin.conf is located in the bitcoin directory in this repository
# Setting the .env file up (see the env settings section of this readme)
# will help you to adjust settings for peerplays-in-a-box
nano .env

# Once you've configured your server, it's recommended to download the block log, as replays can be
# faster than p2p download
# ./run.sh dlblocks

# You'll also want to set the shared memory size (use sudo if not logged in as root). 
# Adjust 64G to whatever size is needed for your type of server and make sure to leave growth room.
# Please be aware that the shared memory size changes constantly. Ask in a witness chatroom if you're unsure.
./run.sh shm_size 64G

# It's recommended to set vm.swappiness to 1, which tells the system to avoid using swap 
# unless absolutely necessary. To persist on reboot, place in /etc/sysctl.conf
sysctl -w vm.swappiness=1

# Start the SON environment
./run.sh start_son_regtest
```
# Updating your Peerplays node

To update to a newer version of Peerplays, first check [@datasecuritynode's docker hub](https://hub.docker.com/r/datasecuritynode/peerplays/tags/) to see if a new version of Peerplays is uploaded. Low memory mode (witness/seed) images are tagged like "v0.20.0", while full node images are tagged as "v0.20.0-full". 

Security updates may not be tagged under a specific version, instead `latest`/`latest-full` will simply show a newer "Last Updated" on docker hub.

If there is a new version available, then you can update using the following (be warned, a replay is needed in many cases):

```
git pull
./run.sh install
./run.sh restart
```

**If you're updating a full node, please remember to use `install_full` instead of install.**

# Checking the status of your node

You can use the `logs` command to see the output from peerplaysd:

```
./run.sh logs
```

You can also connect the local wallet using:

```
./run.sh wallet
```

Be aware, you can't connect cli_wallet until your Peerplays blockchain (witness_node) has finished replaying.

# Environment options

By default, `run.sh` will attempt to load variables from `.env` in the same directory as run.sh.

Anything which is not set in .env will fall back to a default value specified at the top of run.sh.

The most common .env which is recommended for witnesses is the following:


```
DOCKER_NAME=witness
PORTS=
```

The above `.env` file will set your docker container name to "witness", instead of the default "seed", and will also disable port forwarding, preventing exposure of the p2p port in the event you forget to turn off p2p-endpoint.

Full list of possible configuration options:

 - **PORTS** - default `9777` - a comma separated list of ports in peerplaysd to forward to the internet
 - **DOCKER_NAME** - default `seed` - the container name to use for your peerplaysd server
 - **DOCKER_DIR** - default `$DIR/dkr` - The directory to build the low memory node docker image from
 - **FULL_DOCKER_DIR** - default `$DIR/dkr_fullnode` - The directory to build the full-node RPC node docker image from
 - **DK_TAG** - default `datasecuritynode/peerplays:latest` - The docker tag to obtain Peerplays from. Useful for installing beta versions, or downgrading to previous versions.
 - **DK_TAG_FULL** - default `datasecuritynode/peerplays:latest-full` - The docker tag to obtain Peerplays (full RPC node)  from. Useful for installing beta versions, or downgrading to previous versions.
 - **SHM_DIR** - default `/dev/shm` - override the location of shared_memory.bin and shared_memory.meta. /dev/shm is a RAM disk on Linux, and can be adjusted with `shm_size`
 - **REMOTE_WS** - default connects to the Peerplays witness node endpoints - the websocket server to use for the `remote_wallet` command

 ## SON
 - **DOCKER-NETWORK** - default `son` - the network name to use for communication between the peerplaysd and bitcoind containers
 - **SON_WALLET** - default `son-wallet` - the bitcoin wallet name to create in bitcoind
 - **BTC_REGTEST_KEY** - default `cSKyTeXidmj93dgbMFqgzD7yvxzA7QAYr5j9qDnY9seyhyv7gH2m` - the bitcoin private key to import in bitcoind

# bos_install
 To install and spinup bos:
 ```
 ./run.sh bos_install
 ```
 

# Commands

Full list of `./run.sh` commands:

 - **start** - start a stopped peerplays-docker instance
 - **start_son** - start a stopped peerplays-docker SON instance
 - **start_son_regtest** - start a Peerplays SON and Bitcoin regtest containers and network
 - **stop** - shutdown a peerplays-docker instance
 - **restart** - restart a peerplays-docker instance (will also start it if it's already stopped)
 - **wallet** - connect to the local container wallet
 - **replay** - replay a peerplays-docker instance (run `stop` first)
 - **replay_son** - replay a peerplays-docker SON instance (run `stop` first) 

 - **dlblocks** - download blocks from gtg (gandalf)'s block log server and install them into the blockchain directory
 - **shm_size (size)** - change the size of /dev/shm, e.g. `./run.sh shm_size 64G` for 64 gigabytes
 - **install** - install or update the peerplays docker image from docker hub
 - **install_full** - install or update the full node peerplays docker image from docker hub
 - **build** - build the low memory mode version of peerplays into a docker image from source
 - **build_full** - build the full node version of peerplays into a docker image from source
 - **logs** - display the logs of the container with automatic follow. press ctrl-c to exit
 - **enter** - open a bash prompt inside of the container for debugging
 - **bos_install** - install and spinup bos-auto

# LICENSE

Steem-in-a-box was built by @someguy123 ([github](https://github.com/someguy123) [steemit](https://steemit.com/@someguy123) [twitter](https://twitter.com/@compgenius999))

GNU Affero General Public License v3.0

SEE LICENSE FILE FOR MORE INFO
