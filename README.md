# Peerplays Blockchain

# Usage

To install a witness or seed node:

```bash
git clone https://gitlab.com/data-security-node/peerplays-docker.git
cd peerplays-docker
# If you don't already have a docker installation, this will install it for you
./run.sh install_docker

# This downloads/updates the low-memory docker image for Peerplays
./run.sh install

# If you are a witness, you need to adjust the configuration as needed
# e.g. witness name, private key, logging config, turn off p2p-endpoint etc.
# If you're running a seed, then don't worry about the config, it will just work
nano data/witness_node_data_dir/config.ini

# (optional) Setting the .env file up (see the env settings section of this readme)
# will help you to adjust settings for steem-in-a-box
nano .env

# Once you've configured your server, it's recommended to download the block log, as replays can be
# faster than p2p download
./run.sh dlblocks

# You'll also want to set the shared memory size (use sudo if not logged in as root). 
# Adjust 64G to whatever size is needed for your type of server and make sure to leave growth room.
# Please be aware that the shared memory size changes constantly. Ask in a witness chatroom if you're unsure.
./run.sh shm_size 64G

# It's recommended to set vm.swappiness to 1, which tells the system to avoid using swap 
# unless absolutely necessary. To persist on reboot, place in /etc/sysctl.conf
sysctl -w vm.swappiness=1

# Then after you've downloaded the blockchain, you can start peerplays in replay mode
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

For handling requests to your full node in docker, I recommend spinning up an nginx container, and connecting nginx to the steem node using a docker network.

Example:

```
docker network create rpc_default
# Assuming your RPC container is called "rpc1" instead of witness/seed
docker network connect rpc_default rpc1
docker network connect rpc_default nginx
```

Nginx will now be able to access the container RPC1 via `http://rpc1:8090` (assuming 8090 is the RPC port in your config). Then you can set up SSL and container port forwarding as needed for nginx.

# Updating your Peerplays node

To update to a newer version of Peerplays, first check [@datasecuritynode's docker hub](https://hub.docker.com/r/datasecuritynode/peerplays/tags/) to see if a new version of Peerplays is uploaded.

Security updates may not be tagged under a specific version, instead `latest`/`latest-full` will simply show a newer "Last Updated" on docker hub.

If there is a new version available, then you can update using the following (be warned, a replay is needed in many cases):

```
git pull
./run.sh install
./run.sh restart
```

**If you're updating a full node, please remember to use `install_full` instead of install.**

# Checking the status of your node

You can use the `logs` command to see the output from steemd:

```
./run.sh logs
```

You can also connect the local wallet using:

```
./run.sh wallet
```

Be aware, you can't connect cli_wallet until your peerplaysd has finished replaying.

# Environment options

By default, `run.sh` will attempt to load variables from `.env` in the same directory as run.sh.

Anything which is not set in .env will fall back to a default value specified at the top of run.sh.

The most common .env which is recommended for witnesses is the following:


```
DOCKER_NAME=witness
PORTS=
```

The above `.env` file will set your docker container name to "witness", instead of the default "seed", and will also disable port forwarding, preventing exposure of the p2p port in the event you forget to turn off p2p-endpoint.

# Commands

Full list of `./run.sh` commands:

 - **start** - start a stopped steem-docker instance
 - **stop** - shutdown a steem-docker instance
 - **restart** - restart a steem-docker instance (will also start it if it's already stopped)
 - **wallet** - connect to the local container wallet
 - **remote_wallet** - connect to a remote wallet (default is wss://steemd.privex.io - @privex load balancer)
   - be aware, due to the way load balancing works, this may raise an error at first. just run it again a few times and eventually it will connect. note that external servers often have a 60 second connection limit, so you may be disconnected within 60 seconds.
 - **replay** - replay a steem-docker instance (run `stop` first) 
 - **dlblocks** - download blocks from gtg (gandalf)'s block log server and install them into the blockchain directory
 - **shm_size (size)** - change the size of /dev/shm, e.g. `./run.sh shm_size 64G` for 64 gigabytes
 - **install** - install or update the steem docker image from docker hub
 - **install_full** - install or update the full node steem docker image from docker hub
 - **build** - build the low memory mode version of steem into a docker image from source
 - **build_full** - build the full node version of steem into a docker image from source
 - **logs** - display the logs of the container with automatic follow. press ctrl-c to exit
 - **enter** - open a bash prompt inside of the container for debugging
