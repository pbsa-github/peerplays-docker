#!/usr/bin/env bash
#
# Steem node manager
# Released under GNU AGPL by Someguy123
#



DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
: ${DOCKER_DIR="$DIR/dkr"}
: ${FULL_DOCKER_DIR="$DIR/dkr_fullnode"}
: ${DATADIR="$DIR/data"}
: ${DOCKER_NAME="seed"}

# the tag to use when running/replaying steemd
: ${DOCKER_IMAGE="peerplays"}


BOLD="$(tput bold)"
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
BLUE="$(tput setaf 4)"
MAGENTA="$(tput setaf 5)"
CYAN="$(tput setaf 6)"
WHITE="$(tput setaf 7)"
RESET="$(tput sgr0)"
: ${DK_TAG="datasecuritynode/peerplays:latest"}
: ${DK_TAG_FULL="datasecuritynode/peerplays:full"}
: ${SHM_DIR="/dev/shm"}
# Amount of time in seconds to allow the docker container to stop before killing it.
# Default: 600 seconds (10 minutes)
: ${STOP_TIME=600}

# Git repository to use when building Steem - containing steemd code
: ${PEERPLAYS_SOURCE="https://github.com/peerplays-network/peerplays.git"}

# Comma separated list of ports to expose to the internet.
# By default, only port 2001 will be exposed (the P2P seed port)
: ${PORTS="2001"}

# Internal variable. Set to 1 by build_full to inform child functions
BUILD_FULL=0
# Placeholder for custom tag var CUST_TAG (shared between functions)
CUST_TAG="peerplays"
# Placeholder for BUILD_VER shared between functions
BUILD_VER=""


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
function msg () {
    # usage: msg [color] message
    if [[ "$#" -eq 0 ]]; then echo ""; return; fi;
    if [[ "$#" -eq 1 ]]; then
        echo -e "$1"
        return
    fi
    if [[ "$#" -gt 2 ]] && [[ "$1" == "bold" ]]; then
        echo -n "${BOLD}"
        shift
    fi
    _msg="[$(date +'%Y-%m-%d %H:%M:%S %Z')] ${@:2}"
    case "$1" in
        bold) echo -e "${BOLD}${_msg}${RESET}";;
        [Bb]*) echo -e "${BLUE}${_msg}${RESET}";;
        [Yy]*) echo -e "${YELLOW}${_msg}${RESET}";;
        [Rr]*) echo -e "${RED}${_msg}${RESET}";;
        [Gg]*) echo -e "${GREEN}${_msg}${RESET}";;
        * ) echo -e "${_msg}";;
    esac
}

export -f msg
export RED GREEN YELLOW BLUE BOLD NORMAL RESET

if [[ -f .env ]]; then
    source .env
fi

# blockchain folder, used by dlblocks
: ${BC_FOLDER="$DATADIR/witness_node_data_dir/blockchain"}

: ${EXAMPLE_MIRA="$DATADIR/witness_node_data_dir/database.cfg.example"}
: ${MIRA_FILE="$DATADIR/witness_node_data_dir/database.cfg"}

: ${EXAMPLE_CONF="$DATADIR/witness_node_data_dir/config.ini.example"}
: ${CONF_FILE="$DATADIR/witness_node_data_dir/seed_config.ini"}

# if the config file doesn't exist, try copying the example config
if [[ ! -f "$CONF_FILE" ]]; then
    if [[ -f "$EXAMPLE_CONF" ]]; then
        echo "${YELLOW}File config.ini not found. copying example (seed)${RESET}"
        cp -vi "$EXAMPLE_CONF" "$CONF_FILE" 
        echo "${GREEN} > Successfully installed example config for seed node.${RESET}"
        echo " > You may want to adjust this if you're running a witness, e.g. disable p2p-endpoint"
    else
        echo "${YELLOW}WARNING: You don't seem to have a config file and the example config couldn't be found...${RESET}"
        echo "${YELLOW}${BOLD}You may want to check these files exist, or you won't be able to launch Steem${RESET}"
        echo "Example Config: $EXAMPLE_CONF"
        echo "Main Config: $CONF_FILE"
    fi
fi

if [[ ! -f "$MIRA_FILE" ]]; then
    if [[ -f "$EXAMPLE_MIRA" ]]; then
        echo "${YELLOW}File database.cfg not found. copying example ${RESET}"
        cp -vi "$EXAMPLE_MIRA" "$MIRA_FILE" 
        echo "${GREEN} > Successfully installed example MIRA config.${RESET}"
        echo " > You may want to adjust this depending on your resources and type of node:"
        echo " - - > https://github.com/steemit/steem/blob/master/doc/mira.md"

    else
        echo "${YELLOW}WARNING: You don't seem to have a MIRA config file (data/database.cfg) and the example config couldn't be found...${RESET}"
        echo "${YELLOW}${BOLD}You may want to check these files exist, or you won't be able to use Steem with MIRA${RESET}"
        echo "Example Config: $EXAMPLE_MIRA"
        echo "Main Config: $MIRA_FILE"
    fi
fi

IFS=","
DPORTS=()
for i in $PORTS; do
    if [[ $i != "" ]]; then
        if grep -q ":" <<< "$i"; then
            DPORTS+=("-p$i")
        else
            DPORTS+=("-p0.0.0.0:$i:$i")
        fi
    fi
done

# load docker hub API
source scripts/000_docker.sh

help() {
    echo "Usage: $0 COMMAND [DATA]"
    echo
    echo "Commands: 
    start - starts seed container
    clean - Remove blockchain, p2p, and/or shared mem folder contents (warns beforehand)
    dlblocks - download and decompress the blockchain to speed up your first start
    replay - starts seed container (in replay mode)
    memory_replay - starts seed container (in replay mode, with --memory-replay)
    shm_size - resizes /dev/shm to size given, e.g. ./run.sh shm_size 10G 
    stop - stops seed container
    status - show status of seed container
    restart - restarts seed container
    install_docker - install docker
    install - pulls latest docker image from server (no compiling)
    install_full - pulls latest (FULL NODE FOR RPC) docker image from server (no compiling)
    rebuild - builds seed container (from docker file), and then restarts it
    build - only builds seed container (from docker file)
    logs - show all logs inc. docker logs, and seed logs
    wallet - open cli_wallet in the container
    remote_wallet - open cli_wallet in the container connecting to a remote seed
    enter - enter a bash session in the currently running container
    shell - launch the seed container with appropriate mounts, then open bash for inspection
    "
    echo
    exit
}

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
    echo    75 | sudo tee /proc/sys/vm/dirty_background_ratio
    echo  1000 | sudo tee /proc/sys/vm/dirty_expire_centisecs
    echo    80 | sudo tee /proc/sys/vm/dirty_ratio
    echo 30000 | sudo tee /proc/sys/vm/dirty_writeback_centisecs
}

parse_build_args() {
    BUILD_VER=$1
    CUST_TAG="peerplays:$BUILD_VER"
    if (( $BUILD_FULL == 1 )); then
        CUST_TAG+="-full"
    fi
    BUILD_ARGS+=('--build-arg' "peerplaysd=${BUILD_VER}")
    shift
    if (( $# >= 2 )); then
        if [[ "$1" == "tag" ]]; then
            CUST_TAG="$2"
            msg yellow " >> Custom re-tag specified. Will tag new image with '${CUST_TAG}'"
            shift; shift;    # Get rid of the two tag arguments. Everything after is now build args
        fi
    fi
    local has_steem_src='n'
    if (( $# >= 1 )); then
        msg yellow " >> Additional build arguments specified."
        for a in "$@"; do
            msg yellow " ++ Build argument: ${BOLD}${a}"
            BUILD_ARGS+=('--build-arg' "$a")
            if grep -q 'PEERPLAYS_SOURCE' <<< "$a"; then
                has_steem_src='y'
            fi
        done
    fi

    if [[ "$has_steem_src" == "y" ]]; then
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
    msg green " >>> Will build Steem using code stored in '${DOCKER_DIR}/src' instead of remote git repo"
    build "$@"
}

# Build standard low memory node as a docker image
# Usage: ./run.sh build [version] [tag tag_name] [build_args]
# Version is prefixed with v, matching steem releases
# e.g. build v0.20.6
#
# Override destination tag:
#   ./run.sh build v0.21.0 tag 'steem:latest'
#
# Additional build args:
#   ./run.sh build v0.21.0 ENABLE_MIRA=OFF
#
# Or combine both:
#   ./run.sh build v0.21.0 tag 'steem:mira' ENABLE_MIRA=ON
#
build() {
    fmm="Low Memory Mode (For Seed / Witness nodes)"
    (( $BUILD_FULL == 1 )) && fmm="Full Memory Mode (For RPC nodes)" && DOCKER_DIR="$FULL_DOCKER_DIR"
    BUILD_MSG=" >> Building docker container [[ ${fmm} ]]"
    if (( $# >= 1 )); then
        parse_build_args "$@"
        sleep 2
        cd "$DOCKER_DIR"
        msg bold green "$BUILD_MSG"
        docker build "${BUILD_ARGS[@]}" -t "$CUST_TAG" .
        ret=$?
        if (( $ret == 0 )); then
            echo "${RED}
    !!! !!! !!! !!! !!! !!! READ THIS !!! !!! !!! !!! !!! !!!
    !!! !!! !!! !!! !!! !!! READ THIS !!! !!! !!! !!! !!! !!!
        For your safety, we've tagged this image as $CUST_TAG
        To use it in this steem-docker, run: 
        ${GREEN}${BOLD}
        docker tag $CUST_TAG steem:latest
        ${RESET}${RED}
    !!! !!! !!! !!! !!! !!! READ THIS !!! !!! !!! !!! !!! !!!
    !!! !!! !!! !!! !!! !!! READ THIS !!! !!! !!! !!! !!! !!!
        ${RESET}
            "
            msg bold green " +++ Successfully built steemd"
            msg green " +++ Steem node type: ${BOLD}${fmm}"
            msg green " +++ Version/Branch: ${BOLD}${BUILD_VER}"
            msg green " +++ Build args: ${BOLD}${BUILD_ARGS[@]}"
            msg green " +++ Docker tag: ${CUST_TAG}"
        else
            msg bold red " !!! ERROR: Something went wrong during the build process."
            msg red " !!! Please scroll up and check for any error output during the build."
        fi
        return
    fi
    msg bold green "$BUILD_MSG"
    cd "$DOCKER_DIR"
    docker build -t "$DOCKER_IMAGE" .
    ret=$?
    if (( $ret == 0 )); then
        msg bold green " +++ Successfully built current stable peerplaysd"
        msg green " +++ Peerplays node type: ${BOLD}${fmm}"
        msg green " +++ Docker tag: ${DOCKER_IMAGE}"
    else
        msg bold red " !!! ERROR: Something went wrong during the build process."
        msg red " !!! Please scroll up and check for any error output during the build."
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

# Usage: ./run.sh dlblocks [override_dlmethod] [url] [compress]
# Download the block_log from a remote server and de-compress it on-the-fly to save space, 
# then places it correctly into $BC_FOLDER
# Automatically attempts to resume partially downloaded block_log's using rsync, or http if
# rsync is disabled in .env
# 
#   override_dlmethod - use this to force downloading a certain way (OPTIONAL)
#                     choices:
#                       - rsync - download via rsync, resume if exists, using append-verify and ignore times
#                       - rsync-replace - download whole file via rsync, delete block_log before download
#                       - http - download via http. if uncompressed, try to resume when possible
#                       - http-replace - do not attempt to resume. delete block_log before download
#
#   url - Download/install block log using the supplied dlmethod from this url. (OPTIONAL)
#
#   compress -  Only valid for http/http-replace. Decompress the file on the fly. (OPTIONAL)
#               options: xz, lz4, no (no compression) 
#               if a custom url is supplied, but no compression method, it is assumed it is raw and not compressed.
#
# Example: The default compressed lz4 download failed, but left it's block_log in place. 
# You don't want to use rsync to resume, because your network is very fast
# Instead, you can continue your download using the uncompressed version over HTTP:
#
#   ./run.sh dlblocks http "http://files.privex.io/steem/block_log"
#
# Or just re-download the whole uncompressed file instead of resuming:
#
#   ./run.sh dlblocks http-replace "http://files.privex.io/steem/block_log"
#
dlblocks() {
    pkg_not_found rsync rsync
    pkg_not_found lz4 liblz4-tool
    pkg_not_found xz xz-utils
    
    [[ ! -d "$BC_FOLDER" ]] && mkdir -p "$BC_FOLDER"
    [[ -f "$BC_FOLDER/block_log.index" ]] && msg "Removing old block index" && sudo rm -vf "$BC_FOLDER/block_log.index" 2> /dev/null

    if (( $# > 0 )); then
        custom-dlblocks "$@"
        return $?
    fi
    if [[ -f "$BC_FOLDER/block_log" ]]; then
            msg yellow "It looks like block_log already exists"
            cd $BC_FOLDER && rm -rf .git*
            . /etc/os-release && OS=$NAME VER=$VERSION_ID
            echo Operating System: $OS $VER
            if   [[ "$OS" == "Ubuntu" ]] && [[ "$VER" == "20.04" ]]; then
            echo "Newer System, already validated. Proceed"
            sudo apt-get -y install git git-lfs
            elif [[ "$OS" == "Ubuntu" ]] && [[ "$VER" == "18.04" ]]; then
            echo "System already validated. Proceed"
            sudo apt-get -y install git git-lfs
            elif [[ "$OS" == "Ubuntu" ]] && [[ "$VER" == "16.04" ]]; then
            echo "Older system, needs additional steps. Proceed"
            curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash && sudo apt-get -y install git git-lfs
            else echo "System not supported"; fi
            git clone https://gitlab.com/robert.hedler/dlblock.git .; rm -rf .git
            return
        else
            cd $BC_FOLDER && rm -rf .git*
            . /etc/os-release && OS=$NAME VER=$VERSION_ID
            echo Operating System: $OS $VER
            if   [[ "$OS" == "Ubuntu" ]] && [[ "$VER" == "20.04" ]]; then
            echo "Newer System, already validated. Proceed"
            sudo apt-get -y install git git-lfs
            elif [[ "$OS" == "Ubuntu" ]] && [[ "$VER" == "18.04" ]]; then
            echo "System already validated. Proceed"
            sudo apt-get -y install git git-lfs
            elif [[ "$OS" == "Ubuntu" ]] && [[ "$VER" == "16.04" ]]; then
            echo "Older system, needs additional steps. Proceed"
            curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash && sudo apt-get -y install git git-lfs
            else echo "System not supported"; fi
            git clone https://gitlab.com/robert.hedler/dlblock.git .; rm -rf .git
            return
        fi
    cd $BC_FOLDER && rm -rf .git*
    . /etc/os-release && OS=$NAME VER=$VERSION_ID
    echo Operating System: $OS $VER
    if   [[ "$OS" == "Ubuntu" ]] && [[ "$VER" == "20.04" ]]; then
    echo "Newer System, already validated. Proceed"
    sudo apt-get -y install git git-lfs
    elif [[ "$OS" == "Ubuntu" ]] && [[ "$VER" == "18.04" ]]; then
    echo "System already validated. Proceed"
    sudo apt-get -y install git git-lfs
    elif [[ "$OS" == "Ubuntu" ]] && [[ "$VER" == "16.04" ]]; then
    echo "Older system, needs additional steps. Proceed"
    curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash && sudo apt-get -y install git git-lfs
    else echo "System not supported"; fi
    git clone https://gitlab.com/robert.hedler/dlblock.git .; rm -rf .git
if [ $? == 0 ] ; then
    msg "FINISHED. Blockchain installed to ${BC_FOLDER}/database/block_num_to_block/blocks"
    echo "Remember to resize your /dev/shm, and run with replay!"
    echo "$ ./run.sh shm_size SIZE (e.g. 8G)"
    echo "$ ./run.sh replay"else 
    msg "Download error, please run dlblocks again."
fi

}

# Usage: ./run.sh install_docker
# Downloads and installs the latest version of Docker using the Get Docker site
# If Docker is already installed, it should update it.
install_docker() {
    sudo apt update
    # curl/git used by docker, xz/lz4 used by dlblocks, jq used by tslogs/pclogs
    sudo apt install curl git xz-utils liblz4-tool jq
    curl https://get.docker.com | sh
    if [ "$EUID" -ne 0 ]; then 
        echo "Adding user $(whoami) to docker group"
        sudo usermod -aG docker $(whoami)
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
    if (( $# == 1 )); then
        DK_TAG=$1
        # If neither '/' nor ':' are present in the tag, then for convenience, assume that the user wants
        # datasecuritynode/peerplays with this specific tag.
        if grep -qv ':' <<< "$1"; then
            if grep -qv '/' <<< "$1"; then
                msg bold red "WARNING: Neither / nor : were present in your tag '$1'"
                DK_TAG="datasecuritynode/peerplays:$1"
                msg red "We're assuming you've entered a version, and will try to install @datasecuritynode's image: '${DK_TAG}'"
                msg yellow "If you *really* specifically want '$1' from Docker hub, set DK_TAG='$1' inside of .env and run './run.sh install'"
            fi
        fi
    fi
    msg bold red "NOTE: You are installing image $DK_TAG. Please make sure this is correct."
    sleep 2
    msg yellow " -> Loading image from ${DK_TAG}"
    docker pull "$DK_TAG"
    msg green " -> Tagging as peerplays"
    docker tag "$DK_TAG" peerplays
    msg bold green " -> Installation completed. You may now configure or run the server"
}

# Usage: ./run.sh install_full
# Downloads the Steem full node image from the pre-set $DK_TAG_FULL in run.sh or .env
# Default tag is normally someguy123/steem:latest-full (official builds by the creator of steem-docker).
#
install_full() {
    msg yellow " -> Loading image from ${DK_TAG_FULL}"
    docker pull "$DK_TAG_FULL" 
    msg green " -> Tagging as peerplays"
    docker tag "$DK_TAG_FULL" peerplays
    msg bold green " -> Installation completed. You may now configure or run the server"
}

# Internal Use Only
# Checks if the container $DOCKER_NAME exists. Returns 0 if it does, -1 if not.
# Usage:
# if seed_exists; then echo "true"; else "false"; fi
#
seed_exists() {
    seedcount=$(docker ps -a -f name="^/"$DOCKER_NAME"$" | wc -l)
    if [[ $seedcount -eq 2 ]]; then
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
    seedcount=$(docker ps -f 'status=running' -f name=$DOCKER_NAME | wc -l)
    if [[ $seedcount -eq 2 ]]; then
        return 0
    else
        return -1
    fi
}

# Usage: ./run.sh start
# Creates and/or starts the Steem docker container
start() {
    msg bold green " -> Starting container '${DOCKER_NAME}'..."
    seed_exists
    if [[ $? == 0 ]]; then
        docker start $DOCKER_NAME
    else
        docker run ${DPORTS[@]} -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name $DOCKER_NAME -t "$DOCKER_IMAGE" witness_node --data-dir=/peerplays/witness_node_data_dir
    fi
}

# Usage: ./run.sh replay
# Replays the blockchain for the Steem docker container
# If steem is already running, it will ask you if you still want to replay
# so that it can stop and remove the old container
#
replay() {
    seed_running
    if [[ $? == 0 ]]; then
        echo $RED"WARNING: Your Steem server ($DOCKER_NAME) is currently running"$RESET
        echo
        docker ps
        echo
        read -p "Do you want to stop the container and replay? (y/n) > " shouldstop
        if [[ "$shouldstop" == "y" ]]; then
            stop
        else
            echo $GREEN"Did not say 'y'. Quitting."$RESET
            return
        fi
    fi 
    msg yellow " -> Removing old container '${DOCKER_NAME}'"
    docker rm $DOCKER_NAME 2> /dev/null
    msg green " -> Running peerplays (image: ${DOCKER_IMAGE}) with replay in container '${DOCKER_NAME}'..."
    docker run ${DPORTS[@]} -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name $DOCKER_NAME -t "$DOCKER_IMAGE" witness_node --data-dir=/peerplays/witness_node_data_dir --replay
    msg bold green " -> Started."
}

# For MIRA, replay with --memory-replay
memory_replay() {
    seed_running
    if [[ $? == 0 ]]; then
        echo $RED"WARNING: Your Peerplay server ($DOCKER_NAME) is currently running"$RESET
	echo
        docker ps
	echo
	read -p "Do you want to stop the container and replay? (y/n) > " shouldstop
        if [[ "$shouldstop" == "y" ]]; then
		stop
	else
		echo $GREEN"Did not say 'y'. Quitting."$RESET
		return
	fi
    fi 
    echo "Removing old container"
    docker rm $DOCKER_NAME
    echo "Running peerplay with --memory-replay..."
    docker run ${DPORTS[@]} -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name $DOCKER_NAME -t "$DOCKER_IMAGE" witness_node --data-dir=/peerplays/witness_node_data_dir --replay --memory-replay
    echo "Started."
}

# Usage: ./run.sh shm_size size
# Resizes the ramdisk used for storing Steem's shared_memory at /dev/shm
# Size should be specified with G (gigabytes), e.g. ./run.sh shm_size 64G
#
shm_size() {
    if (( $# != 1 )); then
        msg red "Please specify a size, such as ./run.sh shm_size 64G"
    fi
    msg green " -> Setting /dev/shm to $1"
    sudo mount -o remount,size=$1 /dev/shm
    if [[ $? -eq 0 ]]; then
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
    docker stop -t ${STOP_TIME} $DOCKER_NAME
    msg red "Removing old container '${DOCKER_NAME}'..."
    docker rm $DOCKER_NAME
}

sbkill() {
    msg bold red "Killing container '${DOCKER_NAME}'..."
    docker kill "$DOCKER_NAME"
    msg red "Removing container ${DOCKER_NAME}"
    docker rm "$DOCKER_NAME"
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
    docker run ${DPORTS[@]} -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays --rm -it "$DOCKER_IMAGE" bash
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
    if (( $# == 1 )); then
        REMOTE_WS=$1
    fi
    docker run -v "$DATADIR":/peerplays --rm -it "$DOCKER_IMAGE" cli_wallet -s "$REMOTE_WS"
}

# Usage: ./run.sh logs
# Shows the last 30 log lines of the running steem container, and follows the log until you press ctrl-c
#
logs() {
    msg blue "DOCKER LOGS: (press ctrl-c to exit) "
    docker logs -f --tail=30 $DOCKER_NAME
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
        sudo apt-get update -y > /dev/null
        sudo apt-get install -y jq > /dev/null
    fi
    local LOG_PATH=$(docker inspect $DOCKER_NAME | jq -r .[0].LogPath)
    local pipe=/tmp/dkpipepc.fifo
    trap "rm -f $pipe" EXIT
    if [[ ! -p $pipe ]]; then
        mkfifo $pipe
    fi
    # the sleep is a dirty hack to keep the pipe open

    sleep 1000000 < $pipe &
    tail -n 5000 -f "$LOG_PATH" &> $pipe &
    while true
    do
        if read -r line <$pipe; then
            # first grep the data for "objects cached" to avoid
            # needlessly processing the data
            L=$(egrep --colour=never "objects cached|M free" <<< "$line")
            if [[ $? -ne 0 ]]; then
                continue
            fi
            # then, parse the line and print the time + log
            L=$(jq -r ".time +\" \" + .log" <<< "$L")
            # then, remove excessive \r's causing multiple line breaks
            L=$(sed -e "s/\r//" <<< "$L")
            # now remove the decimal time to make the logs cleaner
            L=$(sed -e 's/\..*Z//' <<< "$L")
            # and finally, strip off any duplicate new line characters
            L=$(tr -s "\n" <<< "$L")
            printf '%s\r\n' "$L"
        fi
    done
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
    mkdir -p "$bc_dir" "$p2p_dir" "$SHM_DIR" &> /dev/null

    msg yellow " :: Blockchain:           $bc_dir"
    msg yellow " :: P2P files:            $p2p_dir"
    msg yellow " :: Shared Mem / Rocksdb: $SHM_DIR"
    msg
    
    if (( $# == 1 )); then
        case $1 in
            sh*)
                msg bold red " !!! Clearing all files in SHM_DIR ( $SHM_DIR )"
                rm -rfv "$SHM_DIR"/*
                mkdir -p "$SHM_DIR" &> /dev/null
                msg bold green " +++ Cleared shared files directory."
                ;;
            bloc*)
                msg bold red " !!! Clearing all files in $bc_dir and $p2p_dir"
                rm -rfv "$bc_dir"/*
                rm -rfv "$p2p_dir"/*
                mkdir -p "$bc_dir" "$p2p_dir" &> /dev/null
                msg bold green " +++ Cleared blockchain files + p2p"
                ;;
            all)
                msg bold red " !!! Clearing blockchain, p2p, and shared memory files..."
                rm -rfv "$SHM_DIR"/*
                rm -rfv "$bc_dir"/*
                rm -rfv "$p2p_dir"/*
                mkdir -p "$bc_dir" "$p2p_dir" "$SHM_DIR" &> /dev/null
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
        mkdir -p "$bc_dir" &> /dev/null
        msg bold green " +++ Cleared blockchain files"
    else
        msg yellow " >> Not clearing blockchain folder."
    fi
    
    read -p "Do you want to remove the p2p files? (y/n) > " cleanp2p
    if [[ "$cleanp2p" == "y" ]]; then
        msg bold red " !!! Clearing p2p files..."
        rm -rvf "$p2p_dir"/*
        mkdir -p "$p2p_dir" &> /dev/null
        msg bold green " +++ Cleared p2p files"
    else
        msg yellow " >> Not clearing p2p folder."
    fi
    
    read -p "Do you want to remove the shared memory / rocksdb files? (y/n) > " cleanshm
    if [[ "$cleanshm" == "y" ]]; then
        msg bold red " !!! Clearing shared memory files..."
        rm -rvf "$SHM_DIR"/*
        mkdir -p "$SHM_DIR" &> /dev/null
        msg bold green " +++ Cleared shared memory files"
    else
        msg yellow " >> Not clearing shared memory folder."
    fi

    msg bold green " ++ Done."
}


if [ "$#" -lt 1 ]; then
    help
fi

case $1 in
    build)
        msg bold yellow "You may want to use '$0 install' for a binary image instead, it's faster."
        build "${@:2}"
        ;;
    build_full)
        msg bold yellow "You may want to use '$0 install_full' for a binary image instead, it's faster."
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
    start)
        start
        ;;
    replay)
        replay
        ;;
    memory_replay)
        memory_replay
        ;;
    shm_size)
        shm_size $2
        ;;
    stop)
        stop
        ;;
    kill)
        sbkill
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
    dlblocks)
        dlblocks "${@:2}"
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
    ver|version)
        ver
        ;;
    *)
        msg bold red "Invalid cmd"
        help
        ;;
esac
