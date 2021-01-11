#!/usr/bin/env bash
################################################################################
# Peerplays node manager                                                       #
# Released under GNU AGPL by Someguy123                                        #
################################################################################

BOLD="" RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE="" RESET=""
if [ -t 1 ]; then
	BOLD="$(tput bold)" RED="$(tput setaf 1)" GREEN="$(tput setaf 2)" YELLOW="$(tput setaf 3)" BLUE="$(tput setaf 4)"
	MAGENTA="$(tput setaf 5)" CYAN="$(tput setaf 6)" WHITE="$(tput setaf 7)" RESET="$(tput sgr0)"
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${DOCKER_DIR=$DIR/peerplays-docker/dkr}"
: "${FULL_DOCKER_DIR=$DIR/dkr_fullnode}"
: "${DATADIR=$DIR/peerplays-docker/data}"
: "${DOCKER_NAME="peerplays"}"
: "${DOCKER_BITCOIN_NAME="bitcoind-node"}"
: "${DOCKER_BITCOIN_VOLUME="bitcoind-data"}"
: "${BITCOIN_DOCKER_TAG="kylemanna/bitcoind"}"
: "${DOCKER_NETWORK="son"}"
: "${BITCOIN_WALLET="son-wallet"}"
: "${BTC_REGTEST_KEY="cSKyTeXidmj93dgbMFqgzD7yvxzA7QAYr5j9qDnY9seyhyv7gH2m"}"

: "${DKR_DATA_MOUNT="/peerplays"}" # Mount $DATADIR onto this folder within the container
: "${DKR_SHM_MOUNT="/shm"}"        # Mount $SHM_DIR onto this folder within the container
: "${DKR_RUN_BIN="witness_node"}"  # Run this executable within the container

# the tag to use when running/replaying peerplaysd
: "${DOCKER_IMAGE="peerplays"}"
: "${PEERPLAYS_DOCKER_TAG="datasecuritynode/peerplays:latest"}"

# Amount of time in seconds to allow the docker container to stop before killing it.
# Default: 600 seconds (10 minutes)
: "${STOP_TIME=60}"

# Git repository to use when building Steem - containing peerplaysd code
: "${PEERPLAYS_SOURCE="https://github.com/peerplays-network/peerplays.git"}"
: "${PEERPLAYS_DOCKER_SOURCE="https://gitlab.com/PBSA/PeerplaysIO/tools-libs/peerplays-docker.git"}"

# Comma separated list of ports to expose to the internet.
# By default, only port 9777 will be exposed (the P2P seed port)
: "${PORTS="9777"}"

# Internal variable. Set to 1 by build_full to inform child functions
BUILD_FULL=0
# Placeholder for custom tag var CUST_TAG (shared between functions)
CUST_TAG="peerplays"
# Placeholder for BUILD_VER shared between functions
BUILD_VER=""

# blockchain folder, used by dlblocks
: "${BC_FOLDER=$DATADIR/witness_node_data_dir/blockchain}"

: "${EXAMPLE_MIRA=$DATADIR/witness_node_data_dir/database.cfg.example}"
: "${MIRA_FILE=$DATADIR/witness_node_data_dir/database.cfg}"

: "${EXAMPLE_CONF=$DATADIR/witness_node_data_dir/config.ini.example}"
: "${CONF_FILE=$DATADIR/witness_node_data_dir/config.ini}"

# Array of additional arguments to be passed to Docker during builds
# Generally populated using arguments passed to build/build_full
# But you can specify custom additional build parameters by setting BUILD_ARGS
# as an array in .env
# e.g.
#
#    BUILD_ARGS=('--rm' '-q' '--compress')
#
BUILD_ARGS=()

# easy coloured messages function
# written by @someguy123
function msg() {
	if [[ "$#" -eq 0 ]]; then
		echo ""
		return
	fi
	if [[ "$#" -eq 1 ]]; then
		echo -e "$1"
		return
	fi

	_msg=""

	if ((MSG_TS_DEFAULT == 1)); then
		[[ "$1" == "ts" ]] && shift
		{ [[ "$1" == "nots" ]] && shift; } || _msg="[$(date +'%Y-%m-%d %H:%M:%S %Z')] "
	else
		[[ "$1" == "nots" ]] && shift
		[[ "$1" == "ts" ]] && shift && _msg="[$(date +'%Y-%m-%d %H:%M:%S %Z')] "
	fi

	if [[ "$#" -gt 2 ]] && [[ "$1" == "bold" ]]; then
		echo -n "${BOLD}"
		shift
	fi
	(($# == 1)) && _msg+="$@" || _msg+="${@:2}"

	case "$1" in
	bold) echo -e "${BOLD}${_msg}${RESET}" ;;
	BLUE | blue) echo -e "${BLUE}${_msg}${RESET}" ;;
	YELLOW | yellow) echo -e "${YELLOW}${_msg}${RESET}" ;;
	RED | red) echo -e "${RED}${_msg}${RESET}" ;;
	GREEN | green) echo -e "${GREEN}${_msg}${RESET}" ;;
	CYAN | cyan) echo -e "${CYAN}${_msg}${RESET}" ;;
	MAGENTA | magenta | PURPLE | purple) echo -e "${MAGENTA}${_msg}${RESET}" ;;
	*) echo -e "${_msg}" ;;
	esac
}

export -f msg
export RED GREEN YELLOW BLUE BOLD NORMAL RESET

if [[ -f .env ]]; then
	source .env
fi

# blockchain folder, used by dlblocks
: "${BC_FOLDER=$DATADIR/witness_node_data_dir/blockchain}"

: "${EXAMPLE_MIRA=$DATADIR/witness_node_data_dir/database.cfg.example}"
: "${MIRA_FILE=$DATADIR/witness_node_data_dir/database.cfg}"

: "${EXAMPLE_CONF=$DATADIR/witness_node_data_dir/config.ini.example}"
: "${CONF_FILE=$DATADIR/witness_node_data_dir/seed_config.ini}"

# full path to btc regtest config
: "${BTC_REGTEST_CONF="/var/opt/peerplays-docker/bitcoin/regtest/bitcoin.conf"}"

# if the config file doesn't exist, try copying the example config
#if [[ ! -f "$CONF_FILE" ]]; then
#	if [[ -f "$EXAMPLE_CONF" ]]; then
#		echo "${YELLOW}File config.ini not found. copying example (seed)${RESET}"
#		cp -vi "$EXAMPLE_CONF" "$CONF_FILE"
#		echo "${GREEN} > Successfully installed example config for seed node.${RESET}"
#		echo " > You may want to adjust this if you're running a witness, e.g. disable p2p-endpoint"
#	else
#		echo "${YELLOW}WARNING: You don't seem to have a config file and the example config couldn't be found...${RESET}"
#		echo "${YELLOW}${BOLD}You may want to check these files exist, or you won't be able to launch Peerplays${RESET}"
#		echo "Example Config: $EXAMPLE_CONF"
#		echo "Main Config: $CONF_FILE"
#	fi
#fi

IFS=","
DPORTS=()
for i in $PORTS; do
	if [[ $i != "" ]]; then
		if grep -q ":" <<<"$i"; then
			DPORTS+=("-p$i")
		else
			DPORTS+=("-p0.0.0.0:$i:$i")
		fi
	fi
done

if ! ((${#DKR_VOLUMES[@]})); then
	DKR_VOLUMES=(
		"${SHM_DIR}:${DKR_SHM_MOUNT}"
		"${DATADIR}:${DKR_DATA_MOUNT}"
	)
fi

if ((${#EXTRA_VOLUMES[@]})); then
	IFS="," read -r -a _EXTRA_VOLS <<<"$EXTRA_VOLUMES"
	DKR_VOLUMES+=("${_EXTRA_VOLS[@]}")
fi

# load docker hub API
#source scripts/000_docker.sh

help() {
	clear
	echo "Usage: $0 COMMAND"
	echo
	echo "Commands:
	
$(msg bold "#---WITNESS NODE AS SERVICE---#")
	
$(msg blue "witness_install")               - Builds, Installs and Starts the Peerplays Blockchain as a Service
$(msg blue "witness_install_only")          - Builds, Installs Peerplays Blockchain (Manual Start)

$(msg bold "#---WITNESS NODE AS DOCKER CONTAINER---#")

$(msg yellow "witness_docker_install")      - installs and starts ${DOCKER_NAME} witness docker container
$(msg yellow "build")                       - builds a Peerplays witness docker image from source code
$(msg yellow "start")                       - starts the ${DOCKER_NAME} witness docker container
$(msg yellow "stop")                        - stops ${DOCKER_NAME} witness docker container
$(msg yellow "kill")                        - force stop ${DOCKER_NAME} witness docker container (in event of ${DOCKER_NAME} container hanging indefinitely)
$(msg yellow "restart")                     - restarts ${DOCKER_NAME} witness docker container
$(msg yellow "status")                      - show status of ${DOCKER_NAME} witness docker container

$(msg bold "#---SEED NODE AS DOCKER CONTAINER---#")

$(msg yellow "seed_docker_install")         - installs and starts ${DOCKER_NAME} seed docker container
$(msg yellow "start")                       - starts the ${DOCKER_NAME} seed docker container
$(msg yellow "stop")                        - stops ${DOCKER_NAME} seed docker container
$(msg yellow "kill")                        - force stop ${DOCKER_NAME} seed docker container (in event of ${DOCKER_NAME} container hanging indefinitely)
$(msg yellow "restart")                     - restarts ${DOCKER_NAME} seed docker container
$(msg yellow "status")                      - show status of ${DOCKER_NAME} seed docker container

$(msg bold "#---SON AS DOCKER CONTAINER---#")

$(msg magenta "son_docker_install")         - installs and starts ${DOCKER_NAME} SON docker container
$(msg magenta "son_docker_regtest_install") - installs and starts ${DOCKER_NAME} SON docker container in test mode
$(msg magenta "start")                      - starts the ${DOCKER_NAME} SON docker container
$(msg magenta "stop")                       - stops ${DOCKER_NAME} SON docker container
$(msg magenta "kill")                       - force stop ${DOCKER_NAME} SON docker container (in event of ${DOCKER_NAME} container hanging indefinitely)
$(msg magenta "restart")                    - restarts ${DOCKER_NAME} SON docker container
$(msg magenta "status")                     - show status of ${DOCKER_NAME} SON docker container

$(msg bold "#---Common commands---#")
$(msg green "logs")                         - shows the logs related to Peerplays Blockchain
$(msg green "uninstall")                    - uninstalls the Peerplays Blockchain installation
$(msg green "replay")                       - starts replay of the installed Peerplays Blockchain installation
$(msg green "shm_size")                     - Resizes the ramdisk used for storing Peerplays's shared_memory at /dev/shm (ex: ./run.sh shm_size 64G)
	"
	echo
	exit
}

####SON NODE COMMANDS#######
#	start - starts seed container
#	start_son - starts son seed container
#	start_son_regtest - starts son seed container and bitcoind container under the docker network
#	replay_son - starts son seed container (in replay mode)
#	stop - stops seed container
#	status - show status of seed container
#	restart - restarts seed container
#	install_docker - install docker
#	install_full - pulls latest (FULL NODE FOR RPC)
############################

APT_UPDATED="n"
pkg_not_found() {
	# check if a command is available
	# if not, install it from the package specified
	# Usage: pkg_not_found [cmd] [apt-package]
	# e.g. pkg_not_found git git
	if [[ $# -lt 2 ]]; then
		echo "${RED}ERR: pkg_not_found requires 2 arguments (cmd) (package)${NORMAL}"
		exit
	fi
	local cmd=$1
	local pkg=$2
	if ! [ -x "$(command -v $cmd)" ]; then
		echo "${YELLOW}WARNING: Command $cmd was not found. installing now...${NORMAL}"
		if [[ "$APT_UPDATED" == "n" ]]; then
			sudo apt update -y
			APT_UPDATED="y"
		fi
		sudo apt install -y "$pkg"
	fi
}

optimize() {
	echo 75 | sudo tee /proc/sys/vm/dirty_background_ratio
	echo 1000 | sudo tee /proc/sys/vm/dirty_expire_centisecs
	echo 80 | sudo tee /proc/sys/vm/dirty_ratio
	echo 30000 | sudo tee /proc/sys/vm/dirty_writeback_centisecs
}

parse_build_args() {
	BUILD_VER=$1
	CUST_TAG="peerplays:$BUILD_VER"
	if (($BUILD_FULL == 1)); then
		CUST_TAG+="-full"
	fi
	BUILD_ARGS+=('--build-arg' "peerplaysd=${BUILD_VER}")
	shift
	if (($# >= 2)); then
		if [[ "$1" == "tag" ]]; then
			CUST_TAG="$2"
			msg yellow " >> Custom re-tag specified. Will tag new image with '${CUST_TAG}'"
			shift
			shift # Get rid of the two tag arguments. Everything after is now build args
		fi
	fi
	local has_peerplays_src='n'
	if (($# >= 1)); then
		msg yellow " >> Additional build arguments specified."
		for a in "$@"; do
			msg yellow " ++ Build argument: ${BOLD}${a}"
			BUILD_ARGS+=('--build-arg' "$a")
			if grep -q 'PEERPLAYS_SOURCE' <<<"$a"; then
				has_peerplays_src='y'
			fi
		done
	fi

	if [[ "$has_peerplays_src" == "y" ]]; then
		msg bold yellow " [!!] PEERPLAYS_SOURCE has been specified in the build arguments. Using source from build args instead of global"
	else
		msg bold yellow " [!!] Did not find PEERPLAYS_SOURCE in build args. Using PEERPLAYS_SOURCE from environment:"
		msg bold yellow " [!!] PEERPLAYS_SOURCE = ${PEERPLAYS_SOURCE}"
		BUILD_ARGS+=('--build-arg' "PEERPLAYS_SOURCE=${PEERPLAYS_SOURCE}")
	fi

	msg blue " ++ CUSTOM BUILD SPECIFIED. Building from branch/tag ${BOLD}${BUILD_VER}"
	msg blue " ++ Tagging final image as: ${BOLD}${CUST_TAG}"
	msg yellow " -> Docker build arguments: ${BOLD}${BUILD_ARGS[@]}"
}

build_local() {
	PEERPLAYS_SOURCE="local_src_folder"
	DOCKER_DIR="${DIR}/dkr_local"

	if [[ ! -d "${DOCKER_DIR}/src" ]]; then
		msg bold red "ERROR: You must place the source code inside of ${DOCKER_DIR}/src"
		return 1
	fi

	msg green " >>> Local build requested."
	msg green " >>> Will build Peerplays using code stored in '${DOCKER_DIR}/src' instead of remote git repo"
	build "$@"
}

# Build standard low memory node as a docker image
# Usage: ./run.sh build [version] [tag tag_name] [build_args]
# Version is prefixed with v, matching Peerplays releases
# e.g. build v0.20.6
#
# Override destination tag:
#   ./run.sh build v0.21.0 tag 'peerplays:latest'
#
# Additional build args:
#   ./run.sh build v0.21.0 ENABLE_MIRA=OFF
#
# Or combine both:
#   ./run.sh build v0.21.0 tag 'steem:mira' ENABLE_MIRA=ON
#

build() {
	read -r -p "Enter Peerplays blockchain repository branch/tag to be used for building the docker image [Press Enter for default: master]: " BRANCH
	BRANCH=${BRANCH:-master}
	read -r -p "Enter the docker image name[Press Enter for default: peerplays]: " PEERPLAYS_IMAGE
	PEERPLAYS_IMAGE=${PEERPLAYS_IMAGE:-peerplays}
	read -r -p "Enter the tag name to be used for the docker image[Press Enter for default: latest]: " PEERPLAYS_IMAGE_TAG
	PEERPLAYS_IMAGE_TAG=${PEERPLAYS_IMAGE_TAG:-latest}
	PEERPLAYS_DOCKER_TAG="$PEERPLAYS_IMAGE:$PEERPLAYS_IMAGE_TAG"

	{
		echo -e "BRANCH=$BRANCH"
		echo -e "PEERPLAYS_IMAGE_TAG=$PEERPLAYS_IMAGE_TAG"
		echo -e "PEERPLAYS_IMAGE=$PEERPLAYS_IMAGE"
		echo -e "PEERPLAYS_DOCKER_TAG=$PEERPLAYS_DOCKER_TAG"
	} >>$HOME/.install_setting

	msg bold blue "Downloading Peerplays blockchain source code"
	git clone "${PEERPLAYS_DOCKER_SOURCE}"
	fmm="Low Memory Mode (For Seed / Witness nodes)"
	(($BUILD_FULL == 1)) && fmm="Full Memory Mode (For RPC nodes)" && DOCKER_DIR="$FULL_DOCKER_DIR"
	BUILD_MSG=" >> Building docker container [[ ${fmm} ]]"
	if (($# >= 1)); then
		"$@"
		sleep 2
		sudo cp ./peerplays-docker/data/witness_node_data_dir/config.ini.example ./peerplays-docker/data/witness_node_data_dir/config.ini
		sed -i.tmp 's/^required-participation\ \=\ .*$/required-participation\ \=\ false/' "$DATADIR"/witness_node_data_dir/config.ini
		sed -i "s/ARG\ PEERPLAYS_VERSION=.*$/ARG\ PEERPLAYS_VERSION="$BRANCH"/" "$DOCKER_DIR"/Dockerfile
		cd "$DOCKER_DIR" || exit

		msg bold green "$BUILD_MSG"
		sudo docker build "${BUILD_ARGS[@]}" -t "$PEERPLAYS_DOCKER_TAG" .
		ret=$?
		if (($ret == 0)); then
			echo "${RED}
	!!! !!! !!! !!! !!! !!! READ THIS !!! !!! !!! !!! !!! !!!
	!!! !!! !!! !!! !!! !!! READ THIS !!! !!! !!! !!! !!! !!!
		For your safety, we've tagged this image as $PEERPLAYS_DOCKER_TAG
		To use it in this peerplays-docker, run: 
		${GREEN}${BOLD}
		docker tag $PEERPLAYS_DOCKER_TAG ${DOCKER_IMAGE}:latest
		${RESET}${RED}
	!!! !!! !!! !!! !!! !!! READ THIS !!! !!! !!! !!! !!! !!!
	!!! !!! !!! !!! !!! !!! READ THIS !!! !!! !!! !!! !!! !!!
		${RESET}
			"
			msg bold green " +++ Successfully built peerplaysd"
			msg green " +++ Peerplays node type: ${BOLD}${fmm}"
			msg green " +++ Version/Branch: ${BOLD}${BUILD_VER}"
			msg green " +++ Build args: ${BOLD}${BUILD_ARGS[@]}"
			msg green " +++ Docker tag: ${PEERPLAYS_DOCKER_TAG}"
		else
			msg bold red " !!! ERROR: Something went wrong during the build process."
			msg red " !!! Please scroll up and check for any error output during the build."
		fi
		return
	fi
	msg bold green "$BUILD_MSG"
	cd "$DOCKER_DIR" || exit
	sudo docker build -t "$DOCKER_IMAGE" .
	ret=$?
	if (($ret == 0)); then
		msg bold green " +++ Successfully built current stable peerplaysd"
		msg green " +++ Peerplays node type: ${BOLD}${fmm}"
		msg green " +++ Docker tag: ${DOCKER_IMAGE}"
		msg bold green " Run ./run.sh start to start the Peerplays witness node"
	else
		msg bold red " !!! ERROR: Something went wrong during the build process."
		msg red " !!! Please scroll up and check for any error output during the build."
	fi
}

sci() {
	read -r -p "Enter docker image to be saved locally[Press Enter for default: peerplays:latest]: " PEERPLAYS_DOCKER_TAG
	PEERPLAYS_DOCKER_TAG=${PEERPLAYS_DOCKER_TAG:-"peerplays:latest"}
	read -r -p "Enter the directory where you want to save the Peerplays docker image [Press Enter for default: $PWD]: " SAVE_TO_DIRECTORY
	if [ -z "$SAVE_TO_DIRECTORY" ]; then
		SAVE_TO_DIRECTORY=$PWD
	else
		SAVE_TO_DIRECTORY=$(realpath "$SAVE_TO_DIRECTORY")
	fi

	msg bold blue "Saving the docker image !!!"
	if sudo docker save -o $SAVE_TO_DIRECTORY/peerplays_docker-image.tar "$PEERPLAYS_DOCKER_TAG"; then
		msg bold green "Saving the docker image $SAVE_TO_DIRECTORY/peerplays_docker-image.tar completed successfully"
		msg bold blue "Follow the following steps if you want to load the docker image on a new machine"
		msg bold blue "Run the command--> git clone https://gitlab.com/PBSA/PeerplaysIO/tools-libs/peerplays-docker && cd peerplays-docker"
		msg bold blue "Copy peerplays_docker-image.tar to the current working directory"
		msg bold blue "Run the command--> sudo docker load -i ./peerplays_docker-image.tar"
		msg bold blue "To run the peerplays docker container --> sudo docker run -p0.0.0.0:9777:9777 -v /dev/shm:/shm -v $PWD/data:/peerplays -d --name peerplays -t <DOCKER image> witness_node --data-dir=/peerplays/witness_node_data_dir"
	else
		msg bold green "Saving the docker image faile!!!"
	fi
}

# Build full memory node (for RPC nodes) as a docker image
# Usage: ./run.sh build_full [version]
# Version is prefixed with v, matching steem releases
# e.g. build_full v0.20.6
build_full() {
	BUILD_FULL=1
	build "$@"
}
# Usage: ./run.sh install_docker
# Downloads and installs the latest version of Docker using the Get Docker site
# If Docker is already installed, it should update it.
install_docker() {
	clear
	#figlet -tc "Peerplays Blockchain"
	msg bold green "Installing docker on the machine"

	sudo apt update
	# curl/git used by docker, xz/lz4 used by dlblocks, jq used by tslogs/pclogs
	sudo apt install -y curl git xz-utils liblz4-tool jq
	curl https://get.docker.com | sh
	if [ "$EUID" -ne 0 ]; then
		echo "Adding user $(whoami) to docker group"
		sudo usermod -aG docker "$(whoami)"
		echo "IMPORTANT: Please re-login (or close and re-connect SSH) for docker to function correctly"
	fi
}

# Usage: ./run.sh install [tag]
# Downloads the Steem low memory node image from someguy123's official builds, or a custom tag if supplied
#
#   tag - optionally specify a docker tag to install from. can be third party
#         format: user/repo:version    or   user/repo   (uses the 'latest' tag)
#
# If no tag specified, it will download the pre-set $DK_TAG in run.sh or .env
# Default tag is normally someguy123/steem:latest (official builds by the creator of steem-docker).
#
install() {
	clear
	#figlet -tc "Peerplays Blockchain"

	read -r -p "Enter Peerplays docker tag which you want to use for the docker container[Press Enter for default: latest]: " PEERPLAYS_IMAGE_TAG
	PEERPLAYS_IMAGE_TAG=${PEERPLAYS_IMAGE_TAG:-latest}
	PEERPLAYS_DOCKER_TAG="datasecuritynode/peerplays:$PEERPLAYS_IMAGE_TAG"

		echo "Enter the seed nodes"
		REPEAT=true
		i=1
		SEED_NODES=
        while $REPEAT; do
		    read -r -p "    seed node $i----> eg. 10.10.10.10:1234 ]: " SEED_NODES[$i]
			if [ -z "${SEED_NODES}" ]; then
			   SEED_NODES="\"${SEED_NODES[$i]}\""
			else
			   SEED_NODES="${SEED_NODES},\"${SEED_NODES[$i]}\""
			fi
			
            read -r -p "Do you wish to add more nodes? (Y/N) ]: " REPEAT
        if [[  "$REPEAT" = "Y"  ]]; then
		   REPEAT=true
		   i=$((i+1))
		else
		   REPEAT=false
		fi
        done
		SEED_COUNT=$i
		{ echo -e "SEED_NODES=$SEED_NODES"; echo -e "SEED_COUNT=$SEED_COUNT"; } >>"$HOME"/.install_setting
		unset i SEED_COUNT REPEAT
	
	{ echo -e "PEERPLAYS_IMAGE_TAG=$PEERPLAYS_IMAGE_TAG"; echo -e "PEERPLAYS_DOCKER_TAG=$PEERPLAYS_DOCKER_TAG"; } >>"$HOME"/.install_setting
	
	git clone "${PEERPLAYS_DOCKER_SOURCE}" -b release
	sudo cp ./peerplays-docker/data/witness_node_data_dir/config.ini.example ./peerplays-docker/data/witness_node_data_dir/config.ini
	sed -i.tmp 's/^required-participation\ \=\ .*$/required-participation\ \=\ false/' "$DATADIR"/witness_node_data_dir/config.ini
	sed -i.tmp "s/^seed-nodes\ \=\ .*$/seed-nodes\ \=\ \[$SEED_NODES\]/" "$DATADIR"/witness_node_data_dir/config.ini
	msg bold green "Installing image $PEERPLAYS_IMAGE_TAG"
	sleep 2
	msg yellow " -> Loading image from ${PEERPLAYS_DOCKER_TAG}"
	sudo docker pull "$PEERPLAYS_DOCKER_TAG"
	msg green " -> Tagging as peerplays"
	sudo docker tag "$PEERPLAYS_DOCKER_TAG" peerplays
	msg bold green " -> Installation completed. You may now configure or run the server"
}

# Usage: ./run.sh install_full
# Downloads the Steem full node image from the pre-set $DK_TAG_FULL in run.sh or .env
# Default tag is normally someguy123/steem:latest-full (official builds by the creator of steem-docker).
#
install_full() {
	msg yellow " -> Loading image from ${DK_TAG_FULL}"
	docker pull "$DK_TAG_FULL"
	msg green " -> Tagging as steem"
	docker tag "$DK_TAG_FULL" steem
	msg bold green " -> Installation completed. You may now configure or run the server"
}

# Internal Use Only
# Checks if the container $DOCKER_NAME exists. Returns 0 if it does, -1 if not.
# Usage:
# if seed_exists; then echo "true"; else "false"; fi
#
seed_exists() {
	seedcount=$(sudo docker ps -a -f name="^/"$DOCKER_NAME"$" | wc -l)
	if [[ $seedcount -eq 2 ]]; then
		return 0
	else
		return -1
	fi
}

# Internal Use Only
# Checks if the container $DOCKER_NAME exists. Returns 0 if it does, -1 if not.
# Usage:
# if bitcoin_exists; then echo "true"; else "false"; fi
#
bitcoin_exists() {
	bitcoindcount=$(sudo docker ps -a -f name="^/"$DOCKER_BITCOIN_NAME"$" | wc -l)
	if [[ $bitcoindcount -eq 2 ]]; then
		return 0
	else
		return -1
	fi
}

# Internal Use Only
# Checks if the container $DOCKER_NAME is running. Returns 0 if it's running, -1 if not.
# Usage:
# if seed_running; then echo "true"; else "false"; fi
#
seed_running() {
	seedcount=$(sudo docker ps -f 'status=running' -f "name=$DOCKER_NAME" | wc -l)
	if [[ $seedcount -eq 2 ]]; then
		return 0
	else
		return 1
	fi
}

# stop_seed_running [stop_or_exit=1]
# If the container is running, alert the user and ask if they want to stop the container now.
# By default, if the user says no, 'exit 1' will be called to terminate the script.
#
# If you pass 0 or 'no' as the first argument, then instead of force exiting, a warning will
# be displayed to the user warning that not stopping the container is unsafe, and giving them
# 10 seconds to press CTRL-C in-case they change their minds. Once the 10 second wait is over,
# the function simply returns exit code 1, for the callee function to appropriately handle.
#
stop_seed_running() {
	local stop_or_exit=1
	(($# > 0)) && stop_or_exit="$1"
	if seed_running; then
		msg err red "WARNING: Your $DOCKER_NAME server ($DOCKER_NAME) is currently running"
		echo
		sudo docker ps
		echo
		read -r -p "Do you want to stop the container now? (y/n): " RESPONSE
		RESPONSE=${RESPONSE:-N}
		RESPONSE_IC="$(echo "$RESPONSE" | tr '[:lower:]' '[:upper:]')"
		if [ "$RESPONSE_IC" == "Y" ]; then
			stop
		else
			msg red "You said no. Cannot continue safely without stopping the container first. Aborting."
			exit 1
		fi
	else
		return 0
	fi
}

# remove_seed_exists [stop_or_exit=1]
# Remove the container DOCKER_NAME if it exists, calling 'stop_seed_running' beforehand to ensure
# that the container is stopped.
#
# The first argument, 'stop_or_exit' is passed through to stop_seed_running. See comments for
# that function for info on that.
remove_seed_exists() {
	local stop_or_exit=1
	(($# > 0)) && stop_or_exit="$1"
	stop_seed_running "$stop_or_exit"

	if seed_exists; then
		msg yellow " -> Removing old container '${DOCKER_NAME}'"
		sudo docker rm "$DOCKER_NAME"
	fi
}

# docker_run_node [steemd extra arguments]
# Create and start a container to run DKR_RUN_BIN (usually `steemd`), appending any arguments from this
# function to the steemd command line arguments.
#
# When ran without arguments, should produce a command which looks like:
#   docker run -p 0.0.0.0:2001:2001 -v /hive/data:/steem -d --name $DOCKER_NAME
#       -t $DOCKER_IMAGE steemd --data-dir=/steem/witness_node_data_dir
docker_run_node() {
	: "${DKR_RUN_ADD_DATA_DIR=1}"
	local stm_run_args=()

	#(( DKR_RUN_ADD_DATA_DIR )) && stm_run_args+=("--data-dir=${DATADIR}")
	((DKR_RUN_ADD_DATA_DIR)) && stm_run_args+=("--data-dir=${DATADIR}/witness_node_data_dir")

	stm_run_args+=("${STEEM_RUN_ARGS[@]}" "$@")
	_docker_run "${DKR_RUN_BIN}" "${stm_run_args[@]}"

}

docker_run_wallet() {
	local ws_node="$REMOTE_WS"
	(($# > 0)) && ws_node="$1"
	_docker_int_autorm cli_wallet -s "$ws_node" "${@:2}"
}

# docker_run_base [image_executable] [exe_args]
# Works the same as _docker_run, but defaults the following env variables to 0 instead
# of the default 1 set by _docker_run:
#
#   RUN_DETACHED DKR_USE_NAME DKR_MOUNT_VOLS DKR_EXPOSE_PORTS
#
_docker_run_base() {
	: "${RUN_DETACHED=0}"
	: "${DKR_USE_NAME=0}"
	: "${DKR_MOUNT_VOLS=0}"
	: "${DKR_EXPOSE_PORTS=0}"
	_docker_run "$@"
}

# docker_int_autorm [image_executable] [exe_args]
# _docker_run_base wrapper for "interactive auto-removing" containers.
# Mostly the same as _docker_run_base, except DKR_MOUNT_VOLS defaults to 1,
# and the docker args '--rm' and '-i' are appended to DKR_RUN_ARGS
_docker_int_autorm() {
	: "${DKR_MOUNT_VOLS=1}"
	DKR_RUN_ARGS=("--rm" "-i")
	_docker_run_base "$@"
}

# docker_run [image_executable] [exe_args]
# Creates and starts a docker container with `docker run`, while automatically
# building parts of the command for mounting volumes / exposing ports etc.
# based on env vars such as `DKR_VOLUMES`, `DPORTS`, and others.
#
# Example:
#   _docker_run steemd --data-dir=/steem/witness_node_data_dir
#   RUN_DETACHED=0 DKR_USE_NAME=0 DKR_EXPOSE_PORTS=0 _docker_run cli_wallet -s "wss://hived.privex.io"
#
_docker_run() {
	local x_run_args=("$@")

	_CMD=(
		sudo docker run
	)
	: "${RUN_DETACHED=1}"
	: "${DKR_USE_NAME=1}"
	: "${DKR_MOUNT_VOLS=1}"
	: "${DKR_EXPOSE_PORTS=1}"

	echo "PORTS" "$DKR_EXPOSE_PORTS"
	echo "COMMAND" "$_CMD"
	((DKR_EXPOSE_PORTS)) && _CMD+=("${DPORTS[@]}")

	if ((DKR_MOUNT_VOLS)); then
		# Iterate over DKR_VOLUMES to generate docker volume mount arguments
		for v in "${DKR_VOLUMES[@]}"; do
			_CMD+=("-v" "$v")
		done
	fi

	((RUN_DETACHED)) && _CMD+=('-d')
	((${#DKR_RUN_ARGS[@]} > 0)) && _CMD+=("${DKR_RUN_ARGS[@]}")

	((DKR_USE_NAME)) && _CMD+=("--name" "$DOCKER_NAME")

	_CMD+=("-t" "$PEERPLAYS_DOCKER_TAG")

	((${#x_run_args[@]} > 0)) && _CMD+=("${x_run_args[@]}")

	if ((DKR_DRY_RUN)); then
		echo "Would've ran the following command:"
		echo "${_CMD[@]}"
	else
		env "${_CMD[@]}"
	fi
}

# Usage: ./run.sh start
# Creates and/or starts the Steem docker container
start() {
	msg bold green " -> Starting container '${DOCKER_NAME}'..."
	PEERPLAYS_DOCKER_TAG="$(grep PEERPLAYS_DOCKER_TAG "$HOME"/.install_setting | awk -F= '{print $2}')"
	seed_exists
	if [[ $? == 0 ]]; then
		if sudo docker start "$DOCKER_NAME"; then
			msg bold green "Witness node started, now you can view the logs using ./run.sh logs"
		else
			msg bold red "Witness node docker container failed to start!!!"
			exit
		fi
	else
		CHECK_MODE=$(grep MODE "$HOME"/.install_setting | awk -F= '{print $2}')
		if [ "$CHECK_MODE" = "WITNESS_DOCKER" ]; then

			if sudo docker run "${DPORTS[@]}" -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name "$DOCKER_NAME" -t "$PEERPLAYS_DOCKER_TAG" witness_node --data-dir=/peerplays/witness_node_data_dir; then
				msg bold green "Peerplays witness docker container started successfully, now you can view the logs using ./run.sh logs"
			else
				msg bold red "Peerplays witness node docker container failed to start!!!"
				exit
			fi
		elif [ "$CHECK_MODE" = "SON_DOCKER" ]; then
			if sudo docker run "${DPORTS[@]}" --entrypoint /peerplays/son-entrypoint.sh --network ${DOCKER_NETWORK} -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name $DOCKER_NAME -t datasecuritynode/peerplays:son-dev witness_node --data-dir=/peerplays/witness_node_data_dir; then
				msg bold green "Peerplays SON docker container started successfully, you can view the logs using ./run.sh logs"
			else
				msg bold red "Peerplays SON docker container failed to start!!!"
				exit
			fi
		elif [ "$CHECK_MODE" = "SON_TEST_DOCKER" ]; then
			if sudo docker run "${DPORTS[@]}" --network ${DOCKER_NETWORK} -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name $DOCKER_NAME -t datasecuritynode/peerplays:son-dev witness_node --data-dir=/peerplays/witness_node_data_dir; then
				msg bold green "Peerplays SON docker container(test mode) started successfully, you can view the logs using ./run.sh logs"
			else
				msg bold red "Peerplays SON docker container(test mode) failed to start!!!"
				exit
			fi
		elif [ "$CHECK_MODE" = "SEED_DOCKER" ]; then
			if sudo docker run "${DPORTS[@]}" -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name ${DOCKER_NAME} -t ${PEERPLAYS_DOCKER_TAG} witness_node --data-dir=/peerplays/witness_node_data_dir; then
				msg bold green "Peerplays seed docker container started successfully, you can view the logs using ./run.sh logs"
			else
				msg bold red "Peerplays seed docker container failed to start!!!"
				exit
			fi	
		fi
	fi
}

# Usage: ./run.sh replay
# Replays the blockchain for the Steem docker container
# If steem is already running, it will ask you if you still want to replay
# so that it can stop and remove the old container
#
steem_replay() {
	remove_seed_exists 1
	local p_msg=" -> Running $DOCKER_IMAGE (image: ${DOCKER_IMAGE}) with replay in container '${DOCKER_NAME}'"
	(($# > 0)) && p_msg+=" - extra args: '$*'..." || p_msg+="..."
	msg green "$p_msg"
	docker_run_node --replay-blockchain "$@"
	msg bold green " -> Started."
}

#INTERNAL
peerplays_docker_replay() {
	remove_seed_exists 1
	CHECK_MODE=$(grep MODE "$HOME"/.install_setting | awk -F= '{print $2}')
	if [ "$CHECK_MODE" = "WITNESS_DOCKER" ]; then
		if sudo docker run "${DPORTS[@]}" -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name "$DOCKER_NAME" -t "$DOCKER_IMAGE" witness_node --replay-blockchain --data-dir=/peerplays/witness_node_data_dir; then
			msg bold green "Replay of witness node started successfully"
		else
			msg bold red "Replay of witness node failed !!!"
		fi
	else
		if sudo docker run "${DPORTS[@]}" --entrypoint /peerplays/son-entrypoint.sh --network ${DOCKER_NETWORK} -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name $DOCKER_NAME -t datasecuritynode/peerplays:son-dev witness_node --replay-blockchain --data-dir=/peerplays/witness_node_data_dir; then
			msg bold green "Replay of SON docker container started successfully"
		else
			msg bold red "SON docker container failed to start!!!"
			exit
		fi
	fi
}

#INTERNAL
peerplays_replay() {
	msg bold green "Replaying the blockchain"
	INSTALL_ABS_DIR="$(grep DIRECTORY "$HOME"/.install_setting | awk -F= '{print $2}')"
	msg bold red "Stoping the Peerplays Blockchain Replay Service"
	if ! sudo systemctl stop peerplays.service; then
		msg bold red "Peerplays witness node stop failed!!!!!"
		exit
	else
		if ! sudo systemctl list-unit-files --type service | grep peerplays-replay.service; then
			msg bold blue "Creating Peerplays Blockchain Replay Service"
			echo -e "[Unit]" >"$INSTALL_ABS_DIR"/peerplays.service
			{
				echo -e "Description=Peerplays Witness Node\n"
				echo -e "[Service]"
				echo -e "User=$(whoami)"
				echo -e "WorkingDirectory=$INSTALL_ABS_DIR"
				echo -e "ExecStart=$INSTALL_ABS_DIR/src/peerplays/programs/witness_node/witness_node --replay-blockchain"
				echo -e "Restart=always\n"
				echo -e "[Install]"
				echo -e "WantedBy=mult-user.target"
			} >>"$INSTALL_ABS_DIR"/peerplays-replay.service
			msg bold blue "Starting Peerplays Blockchain replay service"
			sudo cp "$INSTALL_ABS_DIR"/peerplays-replay.service /etc/systemd/system && sudo systemctl start peerplays-replay.service
			sleep 30
		else
			msg bold blue "Starting Peerplays Blockchain replay service"
			sudo systemctl start peerplays-replay.service
			sleep 30
		fi
		if [ "$(systemctl is-active peerplays-replay.service)" = "active" ]; then
			msg bold green "Peerplays witness replay started successfully. You can monitor the logs using ./run.sh logs"
		else
			msg bold red "Peerplays witness node replay failed!!!!!"
			exit
		fi
	fi
}

# Usage: ./run.sh replay
replay() {
	if [ -f "$HOME"/.install_setting ]; then
		if ! sudo systemctl list-unit-files --type service | grep peerplays; then
			peerplays_docker_replay
		else
			peerplays_replay
		fi
	else
		msg bold red "Peerplays Blockchain not present on this server/not installed using run.sh"
	fi
}

# For MIRA, you can replay with --memory-replay to tell steemd to store as much chainstate as it can in memory,
# instead of constantly reading/writing it to the disk RocksDB files.
# WARNING: Consumes a ridiculous amount of memory compared to standard MIRA replay and non-MIRA replay
# (somewhere around 120GB for low memory mode with basic plugins...)
memory_replay() {
	remove_seed_exists 1
	echo "Removing old container"
	docker rm "$DOCKER_NAME"
	echo "Running ${NETWORK_NAME} with --memory-replay..."
	docker_run_node --replay --memory-replay "$@"
	echo "Started."
}

# Usage: ./run.sh shm_size size
# Resizes the ramdisk used for storing Steem's shared_memory at /dev/shm
# Size should be specified with G (gigabytes), e.g. ./run.sh shm_size 64G
#
shm_size() {
	if (($# < 1)); then
		msg red "Please specify a size, such as ./run.sh shm_size 64G"
	fi
	msg green " -> Setting /dev/shm to $1"
	if sudo mount -o "remount,size=$1" /dev/shm; then
		msg bold green "Successfully resized /dev/shm"
	else
		msg bold red "An error occurred while resizing /dev/shm..."
		msg red "Make sure to specify size correctly, e.g. 64G. You can also try using sudo to run this."
	fi
}

# Usage: ./run.sh stop
# Stops the Steem container, and removes the container to avoid any leftover
# configuration, e.g. replay command line options
#
stop() {
	msg "If you don't care about a clean stop, you can force stop the container with ${BOLD}./run.sh kill"
	msg red "Stopping container '${DOCKER_NAME}' (allowing up to ${STOP_TIME} seconds before killing)..."
	sudo docker stop -t ${STOP_TIME} $DOCKER_NAME
	msg red "Removing old container '${DOCKER_NAME}'..."
	sudo docker rm "$DOCKER_NAME"
}

kill() {
	msg bold red "Killing container '${DOCKER_NAME}'..."
	sudo docker kill "$DOCKER_NAME"
	msg red "Removing container ${DOCKER_NAME}"
	sudo docker rm "$DOCKER_NAME"
}

# Usage: ./run.sh enter
# Enters the running docker container and opens a bash shell for debugging
#
enter() {
	docker exec -it $DOCKER_NAME bash
}

# Usage: ./run.sh shell
# Runs the container similar to `run` with mounted directories,
# then opens a BASH shell for debugging
# To avoid leftover containers, it uses `--rm` to remove the container once you exit.
#
shell() {
	_docker_int_autorm bash
	# docker run ${DPORTS[@]} -v "$SHM_DIR":/shm -v "$DATADIR":/steem --rm -it "$DOCKER_IMAGE" bash
}

# Usage: ./run.sh wallet
# Opens cli_wallet inside of the running Steem container and
# connects to the local steemd over websockets on port 8090
#
wallet() {
	docker exec -it $DOCKER_NAME cli_wallet -s ws://127.0.0.1:8090
}

# Usage: ./run.sh remote_wallet [wss_server]
# Connects to a remote websocket server for wallet connection. This is completely safe
# as your wallet/private keys are never sent to the remote server.
#
# By default, it will connect to wss://steemd.privex.io:443 (ws = normal websockets, wss = secure HTTPS websockets)
# See this link for a list of WSS nodes: https://www.steem.center/index.php?title=Public_Websocket_Servers
#
#    wss_server - a custom websocket server to connect to, e.g. ./run.sh remote_wallet wss://rpc.steemviz.com
#
remote_wallet() {
	if (($# >= 1)); then
		REMOTE_WS="$1"
	fi
	# DKR_RUN_ARGS="--rm -i" RUN_DETACHED=0 DKR_RUN_ADD_DATA_DIR=0
	# DKR_RUN_BIN="cli_wallet"
	# docker run -v "$DATADIR":/steem --rm -it "$DOCKER_IMAGE" cli_wallet -s "$REMOTE_WS"
	docker_run_wallet "$REMOTE_WS"
}

# Usage: ./run.sh logs
# Shows the last 30 log lines of the running steem container, and follows the log until you press ctrl-c
#
logs() {
	if [ "$(systemctl is-active peerplays.service)" = "active" ]; then
		msg bold green "Tailing Peerplays service logs"
		#WITNESS_SCRIPT=`systemctl status peerplays|grep ExecStart |awk -F\= '{print $2}'|sed -e 's/[^ ]* *$//'`
		#WITNESS_SCRIPT_DIR=`systemctl status peerplays|grep witness|grep peerplays|awk '{print $2}'|xargs dirname`
		sudo journalctl -f -u peerplays
		exit
	elif [ "$(systemctl is-active peerplays-replay.service)" = "active" ]; then
		msg bold green "Tailing Peerplays service logs"
		#WITNESS_SCRIPT=`systemctl status peerplays|grep ExecStart |awk -F\= '{print $2}'|sed -e 's/[^ ]* *$//'`
		#WITNESS_SCRIPT_DIR=`systemctl status peerplays|grep witness|grep peerplays|awk '{print $2}'|xargs dirname`
		sudo journalctl -f -u peerplays-replay
		exit
	else
		msg blue "DOCKER LOGS: (press ctrl-c to exit) "
		sudo docker logs -f --tail=30 "$DOCKER_NAME"
		exit
	fi
	#echo $RED"INFO AND DEBUG LOGS: "$RESET
	#tail -n 30 $DATADIR/{info.log,debug.log}
}

# Usage: ./run.sh pclogs
# (warning: may require root to work properly in some cases)
# Used to watch % replayed during blockchain replaying.
# Scans and follows a large portion of your steem logs then filters to only include the replay percentage
#   example:    2018-12-08T23:47:16    22.2312%   6300000 of 28338603   (60052M free)
#
pclogs() {
	if [[ ! $(command -v jq) ]]; then
		msg red "jq not found. Attempting to install..."
		sleep 3
		sudo apt-get update -y >/dev/null
		sudo apt-get install -y jq >/dev/null
	fi
	local LOG_PATH=$(docker inspect "$DOCKER_NAME" | jq -r .[0].LogPath)
	local pipe="$(mktemp).fifo"
	trap "rm -f '$pipe'" EXIT
	if [[ ! -p "$pipe" ]]; then
		mkfifo "$pipe"
	fi
	# the sleep is a dirty hack to keep the pipe open

	sleep 1000000 <"$pipe" &
	tail -n 5000 -f "$LOG_PATH" &>"$pipe" &
	while true; do
		if read -r line <"$pipe"; then
			# first grep the data for "objects cached" to avoid
			# needlessly processing the data
			L=$(egrep --colour=never "objects cached|M free" <<<"$line")
			if [[ $? -ne 0 ]]; then
				continue
			fi
			# then, parse the line and print the time + log
			L=$(jq -r ".time +\" \" + .log" <<<"$L")
			# then, remove excessive \r's causing multiple line breaks
			L=$(sed -e "s/\r//" <<<"$L")
			# now remove the decimal time to make the logs cleaner
			L=$(sed -e 's/\..*Z//' <<<"$L")
			# and finally, strip off any duplicate new line characters
			L=$(tr -s "\n" <<<"$L")
			printf '%s\r\n' "$L"
		fi
	done
}

# Original grep/sed snippet made by @drakos
clean-logs() {
	msgerr cyan "Monitoring and cleaning replay logs for ${DOCKER_NAME}"

	docker logs --tail=5000000 -f -t "$DOCKER_NAME" |
		grep -E '[0-9]{2}%.*M free|[0-9]{2}%.*objects cached|Performance report at block|Done reindexing|Migrating state to disk|Converting index.*to mira type' |
		sed -e "s/\r\x1B\[0m//g"
}

# Usage: ./run.sh tslogs
# (warning: may require root to work properly in some cases)
# Shows the Steem logs, but with UTC timestamps extracted from the docker logs.
# Scans and follows a large portion of your steem logs, filters out useless data, and appends a
# human readable timestamp on the left. Time is normally in UTC, not your local. Example:
#
#   2018-12-09T01:04:59 p2p_plugin.cpp:212            handle_block         ] Got 21 transactions
#                   on block 28398481 by someguy123 -- Block Time Offset: -345 ms
#
tslogs() {
	if [[ ! $(command -v jq) ]]; then
		msg red "jq not found. Attempting to install..."
		sleep 3
		sudo apt update
		sudo apt install -y jq
	fi
	local LOG_PATH=$(docker inspect "$DOCKER_NAME" | jq -r .[0].LogPath)
	local pipe="$(mktemp).fifo"
	trap "rm -f '$pipe'" EXIT
	if [[ ! -p "$pipe" ]]; then
		mkfifo "$pipe"
	fi
	# the sleep is a dirty hack to keep the pipe open

	sleep 10000 <"$pipe" &
	tail -n 100 -f "$LOG_PATH" &>"$pipe" &
	while true; do
		if read -r line <"$pipe"; then
			# first, parse the line and print the time + log
			L=$(jq -r ".time +\" \" + .log" <<<"$line")
			# then, remove excessive \r's causing multiple line breaks
			L=$(sed -e "s/\r//" <<<"$L")
			# now remove the decimal time to make the logs cleaner
			L=$(sed -e 's/\..*Z//' <<<"$L")
			# remove the steem ms time because most people don't care
			L=$(sed -e 's/[0-9]\+ms //' <<<"$L")
			# and finally, strip off any duplicate new line characters
			L=$(tr -s "\n" <<<"$L")
			printf '%s\r\n' "$L"
		fi
	done
}

# Internal use only
# Used by `ver` to pretty print new commits on origin/master
simplecommitlog() {
	local commit_format
	local args
	commit_format=""
	commit_format+="    - Commit %Cgreen%h%Creset - %s %n"
	commit_format+="      Author: %Cblue%an%Creset %n"
	commit_format+="      Date/Time: %Cblue%ai%Creset%n"
	if [[ "$#" -lt 1 ]]; then
		echo "Usage: simplecommitlog branch [num_commits]"
		echo "invalid use of simplecommitlog. exiting"
		exit 1
	fi
	branch="$1"
	args="$branch"
	if [[ "$#" -eq 2 ]]; then
		count="$2"
		args="-n $count $args"
	fi
	git --no-pager log --pretty=format:"$commit_format" $args
}

#INTERNAL
# Checks if the son network exists. Returns 0 if it does, -1 if not.
# Usage:
# if son_network_exists; then echo "true"; else "false"; fi
#
son_network_exists() {
	networkcount=$(sudo docker network ls | grep -c son)
	if [[ $networkcount -eq 2 ]]; then
		return 0
	else
		return -1
	fi
}

# Internal Use Only
# Checks if the bitcoin container exists. Returns 0 if it does, -1 if not.
# Usage:
# if bitcoin_regtest_exists; then echo "true"; else "false"; fi
#
bitcoin_regtest_exists() {
	networkcount=$(sudo docker ps -a -f name="^/"$DOCKER_BITCOIN_NAME"$" | wc -l)
	if [[ $networkcount -eq 2 ]]; then
		return 0
	else
		return -1
	fi
}

# Usage: ./run.sh start_son_regtest
# Creates and/or starts the Peerplays SON docker container with a Bitcoin regtest node in a created docker network.
start_son_regtest() {
	set_variables
	msg yellow " -> Verifying network '${DOCKER_NETWORK}'..."
	son_network_exists
	if [[ $? == 0 ]]; then
		msg yellow " -> Network '${DOCKER_NETWORK}' exists"
	else
		sudo docker network create ${DOCKER_NETWORK}
	fi

	msg bold green " -> Starting container $DOCKER_BITCOIN_NAME ..."
	bitcoin_regtest_exists
	if [[ $? == 0 ]]; then
		sudo docker start $DOCKER_BITCOIN_NAME
	else
	    BTC_REGTEST_CONF=$DIRECTORY/peerplays-docker/bitcoin/regtest/bitcoin.conf
		sudo docker volume create ${DOCKER_BITCOIN_VOLUME}
		sudo docker run -v $DOCKER_BITCOIN_VOLUME:/bitcoin --name=$DOCKER_BITCOIN_NAME -d -p 8333:8333 -p 127.0.0.1:8332:8332 -v $BTC_REGTEST_CONF:/bitcoin/.bitcoin/bitcoin.conf --network ${DOCKER_NETWORK} ${BITCOIN_DOCKER_TAG}
		sleep 40
		sudo docker exec $DOCKER_BITCOIN_NAME bitcoin-cli createwallet ${BITCOIN_WALLET}
		sudo docker exec $DOCKER_BITCOIN_NAME bitcoin-cli -rpcwallet=${BITCOIN_WALLET} importprivkey ${BTC_REGTEST_KEY}
	fi

	msg bold green " -> Starting container '${DOCKER_NAME}'..."
	seed_exists
	if [[ $? == 0 ]]; then
		sudo docker start $DOCKER_NAME
	else
		cd $DIRECTORY/peerplays-docker || exit
		sudo cp ./example.env ./.env || exit
		cd ./scripts/regtest || exit
		sudo ./replace_btc_conf.sh
		cd ../.. || exit
		sudo cp ./data/witness_node_data_dir/config.ini.son-exists.example ./data/witness_node_data_dir/config.ini
		sed -i.tmp "s/^seed-nodes\ \=\ .*$/seed-nodes\ \=\ \[$SEED_NODES\]/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^enable-stale-production\ \=\ .*$/enable-stale-production\ \=\ true/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^#\ bitcoin-private-key\ \=\ .*$/bitcoin-private-key\ \=\ \[\"$BTC_PUBLIC_KEY\",\"$BTC_PRIVATE_KEY\"\]/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^#\ peerplays-private-key\ \=\ .*$/peerplays-private-key\ \=\ \[\"$SON_PUBLIC_KEY\",\"$SON_PRIVATE_KEY\"\]/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^bitcoin-wallet\ \=\ .*$/bitcoin-wallet\ \=\ $BITCOIN_WALLET/" "$DATADIR"/witness_node_data_dir/config.ini

		if sudo docker run "${DPORTS[@]}" --entrypoint /peerplays/son-entrypoint.sh --network ${DOCKER_NETWORK} -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name $DOCKER_NAME -t datasecuritynode/peerplays:son-dev witness_node --data-dir=/peerplays/witness_node_data_dir; then
			msg bold green " Installation successful, you can view the logs using ./run.sh logs"
		fi

	fi
}

# Usage: ./run.sh start_son
# Creates and/or starts the Peerplays SON docker container.
start_son() {
	set_variables
	msg bold green " -> Starting container '${DOCKER_NAME}'..."
	seed_exists
	if [[ $? == 0 ]]; then
		sudo docker start $DOCKER_NAME
	else
		cd $DIRECTORY/peerplays-docker || exit
		sudo cp ./data/witness_node_data_dir/config.ini.son-exists.example ./data/witness_node_data_dir/config.ini
		sed -i.tmp "s/^seed-nodes\ \=\ .*$/seed-nodes\ \=\ \[$SEED_NODES\]/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^enable-stale-production\ \=\ .*$/enable-stale-production\ \=\ true/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^bitcoin-node-ip .*$/bitcoin-node-ip\ \=\ $BITCOIN_IP/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^bitcoin-node-zmq-port\ \=\ .*$/bitcoin-node-zmq-port\ \=\ $BITCOIN_ZMQ_PORT/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^bitcoin-node-rpc-port\ \=\ .*$/bitcoin-node-rpc-port\ \=\ $BITCOIN_RPC_PORT/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^bitcoin-node-rpc-user\ \=\ .*$/bitcoin-node-rpc-user\ \=\ $BITCOIN_RPC_USER/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^bitcoin-node-rpc-password\ \=\ .*$/bitcoin-node-rpc-password\ \=\ $BITCOIN_RPC_PASSWORD/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^bitcoin-wallet\ \=\ .*$/bitcoin-wallet\ \=\ $BITCOIN_WALLET/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^bitcoin-wallet-password\ \=\ .*$/bitcoin-wallet-password\ \=\ $BITCOIN_WALLET_PASSWORD/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^#\ bitcoin-private-key\ \=\ .*$/bitcoin-private-key\ \=\ \[\"$BTC_PUBLIC_KEY\",\"$BTC_PRIVATE_KEY\"\]/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^#\ peerplays-private-key\ \=\ .*$/peerplays-private-key\ \=\ \[\"$SON_PUBLIC_KEY\",\"$SON_PRIVATE_KEY\"\]/" "$DATADIR"/witness_node_data_dir/config.ini

		if sudo docker run "${DPORTS[@]}" -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name ${DOCKER_NAME} -t ${PEERPLAYS_DOCKER_TAG} witness_node --data-dir=/peerplays/witness_node_data_dir; then
			msg bold green " Installation successful, you can view the logs using ./run.sh logs"
		fi

	fi
}

# Usage: ./run.sh start_seed
# Creates and/or starts the Peerplays seed docker container.
start_seed() {
	set_variables
	msg bold green " -> Starting container '${DOCKER_NAME}'..."
	seed_exists
	if [[ $? == 0 ]]; then
		sudo docker start $DOCKER_NAME
	else
		cd $DIRECTORY/peerplays-docker || exit
		sudo cp ./data/witness_node_data_dir/config.ini.example ./data/witness_node_data_dir/config.ini
		#sudo cp ./data/witness_node_data_dir/seed_config.ini ./data/witness_node_data_dir/config.ini
		#sed -i.tmp "s/^seed-nodes\ \=\ .*$/seed-nodes\ \=\ \[$SEED_NODES\]/" "$DATADIR"/witness_node_data_dir/config.ini
		
		sed -i.tmp "0,/^p2p-seed-node\ \=\ .*$/s//seed-nodes\ \=\ \[$SEED_NODES\]/" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^plugin\ \=\ .*$/plugins\ \=\ market_history accounts_list affiliate_stats/" "$DATADIR"/witness_node_data_dir/config.ini
		
		sed -i.tmp "s/^p2p-seed-node\ \=\ .*$/#p2p-seed-node /" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^log-appender\ \=\ .*$/#log-appender /" "$DATADIR"/witness_node_data_dir/config.ini
		sed -i.tmp "s/^log-logger\ \=\ .*$/#log-logger /" "$DATADIR"/witness_node_data_dir/config.ini
		
		sed -i.tmp 's/^required-participation\ \=\ .*$/required-participation\ \=\ false/' "$DATADIR"/witness_node_data_dir/config.ini		
		if sudo docker run "${DPORTS[@]}" -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name ${DOCKER_NAME} -t ${PEERPLAYS_DOCKER_TAG} witness_node --data-dir=/peerplays/witness_node_data_dir; then
			msg bold green " Installation successful, you can view the logs using ./run.sh logs"
		fi

	fi
}

# Usage: ./run.sh ver
# Displays information about your Steem-in-a-box version, including the docker container
# as well as the scripts such as run.sh. Checks for updates using git and DockerHub API.
#
ver() {
	LINE="==========================="
	####
	# Update git, so we can detect if we're outdated or not
	# Also get the branch to warn people if they're not on master
	####
	git remote update >/dev/null
	current_branch=$(git branch | grep '\*' | cut -d ' ' -f2)
	git_update=$(git status -uno)

	####
	# Print out the current branch, commit and check upstream
	# to return commits that can be pulled
	####
	echo "${BLUE}Current ${SELF_NAME} version:${RESET}"
	echo "    Branch: $current_branch"
	if [[ "$current_branch" != "master" ]]; then
		echo "${RED}WARNING: You're not on the master branch. This may prevent you from updating${RESET}"
		echo "${GREEN}Fix: Run 'git checkout master' to change to the master branch${RESET}"
	fi
	# Warn user of modified core files
	git_status=$(git status -s)
	modified=0
	while IFS='' read -r line || [[ -n "$line" ]]; do
		if grep -q " M " <<<$line; then
			modified=1
		fi
	done <<<"$git_status"
	if [[ "$modified" -ne 0 ]]; then
		echo "    ${RED}ERROR: Your ${SELF_NAME} core files have been modified (see 'git status'). You will not be able to update."
		echo "    Fix: Run 'git reset --hard' to reset all core files back to their originals before updating."
		echo "    This will not affect your running witness, or files such as config.ini which are supposed to be edited by the user${RESET}"
	fi
	echo "    ${BLUE}Current Commit:${RESET}"
	simplecommitlog "$current_branch" 1
	echo
	echo
	# Check for updates and let user know what's new
	if grep -Eiq "up.to.date" <<<"$git_update"; then
		echo "    ${GREEN}Your ${SELF_NAME} core files (run.sh, Dockerfile etc.) up to date${RESET}"
	else
		echo "    ${RED}Your ${SELF_NAME} core files (run.sh, Dockerfile etc.) are outdated!${RESET}"
		echo
		echo "    ${BLUE}Updates in the current published version of ${SELF_NAME}:${RESET}"
		simplecommitlog "HEAD..origin/master"
		echo
		echo
		echo "    Fix: ${YELLOW}Please run 'git pull' to update your ${SELF_NAME}. This should not affect any running containers.${RESET}"
	fi
	echo $LINE

	####
	# Show the currently installed image information
	####
	echo "${BLUE}Hive/Steem image installed:${RESET}"
	# Pretty printed docker image ID + creation date
	dkimg_output=$(sudo docker images -f "reference=${DOCKER_IMAGE}:latest" --format "Tag: {{.Repository}}, Image ID: {{.ID}}, Created At: {{.CreatedSince}}")
	# Just the image ID
	dkimg_id=$(sudo docker images -f "reference=${DOCKER_IMAGE}:latest" --format "{{.ID}}")
	# Used later on, for commands that depend on the image existing
	got_dkimg=0
	if [[ $(wc -c <<<"$dkimg_output") -lt 10 ]]; then
		echo "${RED}WARNING: We could not find the currently installed image (${DOCKER_IMAGE})${RESET}"
		echo "${RED}Make sure it's installed with './run.sh install' or './run.sh build'${RESET}"
	else
		echo "    $dkimg_output"
		got_dkimg=1
		echo "${BLUE}Checking for updates...${RESET}"
		remote_docker_id="$(get_latest_id)"
		if [[ "$?" == 0 ]]; then
			remote_docker_id="${remote_docker_id:7:12}"
			if [[ "$remote_docker_id" != "$dkimg_id" ]]; then
				echo "    ${YELLOW}An update is available for your ${NETWORK_NAME} server docker image"
				echo "    Your image ID: $dkimg_id    Image ID on Docker Hub: ${remote_docker_id}"
				echo "    NOTE: If you have built manually with './run.sh build', your image will not match docker hub."
				echo "    To update, use ./run.sh install - a replay may or may not be required (ask in #witness on steem.chat)${RESET}"
			else
				echo "${GREEN}Your installed docker image ($dkimg_id) matches Docker Hub ($remote_docker_id)"
				echo "You're running the latest version of ${NETWORK_NAME} from @someguy123's builds${RESET}"
			fi
		else
			echo "    ${YELLOW}An error occurred while checking for updates${RESET}"
		fi

	fi

	echo $LINE

	msg green "Build information for currently installed ${NETWORK_NAME} image '${DOCKER_IMAGE}':"

	# docker run --rm -it "${DOCKER_IMAGE}" cat /steem_build.txt
	_docker_int_autorm cat /steem_build.txt
	echo "${BLUE}${NETWORK_NAME} version currently running:${RESET}"
	# Verify that the container exists, even if it's stopped
	if seed_exists; then
		_container_image_id=$(docker inspect "$DOCKER_NAME" -f '{{.Image}}')
		# Truncate the long SHA256 sum to the standard 12 character image ID
		container_image_id="${_container_image_id:7:12}"
		echo "    Container $DOCKER_NAME is running on docker image ID ${container_image_id}"
		# If the docker image check was successful earlier, then compare the image to the current container
		if [[ "$got_dkimg" == 1 ]]; then
			if [[ "$container_image_id" == "$dkimg_id" ]]; then
				echo "    ${GREEN}Container $DOCKER_NAME is running image $container_image_id, which matches ${DOCKER_IMAGE}:latest ($dkimg_id)"
				echo "    Your container will not change ${NETWORK_NAME} version on restart${RESET}"
			else
				echo "    ${YELLOW}Warning: Container $DOCKER_NAME is running image $container_image_id, which DOES NOT MATCH ${DOCKER_IMAGE}:latest ($dkimg_id)"
				echo "    Your container may change ${NETWORK_NAME} version on restart${RESET}"
			fi
		else
			echo "    ${YELLOW}Could not get installed image earlier. Skipping image/container comparison.${RESET}"
		fi
		echo "    ...scanning logs to discover blockchain version - this may take 30 seconds or more"
		l=$(docker logs "$DOCKER_NAME")
		if grep -q "blockchain version" <<<"$l"; then
			echo "  " $(grep "blockchain version" <<<"$l")
		else
			echo "    ${RED}Could not identify blockchain version. Not found in logs for '${DOCKER_NAME}'${RESET}"
		fi
	else
		echo "    ${RED}Unfortunately your ${NETWORK_NAME} container doesn't exist (start it with ./run.sh start or replay)..."
		echo "    We can't identify your blockchain version unless the container has been started at least once${RESET}"
	fi

}

# Usage: ./run.sh start
# Very simple status display, letting you know if the container exists, and if it's running.
status() {

	if seed_exists; then
		echo "Container exists?: "$GREEN"YES"$RESET
	else
		echo "Container exists?: "$RED"NO (!)"$RESET
		echo "Container doesn't exist, thus it is NOT running. Run '$0 install && $0 start'"$RESET
		return
	fi

	if seed_running; then
		echo "Container running?: "$GREEN"YES"$RESET
	else
		echo "Container running?: "$RED"NO (!)"$RESET
		echo "Container isn't running. Start it with '$0 start' or '$0 replay'"$RESET
		return
	fi
}

# Usage: ./run.sh clean [blocks|shm|all]
# Removes blockchain, p2p, and/or shared memory folder contents, with interactive prompts.
#
# To skip the "are you sure" prompt, specify either:
#     'blocks' (clear blockchain+p2p)
#     'shm' (SHM_DIR, usually /dev/shm)
#     'all' (clear both of the above)
#
# Example (delete blockchain+p2p folder contents without asking first):
#     ./run.sh clean blocks
#
sb_clean() {
	bc_dir="${DATADIR}/witness_node_data_dir/blockchain"
	p2p_dir="${DATADIR}/witness_node_data_dir/p2p"

	# To prevent the risk of glob problems due to non-existant folders,
	# we re-create them silently before we touch them.
	mkdir -p "$bc_dir" "$p2p_dir" "$SHM_DIR" &>/dev/null

	msg yellow " :: Blockchain:           $bc_dir"
	msg yellow " :: P2P files:            $p2p_dir"
	msg yellow " :: Shared Mem / Rocksdb: $SHM_DIR"
	msg

	if (($# == 1)); then
		case $1 in
		sh*)
			msg bold red " !!! Clearing all files in SHM_DIR ( $SHM_DIR )"
			rm -rfv "$SHM_DIR"/*
			mkdir -p "$SHM_DIR" &>/dev/null
			msg bold green " +++ Cleared shared files directory."
			;;
		bloc*)
			msg bold red " !!! Clearing all files in $bc_dir and $p2p_dir"
			rm -rfv "$bc_dir"/*
			rm -rfv "$p2p_dir"/*
			mkdir -p "$bc_dir" "$p2p_dir" &>/dev/null
			msg bold green " +++ Cleared blockchain files + p2p"
			;;
		all)
			msg bold red " !!! Clearing blockchain, p2p, and shared memory files..."
			rm -rfv "$SHM_DIR"/*
			rm -rfv "$bc_dir"/*
			rm -rfv "$p2p_dir"/*
			mkdir -p "$bc_dir" "$p2p_dir" "$SHM_DIR" &>/dev/null
			msg bold green " +++ Cleared blockchain + p2p + shared memory"
			;;
		*)
			msg bold red " !!! Invalid option. Either run './run.sh clean' for interactive mode, "
			msg bold red " !!!   or for automatic mode specify 'blocks' (blockchain + p2p), "
			msg bold red " !!!   'shm' (shared memory/rocksdb) or 'all' (both blocks and shm)"
			return 1
			;;
		esac
		return
	fi

	msg green " (+) To skip these prompts, you can run './run.sh clean' with 'blocks', 'shm', or 'all'"
	msg green " (?) 'blocks' = blockchain + p2p folder, 'shm' = shared memory folder, 'all' = blocks + shm"
	msg green " (?) Example: './run.sh clean blocks' will clear blockchain + p2p without any warnings."

	read -p "Do you want to remove the blockchain files? (y/n) > " cleanblocks
	if [[ "$cleanblocks" == "y" ]]; then
		msg bold red " !!! Clearing blockchain files..."
		rm -rvf "$bc_dir"/*
		mkdir -p "$bc_dir" &>/dev/null
		msg bold green " +++ Cleared blockchain files"
	else
		msg yellow " >> Not clearing blockchain folder."
	fi

	read -p "Do you want to remove the p2p files? (y/n) > " cleanp2p
	if [[ "$cleanp2p" == "y" ]]; then
		msg bold red " !!! Clearing p2p files..."
		rm -rvf "$p2p_dir"/*
		mkdir -p "$p2p_dir" &>/dev/null
		msg bold green " +++ Cleared p2p files"
	else
		msg yellow " >> Not clearing p2p folder."
	fi

	read -p "Do you want to remove the shared memory / rocksdb files? (y/n) > " cleanshm
	if [[ "$cleanshm" == "y" ]]; then
		msg bold red " !!! Clearing shared memory files..."
		rm -rvf "$SHM_DIR"/*
		mkdir -p "$SHM_DIR" &>/dev/null
		msg bold green " +++ Cleared shared memory files"
	else
		msg yellow " >> Not clearing shared memory folder."
	fi

	msg bold green " ++ Done."
}

# For use by @someguy123 for generating binary images
# ./run.sh publish [mira|nomira] [version] (extratag def: latest)
# e.g. ./run.sh publish mira v0.22.1
# e.g. ./run.sh publish nomira some-branch-fix v0.22.1-fixed
#
# disable extra tag:
# e.g. ./run.sh publish nomira some-branch-fix n/a
#
publish() {
	if (($# < 2)); then
		msg green "Usage: $0 publish [mira|nomira] [version] (extratag def: latest)"
		msg yellow "Environment vars:\n\tMAIN_TAG - Override the primary tag (default: someguy123/steem:\$V)\n"
		return 1
	fi
	MKMIRA="$1"
	BUILD_OPTS=()
	case "$MKMIRA" in
	mira)
		BUILD_OPTS+=("ENABLE_MIRA=ON")
		;;
	nomira)
		BUILD_OPTS+=("ENABLE_MIRA=OFF")
		;;
	*)
		msg red "Invalid 1st argument for publish"
		msg green "Usage: $0 publish [mira|nomira] [version] (extratag def: latest)"
		return 1
		;;
	esac

	V="$2"

	: "${MAIN_TAG="someguy123/steem:$V"}"
	[[ "$MKMIRA" == "mira" ]] && SECTAG="latest-mira" || SECTAG="latest"
	(($# > 2)) && SECTAG="$3"
	if [[ "$SECTAG" == "n/a" ]]; then
		msg bold yellow " >> Will build tag $V as tags $MAIN_TAG (no second tag)"
	else
		SECOND_TAG="someguy123/steem:$SECTAG"
		msg bold yellow " >> Will build tag $V as tags $MAIN_TAG and $SECOND_TAG"
	fi
	sleep 5
	./run.sh build "$V" tag "$MAIN_TAG" "${BUILD_OPTS[@]}"
	[[ "$SECTAG" != "n/a" ]] && docker tag "$MAIN_TAG" "$SECOND_TAG"
	docker push "$MAIN_TAG"
	[[ "$SECTAG" != "n/a" ]] && docker push "$SECOND_TAG"

	msg bold green " >> Finished"
}

#INTERNAL
set_variables() {
CHECK_MODE=$(grep MODE "$HOME"/.install_setting | awk -F= '{print $2}')
	if [[ "$CHECK_MODE" = "SERVICE" ]]; then
	   DIRECTORY=$(grep DIRECTORY "$HOME"/.install_setting | awk -F= '{print $2}')
	   BRANCH=$(grep BRANCH "$HOME"/.install_setting | awk -F= '{print $2}')
	   BOOST_ROOT=$(grep BOOST_ROOT "$HOME"/.install_setting | awk -F= '{print $2}')
	elif [[ "$CHECK_MODE" = "WITNESS_DOCKER" ]]; then
	   DIRECTORY=$(grep DIRECTORY "$HOME"/.install_setting | awk -F= '{print $2}')
	   BRANCH=$(grep BRANCH "$HOME"/.install_setting | awk -F= '{print $2}')
	elif [[ "$CHECK_MODE" = "SON_DOCKER" ]]; then
	   DIRECTORY=$(grep DIRECTORY "$HOME"/.install_setting | awk -F= '{print $2}')
	   BRANCH=$(grep BRANCH "$HOME"/.install_setting | awk -F= '{print $2}')
	   BITCOIN_WALLET=$(grep "BITCOIN_WALLET=" "$HOME"/.install_setting | awk -F= '{print $2}')
	   BITCOIN_WALLET_PASSWORD=$(grep BITCOIN_WALLET_PASSWORD "$HOME"/.install_setting | awk -F= '{print $2}')
	   SON_PUBLIC_KEY=$(grep SON_PUBLIC_KEY "$HOME"/.install_setting | awk -F= '{print $2}')
	   SON_PRIVATE_KEY=$(grep SON_PRIVATE_KEY "$HOME"/.install_setting | awk -F= '{print $2}')
	   BTC_PUBLIC_KEY=$(grep BTC_PUBLIC_KEY "$HOME"/.install_setting | awk -F= '{print $2}')
	   BTC_PRIVATE_KEY=$(grep BTC_PRIVATE_KEY "$HOME"/.install_setting | awk -F= '{print $2}')
	   BITCOIN_IP=$(grep BITCOIN_IP "$HOME"/.install_setting | awk -F= '{print $2}')
	   BITCOIN_ZMQ_PORT=$(grep BITCOIN_ZMQ_PORT "$HOME"/.install_setting | awk -F= '{print $2}')
	   BITCOIN_RPC_PORT=$(grep BITCOIN_RPC_PORT "$HOME"/.install_setting | awk -F= '{print $2}')
	   BITCOIN_RPC_USER=$(grep BITCOIN_RPC_USER "$HOME"/.install_setting | awk -F= '{print $2}')
	   BITCOIN_RPC_PASSWORD=$(grep BITCOIN_RPC_PASSWORD "$HOME"/.install_setting | awk -F= '{print $2}')
       PEERPLAYS_DOCKER_TAG=$(grep PEERPLAYS_DOCKER_TAG "$HOME"/.install_setting | awk -F= '{print $2}')	   
	   SEED_NODES=$(grep SEED_NODES "$HOME"/.install_setting | awk -F= '{print $2}')
	  
	elif [[ "$CHECK_MODE" = "SON_TEST_DOCKER" ]]; then
	   DIRECTORY=$(grep DIRECTORY "$HOME"/.install_setting | awk -F= '{print $2}')
	   BRANCH=$(grep BRANCH "$HOME"/.install_setting | awk -F= '{print $2}')
	   BITCOIN_WALLET=$(grep "BITCOIN_WALLET=" "$HOME"/.install_setting | awk -F= '{print $2}')
	   BITCOIN_WALLET_PASSWORD=$(grep BITCOIN_WALLET_PASSWORD "$HOME"/.install_setting | awk -F= '{print $2}')
	   SON_PUBLIC_KEY=$(grep SON_PUBLIC_KEY "$HOME"/.install_setting | awk -F= '{print $2}')
	   SON_PRIVATE_KEY=$(grep SON_PRIVATE_KEY "$HOME"/.install_setting | awk -F= '{print $2}')
	   SEED_NODES=$(grep SEED_NODES "$HOME"/.install_setting | awk -F= '{print $2}')
	   BTC_PUBLIC_KEY=$(grep BTC_PUBLIC_KEY "$HOME"/.install_setting | awk -F= '{print $2}')
	   BTC_PRIVATE_KEY=$(grep BTC_PRIVATE_KEY "$HOME"/.install_setting | awk -F= '{print $2}')
	   
	elif [[ "$CHECK_MODE" = "SEED_DOCKER" ]]; then
	   DIRECTORY=$(grep DIRECTORY "$HOME"/.install_setting | awk -F= '{print $2}')
	   BRANCH=$(grep BRANCH "$HOME"/.install_setting | awk -F= '{print $2}')
	   SEED_NODES=$(grep SEED_NODES "$HOME"/.install_setting | awk -F= '{print $2}')
	fi
}
# Internal Use Only
install_boost() {
	echo -e "\nInstalling peerplays blockchain with branch/tag $BRANCH in $DIRECTORY directory\n"
	msg bold blue "Starting Installation"
	msg bold blue "Installing pre-requisite libraries"
	sudo apt-get -y update
	sudo apt-get -y install autoconf bash build-essential ca-certificates cmake \
		dnsutils doxygen git graphviz libbz2-dev libcurl4-openssl-dev \
		libncurses-dev libreadline-dev libssl-dev libtool libzmq3-dev \
		locales ntp pkg-config wget autotools-dev libicu-dev python-dev

	msg bold blue "Setting up directories for boost library installation"
	mkdir -p "$DIRECTORY"/src
	cd "$DIRECTORY"/src || exit
	BOOST_ROOT=$DIRECTORY/src/boost_1_67_0
	echo -e "BOOST_ROOT=$BOOST_ROOT" >>"$HOME"/.install_setting
	msg bold blue "Downloading BOOST library"
	wget -c 'http://sourceforge.net/projects/boost/files/boost/1.67.0/boost_1_67_0.tar.bz2/download' \
		-O boost_1_67_0.tar.bz2
	tar xjf boost_1_67_0.tar.bz2
	cd boost_1_67_0/ || exit
	msg bold blue "Building and installing BOOST library"
	./bootstrap.sh "--prefix=$BOOST_ROOT"

	if ! ./b2 install; then
		msg bold red "BOOST library installation failed"
		exit
	else
		msg bold green "BOOST library installation successful"
	fi
}

#INTERNAL
install_peerplays() {
	set_variables
	msg bold blue "Setting up directories for Peerplays Blockchain Installation"
	cd "$DIRECTORY"/src || exit
	msg bold blue "Downloading Peerplays blockchain source code"
	git clone "${PEERPLAYS_SOURCE}"
	cd peerplays || exit
	git checkout "$BRANCH"
	git submodule update --init --recursive
	git submodule sync --recursive
	cmake -DBOOST_ROOT="$BOOST_ROOT" -DCMAKE_BUILD_TYPE=Release
	msg bold blue "Building Peerplays Blockchain code, it will take some time to complete!!!"
	make -j"$(nproc)"
	./programs/witness_node/witness_node --create-genesis-json ./programs/witness_node/genesis.json
	rm -rf ./programs/witness_node/genesis.json
	sed -i.tmp 's/\^#\ p2p-endpoint\ \=\ /p2p-endpoint\ \=\ 0.0.0.0:9777/' ./witness_node_data_dir/config.ini
	sed -i.tmp 's/\^#\ rpc-endpoint\ \=\ /rpc-endpoint\ \=\ 127.0.0.1:8090/' ./witness_node_data_dir/config.ini
	sed -i.tmp "s/^seed-nodes\ \=\ .*$/seed-nodes\ \=\ \[$SEED_NODES\]/" ./witness_node_data_dir/config.ini
	msg bold blue "Installation completed"
}
#INTERNAL
setup_peerplays_service() {
	set_variables
	msg bold blue "Creating Peerplays Blockchain Service"
	echo -e "[Unit]" >"$DIRECTORY"/peerplays.service
	{
		echo -e "Description=Peerplays Witness Node\n"
		echo -e "[Service]"
		echo -e "User=$(whoami)"
		echo -e "WorkingDirectory=$DIRECTORY"
		echo -e "ExecStart=$DIRECTORY/src/peerplays/programs/witness_node/witness_node"
		echo -e "Restart=always\n"
		echo -e "[Install]"
		echo -e "WantedBy=mult-user.target"
	} >>"$DIRECTORY"/peerplays.service

	msg bold blue "Starting Peerplays Blockchain Service"
	sudo cp "$DIRECTORY"/peerplays.service /etc/systemd/system && sudo systemctl start peerplays.service
	sleep 30
	if [ "$(systemctl is-active peerplays.service)" = "active" ]; then
		msg bold green "Peerplays witness node started successfully. You can monitor the logs using ./run.sh logs"
	else
		msg bold red "Peerplays witness node startup failed!!!!!"
		exit
	fi
}

#INTERNAL
pre_install() {
	clear
	#figlet -tc "Peerplays Blockchain"

	if [ "$(grep ^NAME /etc/os-release | awk -F\" '{print $2}')" = "Ubuntu" ] && [ "$(grep ^VERSION_ID /etc/os-release | awk -F\" '{print $2}')" = "18.04" ]; then
		msg bold green "Supported Platform"
	else
		msg bold red "This OS Platform is not supported!!!!!"
		msg nots bold red "\n$(hostnamectl)"
		exit
	fi

	read -r -p "Enter the directory where you want to install Peerplays blockchain [Press Enter for default: $PWD]: " DIRECTORY
	if [ -z "$DIRECTORY" ]; then
		DIRECTORY=$PWD
	else
		DIRECTORY=$(realpath "$DIRECTORY")
	fi

	#mkdir -p $DIRECTORY
	CHECK_MODE=$(grep MODE "$HOME"/.install_setting | awk -F= '{print $2}')
	
	if [[ "$CHECK_MODE" = "SERVICE" ]]; then
	    read -r -p "Enter the Peerplays blockchain repository branch/tag to be used for the installation [Press Enter for default: master]: " BRANCH
	    BRANCH=${BRANCH:-master}
		echo "Enter the seed nodes"
		REPEAT=true
		i=1
		SEED_NODES=
        while $REPEAT; do
		    read -r -p "    seed node $i----> eg. 10.10.10.10:1234 ]: " SEED_NODES[$i]
			if [ -z "${SEED_NODES}" ]; then
			   SEED_NODES="\"${SEED_NODES[$i]}\""
			else
			   SEED_NODES="${SEED_NODES},\"${SEED_NODES[$i]}\""
			fi
			
            read -r -p "Do you wish to add more nodes? (Y/N) ]: " REPEAT
        if [[  "$REPEAT" = "Y"  ]]; then
		   REPEAT=true
		   i=$((i+1))
		else
		   REPEAT=false
		fi
        done
		SEED_COUNT=$i
		{ echo -e "SEED_NODES=$SEED_NODES"; echo -e "SEED_COUNT=$SEED_COUNT"; } >>"$HOME"/.install_setting
		unset i SEED_COUNT REPEAT
		
	elif [[ "$CHECK_MODE" = "SEED_DOCKER" ]]; then
	    read -r -p "Enter the Peerplays blockchain repository branch/tag to be used for the installation [Press Enter for default: master]: " BRANCH
	    BRANCH=${BRANCH:-master}
	    msg bold blue "Downloading Peerplays blockchain source code"		
		git clone "${PEERPLAYS_DOCKER_SOURCE}" -b "${BRANCH}"
	    read -r -p "Enter the Peerplays blockchain Docker image tag to be used for the installation [Press Enter for default: latest]: " PEERPLAYS_IMAGE_TAG
	    PEERPLAYS_IMAGE_TAG=${PEERPLAYS_IMAGE_TAG:-"latest"}
	    PEERPLAYS_DOCKER_TAG="datasecuritynode/peerplays:${PEERPLAYS_IMAGE_TAG}"
		
		echo "Enter the seed nodes"
		REPEAT=true
		i=1
		SEED_NODES=
        while $REPEAT; do
		    read -r -p "    seed node $i----> eg. 10.10.10.10:1234 ]: " SEED_NODES[$i]
			if [ -z "${SEED_NODES}" ]; then
			   SEED_NODES="\"${SEED_NODES[$i]}\""
			else
			   SEED_NODES="${SEED_NODES},\"${SEED_NODES[$i]}\""
			fi
			
            read -r -p "Do you wish to add more nodes? (Y/N) ]: " REPEAT
        if [[  "$REPEAT" = "Y"  ]]; then
		   REPEAT=true
		   i=$((i+1))
		else
		   REPEAT=false
		fi
        done
		SEED_COUNT=$i
		{ echo -e "SEED_NODES=$SEED_NODES"; echo -e "SEED_COUNT=$SEED_COUNT"; echo -e "PEERPLAYS_DOCKER_TAG=$PEERPLAYS_DOCKER_TAG"; } >>"$HOME"/.install_setting
		unset i SEED_COUNT REPEAT
		
	elif [[ "$CHECK_MODE" = "SON_DOCKER" || "$CHECK_MODE" = "SON_TEST_DOCKER" ]]; then
	    read -r -p "Enter the Peerplays blockchain repository branch/tag to be used for the installation [Press Enter for default: master]: " BRANCH
	    BRANCH=${BRANCH:-master}
	    msg bold blue "Downloading Peerplays blockchain source code"		
		git clone "${PEERPLAYS_DOCKER_SOURCE}" -b "${BRANCH}"
	    read -r -p "Enter the Peerplays blockchain Docker image tag to be used for the installation [Press Enter for default: son-dev]: " PEERPLAYS_IMAGE_TAG
	    PEERPLAYS_IMAGE_TAG=${PEERPLAYS_IMAGE_TAG:-"son-dev"}
	    PEERPLAYS_DOCKER_TAG="datasecuritynode/peerplays:${PEERPLAYS_IMAGE_TAG}"
	    read -r -p "Enter the Bitcoin wallet name [Press Enter for default: son-wallet]: " BITCOIN_WALLET
	    BITCOIN_WALLET=${BITCOIN_WALLET:-"son-wallet"}
	    read -r -p "Enter the Bitcoin wallet password [Press Enter for default: peerplaysson]: " BITCOIN_WALLET_PASSWORD
	    BITCOIN_WALLET_PASSWORD=${BITCOIN_WALLET_PASSWORD:-peerplaysson}
	    read -r -p "Enter the SON public key: " SON_PUBLIC_KEY
	    read -r -p "Enter the SON private key: " SON_PRIVATE_KEY
		
		echo "Enter the SON seed nodes"
		REPEAT=true
		i=1
		SEED_NODES=
        while $REPEAT; do
		    read -r -p "    SON seed node $i----> eg. 10.10.10.10:1234 ]: " SEED_NODES[$i]
			if [ -z "${SEED_NODES}" ]; then
			   SEED_NODES="\"${SEED_NODES[$i]}\""
			else
			   SEED_NODES="${SEED_NODES},\"${SEED_NODES[$i]}\""
			fi
			
            read -r -p "Do you wish to add more nodes? (Y/N) ]: " REPEAT
        if [[  "$REPEAT" = "Y"  ]]; then
		   REPEAT=true
		   i=$((i+1))
		else
		   REPEAT=false
		fi
        done
		SEED_COUNT=$i
	    read -r -p "Enter the Bitcoin public key: " BTC_PUBLIC_KEY
	    read -r -p "Enter the Bitcoin private key: " BTC_PRIVATE_KEY
		{ echo -e "BITCOIN_WALLET=$BITCOIN_WALLET"; echo -e "BITCOIN_WALLET_PASSWORD=$BITCOIN_WALLET_PASSWORD"; echo -e "SON_PUBLIC_KEY=$SON_PUBLIC_KEY"; echo -e "SON_PRIVATE_KEY=$SON_PRIVATE_KEY"; echo -e "SEED_COUNT=$SEED_COUNT";  echo -e "SEED_NODES=$SEED_NODES"; echo -e "BTC_PUBLIC_KEY=$BTC_PUBLIC_KEY"; echo -e "BTC_PRIVATE_KEY=$BTC_PRIVATE_KEY"; echo -e "PEERPLAYS_DOCKER_TAG=$PEERPLAYS_DOCKER_TAG"; } >>"$HOME"/.install_setting
		unset i SEED_COUNT REPEAT
	fi
	
	if [[ "$CHECK_MODE" = "SON_DOCKER" ]]; then
	    read -r -p "Enter the IP address of the Bitcoin node: " BITCOIN_IP	
	    read -r -p "Enter the Bitcoin node ZMQ Port[Press Enter for default: 11111]: " BITCOIN_ZMQ_PORT
	    BITCOIN_ZMQ_PORT=${BITCOIN_ZMQ_PORT:-"11111"}	
		read -r -p "Enter the Bitcoin node RPC Port[Press Enter for default: 8332]: " BITCOIN_RPC_PORT
	    BITCOIN_RPC_PORT=${BITCOIN_RPC_PORT:-"8332"}	
		read -r -p "Enter the Bitcoin node RPC username: " BITCOIN_RPC_USER
		read -r -p "Enter the Bitcoin node RPC password: " BITCOIN_RPC_PASSWORD
		{ echo -e "BITCOIN_IP=$BITCOIN_IP"; echo -e "BITCOIN_ZMQ_PORT=$BITCOIN_ZMQ_PORT"; echo -e "BITCOIN_RPC_PORT=$BITCOIN_RPC_PORT"; echo -e "BITCOIN_RPC_USER=$BITCOIN_RPC_USER"; echo -e "BITCOIN_RPC_PASSWORD=$BITCOIN_RPC_PASSWORD";} >> "$HOME"/.install_setting
	fi

	echo -e "DIRECTORY=$DIRECTORY" >>"$HOME"/.install_setting
	echo -e "BRANCH=$BRANCH" >>"$HOME"/.install_setting
}
# Usage: ./run.sh clean witness_install
witness_install() {
	pre_install
	install_boost
	install_peerplays
	setup_peerplays_service
}
# Usage: ./run.sh witness_install_only
witness_install_only() {
	pre_install
	install_boost
	install_peerplays
}

# Usage: ./run.sh son_docker_install
son_docker_install() {
	pre_install
	start_son
}

# Usage: ./run.sh seed_docker_install
seed_docker_install() {
	pre_install
	start_seed
}

# Usage: ./run.sh son_docker_regtest_install
son_docker_regtest_install() {
	pre_install
	start_son_regtest
}

#INTERNAL
uninstall_peerplays() {
	set_variables
	if sudo systemctl list-unit-files --type service | grep peerplays.service; then
		#Cleaning up the peerplays service
		msg bold blue "Uninstalling Peerplays blockchain service"
		sudo systemctl stop peerplays
		sudo systemctl disable peerplays
		sudo rm /etc/systemd/system/peerplays.service
		sudo systemctl daemon-reload
		sudo systemctl reset-failed
		if ! sudo systemctl list-unit-files --type service | grep peerplays.service; then
			msg bold green "Uninstalled Peerplays blockchain service"
		else
			msg bold red "Peerplays blockchain service uninstallation failed!!!"
			exit
		fi
		INSTALL_ROOT_DIR="$(grep DIRECTORY "$HOME"/.install_setting | awk -F= '{print $2}' | xargs dirname)"
		INSTALL_DIR="$(grep DIRECTORY "$HOME"/.install_setting | awk -F= '{print $2}' | xargs basename)"
		cd "$INSTALL_ROOT_DIR" || exit
		#Cleaning up the install directory
		if sudo rm -rf "$INSTALL_DIR" && sudo rm -rf "$HOME"/.install_setting; then
			msg bold green "Peerplays blockchain uninstalled successfully"
			exit
		else
			msg bold red "Peerplays blockchain uninstallation failed!!!"
			exit
		fi
	elif sudo systemctl list-unit-files --type service | grep peerplays-replay.service; then
		#Cleaning up the peerplays replay service
		msg bold green "Uninstalling Peerplays blockchain replay service"
		sudo systemctl stop peerplays-replay
		sudo systemctl disable peerplays-replay
		sudo rm /etc/systemd/system/peerplays-replay.service
		sudo systemctl daemon-reload
		sudo systemctl reset-failed
		if ! sudo systemctl list-unit-files --type service | grep peerplays-replay.service; then
			msg bold green "Uninstalled Peerplays blockchain replay service"
		else
			msg bold red "Peerplays blockchain service uninstallation failed!!!"
			exit
		fi
		INSTALL_ROOT_DIR="$(grep DIRECTORY "$HOME"/.install_setting | awk -F= '{print $2}' | xargs dirname)"
		INSTALL_DIR="$(grep DIRECTORY "$HOME"/.install_setting | awk -F= '{print $2}' | xargs basename)"
		cd "$INSTALL_ROOT_DIR" || exit
		#Cleaning up the install directory
		if sudo rm -rf "$INSTALL_DIR" && sudo rm -rf "$HOME"/.install_setting; then
			msg bold green "Peerplays blockchain uninstalled successfully"
			exit
		else
			msg bold red "Peerplays blockchain uninstallation failed!!!"
			exit
		fi

	fi
}

#INTERNAL
uninstall_peerplays_docker() {
	set_variables
	if seed_exists; then
		PEERPLAYS_DOCKER_TAG="$(grep PEERPLAYS_DOCKER_TAG "$HOME"/.install_setting | awk -F= '{print $2}')"
		msg red "Stopping container '${DOCKER_NAME}' (allowing up to ${STOP_TIME} seconds before killing)..."
		sudo docker stop -t "${STOP_TIME}" "$DOCKER_NAME"
		msg red "Removing the container '${DOCKER_NAME}'..."
		sudo docker rm "$DOCKER_NAME"
		msg red "Removing the '${DOCKER_NAME}' container image ..."
		sudo docker rmi "$DOCKER_NAME"
		sudo docker rmi "$PEERPLAYS_DOCKER_TAG"
		msg green "Peerplays Blockchain successfully uninstalled ..."
	else
		msg bold red "Peerplays Docker container not found in the system"
	fi
}

#INTERNAL
uninstall_bitcoin_docker() {
	set_variables
	if bitcoin_exists; then
		msg red "Stopping container '${DOCKER_BITCOIN_NAME}' (allowing up to ${STOP_TIME} seconds before killing)..."
		sudo docker stop -t "${STOP_TIME}" "$DOCKER_BITCOIN_NAME"
		msg red "Removing the container '${DOCKER_BITCOIN_NAME}'..."
		sudo docker rm "$DOCKER_BITCOIN_NAME"
		msg red "Removing the '${DOCKER_BITCOIN_NAME}' container image ..."
		sudo docker rmi "$DOCKER_BITCOIN_NAME"
		sudo docker rmi "$BITCOIN_DOCKER_TAG"
        sudo docker volume rm "${DOCKER_BITCOIN_VOLUME}"
		sudo docker network rm "${DOCKER_NETWORK}"
		msg green "Peerplays Blockchain successfully uninstalled ..."
	else
		msg bold red "Bitcoin Docker container not found in the system"
	fi
}

#INTERNAL
cleanup_dir() {
	msg blue "Cleaning up the directory"
	if sudo rm -rf peerplays-docker && rm -rf "$HOME"/.install_setting; then
		msg green "Cleaned up peerplays-docker directory and installation files"
		exit
	else
		msg red "Failed to remove the peerplays-docker directory.."
		exit
	fi
}

# Usage: ./run.sh uninstall
uninstall() {
	clear
	#figlet -tc "Peerplays Blockchain"

	if [ -f "$HOME"/.install_setting ]; then
		read -r -p "Do you want to uninstall peerplays blockchain: Y/N]: " UNINSTALL_RESPONSE
		UNINSTALL_RESPONSE=${UNINSTALL_RESPONSE:-N}
		UNINSTALL_RESPONSE_IC="$(echo "$UNINSTALL_RESPONSE" | tr '[:lower:]' '[:upper:]')"

		if [ "$UNINSTALL_RESPONSE_IC" = "Y" ]; then
			CHECK_MODE=$(grep MODE "$HOME"/.install_setting | awk -F= '{print $2}')
			if [[  "$CHECK_MODE" = "SON_TEST_DOCKER" ]]; then
				uninstall_peerplays_docker
				uninstall_bitcoin_docker
				cleanup_dir
			elif [[ "$CHECK_MODE" = "WITNESS_DOCKER" || "$CHECK_MODE" = "SON_DOCKER" || "$CHECK_MODE" = "SEED_DOCKER" ]]; then
				uninstall_peerplays_docker
				cleanup_dir
			elif [[ "$CHECK_MODE" = "SERVICE" ]]; then
				uninstall_peerplays
			fi
		else
			msg bold blue "Exiting uninstallation"
			exit
		fi
	else
		msg bold red "Peerplays Blockchain not present on this server/not installed using run.sh"
	fi
}

# Usage: ./run.sh witness_docker_install
witness_docker_install() {
	if ! sudo docker ps -a; then
		install_docker
		install
		start
	else
		install
		start
	fi
}

if [ "$#" -lt 1 ]; then
	help
fi

if [[ "$1" = "witness_install" || "$1" = "witness_install_only" || "$1" = "witness_docker_install" || "$1" = "son_docker_install"  || "$1" = "son_docker_regtest_install" || "$1" = "seed_docker_install" || "$1" = "install" || "$1" = "build" ]]; then
	if [ -f "$HOME"/.install_setting ]; then
		CHECK_MODE=$(grep MODE "$HOME"/.install_setting | awk -F= '{print $2}')
		msg bold red "Already Peerplays Blockchain is installed in $CHECK_MODE mode. Exiting !!!"
		exit
	else
		if [ "$1" = "witness_install" ]; then
			echo -e "MODE=SERVICE" >"$HOME"/.install_setting
		elif [[ "$1" = "witness_docker_install" || "$1" = "witness_install_only" || "$1" = "build" || ("$1" = "install" && "$2" = "son-dev") ]]; then
			echo -e "MODE=WITNESS_DOCKER" >"$HOME"/.install_setting
		elif [[ "$1" = "son_docker_install" ]]; then
			echo -e "MODE=SON_DOCKER" >"$HOME"/.install_setting
		elif [[ "$1" = "son_docker_regtest_install" ]]; then
			echo -e "MODE=SON_TEST_DOCKER" >"$HOME"/.install_setting
		elif [[ "$1" = "seed_docker_install" ]]; then
			echo -e "MODE=SEED_DOCKER" >"$HOME"/.install_setting

		fi

	fi
fi

case $1 in
build)
	msg bold magenta "This will build a Peerplays Blockchain docker image from source code."
	build "${@:2}"
	;;
witness_install)
	msg bold magenta "This will build, install and start the Peerplays witness as a service."
	witness_install "${@:2}"
	;;
witness_install_only)
	msg bold magenta "This will build and install Peerplays witness  as a service"
	witness_install_only "${@:2}"
	;;
uninstall)
	msg bold magenta "This will uninstall Peerplays Blockchain installation."
	uninstall "${@:2}"
	;;
witness_docker_install)
	msg bold magenta "This will install and start Peerplays witness docker container"
	witness_docker_install "${@:2}"
	;;
son_docker_install)
	msg bold magenta "This will install and start Peerplays SON docker container"
	son_docker_install "${@:2}"
	;;
son_docker_regtest_install)
	msg bold magenta "This will install and start Peerplays SON docker container in test mode"
	son_docker_regtest_install "${@:2}"
	;;
seed_docker_install)
	msg bold magenta "This will install and start Peerplays seed docker container"
	seed_docker_install "${@:2}"
	;;
build_full)
	msg bold magenta "You may want to use '$0 install_full' for a binary image instead, it's faster."
	build_full "${@:2}"
	;;
build_local)
	build_local "${@:2}"
	;;
install_docker)
	install_docker
	;;
install)
	install "${@:2}"
	;;
install_full)
	install_full
	;;
publish)
	publish "${@:2}"
	;;
start)
	start "${@:2}"
	;;
start_son)
	start_son
	;;
start_son_regtest)
	start_son_regtest
	;;
replay)
	msg bold magenta "This will start replay of the installed Peerplays Blockchain"
	replay "${@:2}"
	;;
memory_replay)
	memory_replay "${@:2}"
	;;
shm_size)
	shm_size "$2"
	;;
stop)
	stop
	;;
kill)
	kill
	;;
restart)
	stop
	sleep 5
	start
	;;
rebuild)
	stop
	sleep 5
	build
	start
	;;
clean)
	sb_clean "${@:2}"
	;;
optimize)
	msg "Applying recommended dirty write settings..."
	optimize
	;;
status)
	status
	;;
wallet)
	wallet
	;;
remote_wallet)
	remote_wallet "${@:2}"
	;;
monitor)
	siab-monitor "${@:2}"
	;;
stateshot)
	install-stateshot "${@:2}"
	;;
enter)
	enter
	;;
shell)
	shell
	;;
logs)
	logs
	;;
pclogs)
	pclogs
	;;
tslogs)
	tslogs
	;;
clean_logs | cleanlogs | clean-logs)
	clean-logs
	;;
ver | version)
	ver
	;;
*)
	msg bold red "Invalid cmd"
	help
	;;
esac

exit 0
