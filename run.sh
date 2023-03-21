#!/usr/bin/env bash
#
# Peerplays node manager
# Released under GNU AGPL by Someguy123
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
: ${DOCKER_DIR="$DIR/dkr"}
: ${FULL_DOCKER_DIR="$DIR/dkr_fullnode"}
: ${DATADIR="$DIR/data"}
: ${DOCKER_NAME="seed"}
: ${DOCKER_BITCOIN_NAME="bitcoind-node"}
: ${DOCKER_BITCOIN_VOLUME="bitcoind-data"}
: ${DOCKER_NETWORK="son"}
: ${SON_WALLET="son-wallet"}
: ${BTC_REGTEST_KEY="cSKyTeXidmj93dgbMFqgzD7yvxzA7QAYr5j9qDnY9seyhyv7gH2m"}

# the tag to use when running/replaying peerplaysd
: "${DOCKER_IMAGE="peerplays/peerplays-mainnet:latest"}"

BOLD="$(tput bold)"
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
BLUE="$(tput setaf 4)"
MAGENTA="$(tput setaf 5)"
CYAN="$(tput setaf 6)"
WHITE="$(tput setaf 7)"
RESET="$(tput sgr0)"
: ${DK_TAG="peerplays/peerplays-mainnet:latest"}
: ${DK_TAG_FULL="peerplays/peerplays:full"}
: ${DK_TEST="peerplays/peerplays-testnet:latest"}
: ${SHM_DIR="/dev/shm"}
# Amount of time in seconds to allow the docker container to stop before killing it.
# Default: 600 seconds (10 minutes)
: "${STOP_TIME=600}"

# Git repository to use when building Peerplays - containing peerplaysd code
: "${PEERPLAYS_SOURCE="https://gitlab.com/pbsa/peerplays.git"}"

# Comma separated list of ports to expose to the internet.
# By default, only port 9777 will be exposed (the P2P seed port)
: "${PORTS="9777"}"

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
: "${BC_FOLDER="$DATADIR/witness_node_data_dir"}"

: "${EXAMPLE_MIRA="$DATADIR/witness_node_data_dir/database.cfg.example"}"
: "${MIRA_FILE="$DATADIR/witness_node_data_dir/database.cfg"}"

: "${EXAMPLE_CONF="$DATADIR/witness_node_data_dir/config.ini.example"}"
: "${CONF_FILE="$DATADIR/witness_node_data_dir/seed_config.ini"}"

# bitcoin blockchain folder, used by dlbitcoin
: "${BTC_FOLDER="$DATADIR/libbitcoin"}"


# full path to btc regtest config
: "${BTC_REGTEST_CONF="/var/opt/peerplays-docker/bitcoin/regtest/bitcoin.conf"}"

# if the config file doesn't exist, try copying the example config
if [[ ! -f "$CONF_FILE" ]]; then
    if [[ -f "$EXAMPLE_CONF" ]]; then
        echo "${YELLOW}File config.ini not found. copying example (seed)${RESET}"
        cp -vi "$EXAMPLE_CONF" "$CONF_FILE" 
        echo "${GREEN} > Successfully installed example config for seed node.${RESET}"
        echo " > You may want to adjust this if you're running a witness, e.g. disable p2p-endpoint"
    else
        echo "${YELLOW}WARNING: You don't seem to have a config file and the example config couldn't be found...${RESET}"
        echo "${YELLOW}${BOLD}You may want to check these files exist, or you won't be able to launch Peerplays${RESET}"
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
        echo "${YELLOW}${BOLD}You may want to check these files exist, or you won't be able to use Peerplays with MIRA${RESET}"
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
    start_son - starts son seed container
    start_son_regtest - starts son seed container and bitcoind container under the docker network
    clean - Remove blockchain, p2p, and/or shared mem folder contents, seed, bitcoind, and son docker network (warns beforehand)
    dlblocks - download and decompress Peerplays blockchain to speed up your first start
    dlbitcoin - download and decompress the bitcoin blockchain to speed up SONs inital sync
    replay - starts seed container (in replay mode)
    replay_son - starts son seed container (in replay mode)
    memory_replay - starts seed container (in replay mode, with --memory-replay)
    shm_size - resizes /dev/shm to size given, e.g. ./run.sh shm_size 10G 
    stop - stops seed container
    status - show status of seed container
    restart - restarts seed container
    install_docker - install docker
    install - pulls latest docker image from server (no compiling)
    install_testnet - pulls latest testnet docker image from server (no compiling)
    install_full - pulls latest (FULL NODE FOR RPC) docker image from server (no compiling)
    rebuild - builds seed container (from docker file), and then restarts it
    build - only builds seed container (from docker file)
    logs - show all logs inc. docker logs, and seed logs
    wallet - open cli_wallet in the container
    remote_wallet - open cli_wallet in the container connecting to a remote seed
    enter - enter a bash session in the currently running container
    shell - launch the seed container with appropriate mounts, then open bash for inspection
    bos_install - install and spinup bos-auto
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
    if (( "$BUILD_FULL" == 1 )); then
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
    local has_peerplays_src='n'
    if (( $# >= 1 )); then
        msg yellow " >> Additional build arguments specified."
        for a in "$@"; do
            msg yellow " ++ Build argument: ${BOLD}${a}"
            BUILD_ARGS+=('--build-arg' "$a")
            if grep -q 'PEERPLAYS_SOURCE' <<< "$a"; then
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
        To use it in this peerplays-docker, run: 
        ${GREEN}${BOLD}
        docker tag $CUST_TAG peerplays:latest
        ${RESET}${RED}
    !!! !!! !!! !!! !!! !!! READ THIS !!! !!! !!! !!! !!! !!!
    !!! !!! !!! !!! !!! !!! READ THIS !!! !!! !!! !!! !!! !!!
        ${RESET}
            "
            msg bold green " +++ Successfully built peerplaysd"
            msg green " +++ Peerplays node type: ${BOLD}${fmm}"
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
# Version is prefixed with v, matching Peerplays releases
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
dlblocks() {
    pkg_not_found wget wget

    
    if [[ -f "$BC_FOLDER/blockchain/database/block_num_to_block/blocks" || -f "$BC_FOLDER/blockchain/database/block_num_to_block/index" || -f "$BC_FOLDER/mainnet-blocks-index.tar.gz" ]]; then
        echo "Blockchain database or an archive of it already exists:" 
        read -p "Do you want to delete and redownload or resume a partial download (Resuming also starts a fresh download, but doesnt decompress on the fly)? [y/n/r]: "  answer

        if [ "$answer" == "y" ]; then
            cd "$BC_FOLDER" || return
            msg "Removing old blocks and index files"
            rm -rfv "$BC_FOLDER/blockchain/database/" 2> /dev/null
            rm "$BC_FOLDER/blockchain/db_version" 2> /dev/null
            rm -rfv "$BC_FOLDER/blockchain/object_database/" 2> /dev/null
            msg yellow "Downloading and decompressing on the fly"
            curl https://peerplays.download/downloads/peerplays-mainnet/mainnet-blocks-index.tar.gz | tar xzvf -
            
        elif [ "$answer" == "n" ]; then
            msg "Nothing was removed, exiting.."
            exit 

        elif [ "$answer" == "r" ]; then
            cd "$BC_FOLDER" || return
            msg yellow "This option doesn't decompress on the fly, ensure you have more than 20GB of free space - Waiting 10 seconds.."
            #sleep 10
            wget -c https://peerplays.download/downloads/peerplays-mainnet/mainnet-blocks-index.tar.gz
            msg yellow "Extracting, this might take a minute.."
            tar xzvf mainnet-blocks-index.tar.gz
            
        else
            msg "Invalid input, enter 'y' or 'n' or 'r'"
            exit 1
        fi
    else
        msg yellow "Blockchain database doesn't exist, downloading and extracting the archieve - Ensure you have 20GB of free space.."
        cd "$BC_FOLDER" || exit
        curl https://peerplays.download/downloads/peerplays-mainnet/mainnet-blocks-index.tar.gz | tar xzvf -
        yellow msg "Ensure to extract this index where it was downloaded, inside of: " "$BC_FOLDER"
    
    fi

    #if (( $# > 0 )); then
    #    custom-dlblocks "$@"
    #    return $?
    #fi


    if [ $? == 0 ] ; then
        msg "FINISHED. Blockchain installed to ${BC_FOLDER}"
        echo "Remember to resize your /dev/shm, and run with replay!"
        echo "$ ./run.sh shm_size SIZE (e.g. 8G)"
        echo "$ ./run.sh replay"
    else 
        msg "Download error, please run dlblocks again."
    fi

}

dlbitcoin() {
    pkg_not_found wget wget
    
    if [[ ! -d "$BTC_FOLDER" ]]; then
        msg "Libbitcoin Blockchain database doesn't exist, creating and starting download - Ensure you have atleast 1TB free disk space.."
        df -h .
        sleep 10

        

        mkdir "$BTC_FOLDER"
    fi

    if [[ -f "$BTC_FOLDER/mainnet-libbitcoin.tar.gz" || -f "$BTC_FOLDER/blockchain/transaction_table" || -f "$BTC_FOLDER/blockchain/history_rows" || -f "$BTC_FOLDER/blockchain/block_index" ]]; then
        echo "Bitcoin blockchain database or an archive of it already exists:" 
        read -p "Do you want to delete and redownload or resume a partial download (Resuming also starts a fresh download, but doesnt decompress on the fly)? [y/n/r]: "  answer

        if [ "$answer" == "y" ]; then
            cd "$BTC_FOLDER" || return
            msg red "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            msg red "!! THIS OPTION IS NOT SAFE IF YOU HAVE AN UNSTABLE INTERNET CONNECTION !!!!!!!!!!!!!!!!"
            msg red "!! IF DOWNLOAD IS RESTARTED, PROGRESS WILL BE DESTROYED - USE OPTION "r" TO BE SAFE !!!!!"
            msg red "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            msg red "Ensure you have atleast 970GB+ of free disk space!"
            msg yellow "Download will begin in 40 seconds, please use option "r" to be safe"
            df -h .
            sleep 40
            msg red "Downloading and decompressing on the fly"
            msg "Removing old blocks and index files"
            rm -rfv "$BTC_FOLDER/blockchain/" 2> /dev/null
            curl https://peerplays.download/downloads/libbitcoin-mainnet/mainnet-libbitcoin.tar.gz | tar xzvf -
            
        elif [ "$answer" == "n" ]; then
            msg "Nothing was removed, exiting.."
            exit 

        elif [ "$answer" == "r" ]; then
            cd "$BTC_FOLDER" || return
            msg red "This option doesn't decompress on the fly, ensure you have more than 1.625TB (970+GB TOTAL used after removing tarball..) - Waiting 10 seconds.."
            df -h .
            sleep 10
            wget -c https://peerplays.download/downloads/libbitcoin-mainnet/mainnet-libbitcoin.tar.gz 
            msg yellow "Extracting, this will take some time.."
            tar xzvf mainnet-libbitcoin.tar.gz
            
        else
            msg "Invalid input, enter 'y' or 'n' or 'r'"
            exit 1
        fi
    else
        msg red "Bitcoin blockchain database doesn't exist, downloading and extracting the archieve - Ensure you have 970+GB of free space.."
        df -h . 
        sleep 10
        cd "$BTC_FOLDER" || exit
        wget -c https://peerplays.download/downloads/libbitcoin-mainnet/mainnet-libbitcoin.tar.gz
        tar xzvf mainnet-libbitcoin.tar.gz
    fi

    #if (( $# > 0 )); then
    #    custom-dlblocks "$@"
    #    return $?
    #fi

    if [ $? == 0 ] ; then
        msg "FINISHED. Libbitcoin Blockchain installed to ${BTC_FOLDER}"
    else 
        msg "Download error, please run dlblocks again."
    fi

}

# Usage: ./run.sh install_docker
# Downloads and installs the latest version of Docker using the Get Docker site
# If Docker is already installed, it should update it.
install_docker() {
    sudo apt update
    # curl/git used by docker, xz/lz4 used by dlblocks, jq used by tslogs/pclogs
    sudo apt install curl git xz-utils liblz4-tool jq -y
    curl https://get.docker.com | sh
    if [ "$EUID" -ne 0 ]; then 
        echo "Adding user $(whoami) to docker group"
        sudo usermod -aG docker "$(whoami)"
        echo "IMPORTANT: Please re-login (or close and re-connect SSH) for docker to function correctly"
    fi
}

# Usage: ./run.sh install [tag] [env flag]
# Downloads the Peerplays low memory node image from Peerplays official builds, or a custom tag if supplied
#
#   tag - optionally specify a docker tag to install from. can be third party
#         format: user/repo:version    or   user/repo   (uses the 'latest' tag)
#
#   env flag - optinally
#
#
# If no tag specified, it will download the pre-set $DK_TAG in run.sh or .env
# Default tag is normally peerplays/peerplays-mainnet:latest (official builds by the creator of peerplays-docker).
#
install() {
    if (( $# == 1 )); then
        DK_TAG=$1
        # If neither '/' nor ':' are present in the tag, then for convenience, assume that the user wants
        # peerplays/peerplays with this specific tag.
        if grep -qv ':' <<< "$1"; then
            if grep -qv '/' <<< "$1"; then
                msg bold red "WARNING: Neither / nor : were present in your tag '$1'"
                DK_TAG="peerplays/peerplays-mainnet:$1"
                msg red "We're assuming you've entered a version, and will try to install Peerplays's image: '${DK_TAG}'"
                msg yellow "If you *really* specifically want '$1' from Docker hub, set DK_MAIN='$1' inside of .env and run './run.sh install'"
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

# Usage: ./run.sh install_testnet [tag]
# Downloads the Peerplays low memory node image from Peerplays official builds, or a custom tag if supplied
#
#   tag - optionally specify a docker tag to install from. can be third party
#         format: user/repo:version    or   user/repo   (uses the 'latest' tag)
#
# If no tag specified, it will download the pre-set $DK_TEST in run.sh or .env
# Default tag is normally peerplays/peerplays-testnet:latest (official builds by the creator of peerplays-docker).
#
install_testnet() {
    if (( $# == 1 )); then
        DK_TEST=$1
        # If neither '/' nor ':' are present in the tag, then for convenience, assume that the user wants
        # peerplays/peerplays with this specific tag.
        if grep -qv ':' <<< "$1"; then
            if grep -qv '/' <<< "$1"; then
                msg bold red "WARNING: Neither / nor : were present in your tag '$1'"
                DK_TEST="peerplays/peerplays-testnet:$1"
                msg red "We're assuming you've entered a version, and will try to install Peerplays's image: '${DK_TEST}'"
                msg yellow "If you *really* specifically want '$1' from Docker hub, set DK_TEST='$1' inside of .env and run './run.sh install'"
            fi
        fi
    fi
    msg bold red "NOTE: You are installing image $DK_TEST. Please make sure this is correct."
    sleep 2
    msg yellow " -> Loading image from ${DK_TEST}"
    docker pull "$DK_TEST"
    msg green " -> Tagging as peerplays"
    docker tag "$DK_TEST" peerplays
    msg bold green " -> Installation completed. You may now configure or run the server"
}

# Usage: ./run.sh install_full
# Downloads the Peerplays full node image from the pre-set $DK_TAG_FULL in run.sh or .env
# Default tag is normally peerplays/peerplays:latest-full (official builds by the creator of peerplays-docker).

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
# Checks if the bitcoin container exists. Returns 0 if it does, -1 if not.
# Usage:
# if bitcoin_regtest_exists; then echo "true"; else "false"; fi
#
bitcoin_regtest_exists() {
    networkcount=$(docker ps -a -f name="^/"$DOCKER_BITCOIN_NAME"$" | wc -l)
    if [[ $networkcount -eq 2 ]]; then
        return 0
    else
        return -1
    fi
}

# Internal Use Only
# Checks if the son network exists. Returns 0 if it does, -1 if not.
# Usage:
# if son_network_exists; then echo "true"; else "false"; fi
#
son_network_exists() {
    networkcount=$(docker network ls | grep son | wc -l)
    if [[ $networkcount -eq 2 ]]; then
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
# Creates and/or starts the Peerplays docker container
start() {
    msg bold green " -> Starting container '${DOCKER_NAME}'..."
    seed_exists
    if [[ $? == 0 ]]; then
        docker start "$DOCKER_NAME"
    else
        docker run ${DPORTS[@]} -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays-network -d --name "$DOCKER_NAME" -t "$DOCKER_IMAGE" witness_node --data-dir=/home/peerplays/peerplays-network/witness_node_data_dir
    fi
}

# Usage: ./run.sh start_son
# Creates and/or starts the Peerplays SON docker container
start_son() {
    msg bold green " -> Starting container '${DOCKER_NAME}'..."
    seed_exists
    if [[ $? == 0 ]]; then
        docker start $DOCKER_NAME
    else
        docker run ${DPORTS[@]} --network son -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name $DOCKER_NAME -t "$DOCKER_IMAGE" witness_node --data-dir=/peerplays/witness_node_data_dir
    fi
}


# Usage: ./run.sh start_son_regtest
# Creates and/or starts the Peerplays SON docker container with a Bitcoin regtest node in a created docker network.
start_son_regtest() {
    msg yellow " -> Verifying network '${DOCKER_NETWORK}'..."
    son_network_exists
    if [[ $? == 0 ]]; then
        msg yellow " -> Network '${DOCKER_NETWORK}' exists"
    else
        docker network create ${DOCKER_NETWORK}
    fi

    msg bold green " -> Starting container $DOCKER_BITCOIN_NAME..."
    bitcoin_regtest_exists
    if [[ $? == 0 ]]; then
        docker start $DOCKER_BITCOIN_NAME
    else
        docker run -v $DOCKER_BITCOIN_VOLUME:/bitcoin --name=$DOCKER_BITCOIN_NAME -d -p 8333:8333 -p 127.0.0.1:8332:8332 -v ${BTC_REGTEST_CONF}:/bitcoin/.bitcoin/bitcoin.conf --network ${DOCKER_NETWORK} kylemanna/bitcoind
        sleep 40
        docker exec $DOCKER_BITCOIN_NAME bitcoin-cli createwallet ${SON_WALLET}
        docker exec $DOCKER_BITCOIN_NAME bitcoin-cli -rpcwallet=${SON_WALLET} importprivkey ${BTC_REGTEST_KEY}
    fi

    msg bold green " -> Starting container '${DOCKER_NAME}'..."
    seed_exists
    if [[ $? == 0 ]]; then
        docker start $DOCKER_NAME
    else
        docker run ${DPORTS[@]} --entrypoint /peerplays/son-entrypoint.sh --network ${DOCKER_NETWORK} -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name $DOCKER_NAME -t "$DOCKER_IMAGE" witness_node --data-dir=/peerplays/witness_node_data_dir
    fi
}

# Usage: ./run.sh replay
# Replays the blockchain for the Peerplays docker container
# If Peerplays is already running, it will ask you if you still want to replay
# so that it can stop and remove the old container
#
replay() {
    seed_running
    if [[ $? == 0 ]]; then
        echo "$RED""WARNING: Your Peerplays server ($DOCKER_NAME) is currently running""$RESET"
        echo
        docker ps
        echo
        read -p "Do you want to stop the container and replay? (y/n) > " shouldstop
        if [[ "$shouldstop" == "y" ]]; then
            stop
        else
            echo "$GREEN""Did not say 'y'. Quitting.""$RESET"
            return
        fi
    fi 
    msg yellow " -> Removing old container '${DOCKER_NAME}'"
    docker rm "$DOCKER_NAME" 2> /dev/null
    msg green " -> Running peerplays (image: ${DOCKER_IMAGE}) with replay in container '${DOCKER_NAME}'..."
    docker run --restart unless-stopped ${DPORTS[@]} -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays-network -d --name "$DOCKER_NAME" -t "$DOCKER_IMAGE" witness_node --data-dir=/home/peerplays/peerplays-network/witness_node_data_dir --replay
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

# Usage: ./run.sh son_replay
# Replays the SON chain
replay_son() {
    msg bold green " -> Starting container '${DOCKER_NAME}'..."
    seed_exists
    if [[ $? == 0 ]]; then
        docker start $DOCKER_NAME
    else
        docker run ${DPORTS[@]} --entrypoint /peerplays/son-entrypoint.sh --network son -v "$SHM_DIR":/shm -v "$DATADIR":/peerplays -d --name $DOCKER_NAME -t "$DOCKER_IMAGE" witness_node --data-dir=/peerplays/witness_node_data_dir --replay
    fi
}

# Usage: ./run.sh shm_size size
# Resizes the ramdisk used for storing Peerplays's shared_memory at /dev/shm
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
# Stops the Peerplays container, and removes the container to avoid any leftover
# configuration, e.g. replay command line options
#
stop() {
    msg "If you don't care about a clean stop, you can force stop the container with ${BOLD}./run.sh kill"
    msg red "Stopping container '${DOCKER_NAME}' (allowing up to ${STOP_TIME} seconds before killing)..."
    docker stop -t "${STOP_TIME}" "$DOCKER_NAME"
    msg red "Removing old container '${DOCKER_NAME}'..."
    docker rm "$DOCKER_NAME"
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
# Opens cli_wallet inside of the running Peerplays container and
# connects to the local peerplaysd over websockets on port 8090
#
wallet() {
    docker exec -it $DOCKER_NAME cli_wallet -s ws://127.0.0.1:8090
}

# Usage: ./run.sh remote_wallet [wss_server]
# Connects to a remote websocket server for wallet connection. This is completely safe
# as your wallet/private keys are never sent to the remote server.
#
# By default, it will connect to peerplays witness nodes (ws = normal websockets, wss = secure HTTPS websockets)
#
remote_wallet() {
    if (( $# == 1 )); then
        REMOTE_WS=$1
    fi
    docker run -v "$DATADIR":/peerplays --rm -it "$DOCKER_IMAGE" cli_wallet -s "$REMOTE_WS"
}

# Usage: ./run.sh logs
# Shows the last 30 log lines of the running Peerplays container, and follows the log until you press ctrl-c
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
# Scans and follows a large portion of your Peerplays logs then filters to only include the replay percentage
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
            son)
                msg bold red "!!! Clearing all files in $bc_dir and $p2p_dir and removing $DOCKER_NAME, $DOCKER_BITCOIN_NAME containers and $DOCKER_NETWORK docker network and $DOCKER_BITCOIN_VOLUME volume"
                docker stop $DOCKER_NAME
                docker rm $DOCKER_NAME
                docker stop $DOCKER_BITCOIN_NAME
                docker rm $DOCKER_BITCOIN_NAME
                docker network rm $DOCKER_NETWORK
                docker volume rm $DOCKER_BITCOIN_VOLUME
                rm -rfv "$bc_dir"/*
                rm -rfv "$p2p_dir"/*
                mkdir -p "$bc_dir" "$p2p_dir" &> /dev/null
                msg bold green " +++ Cleared blockchain files + p2p + peerplays container + bitcoin container + son network"
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

bos_install() {
  msg green "Insatall BOS"
  msg yellow $DIR
  sudo apt-get -y install libffi-dev libssl-dev python-dev python3-dev python3-pip libsecp256k1-dev build-essential

  pip3 install virtualenv

  sudo apt-get install mongodb
  sudo systemctl enable mongodb
  sudo systemctl start mongodb

  sudo apt-get install redis-server
  sudo systemctl enable redis
  sudo systemctl start redis

  sudo service mongodb status
  # sudo service redis status

  cd bos-auto
  # create virtual environment
  virtualenv -p python3 env
  # activate environment
  source env/bin/activate
  # install bos-auto into virtual environment
  pip3 install bos-auto
  
  peerplays createwallet
  # peerplays set node wss://irona.peerplays.download:8090
  peerplays set node ws://localhost:8090
  # peerplays set node: wss://hercules.peerplays.download/api

  peerplays addkey
 
  sudo cp bos-auto.service /etc/systemd/system/bos-auto.service
  sudo cp bos-auto-worker.service /etc/systemd/system/bos-auto-worker.service

  sudo systemctl daemon-reload

  sudo systemctl enable bos-auto.service 
  sudo systemctl enable bos-auto-worker.service 

  sudo systemctl start bos-auto.service
  sudo systemctl start bos-auto-worker.service

  msg green "BOS installation completed"
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
    install_testnet)
        install_testnet "${@:2}"
        ;;
    install_full)
        install_full
        ;;
    start)
        start
        ;;
    start_son)
        start_son
        ;;
    start_son_regtest)
        start_son_regtest
        ;;
    replay)
        replay
        ;;
    replay_son)
        replay_son
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
    dlbitcoin)
        dlbitcoin "${@:2}"
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
    bos_install)
        bos_install
        ;;
    *)
        msg bold red "Invalid cmd"
        help
        ;;
esac
