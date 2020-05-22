FROM ubuntu:18.04

# cd ~/dkr && docker build -t steem .
# docker run -p 0.0.0.0:2001:2001 -v $PWD/data:/steem -d -t steem


RUN apt-get update && \
    apt-get install -y apt-utils && \
    apt-get install -y gcc g++ cmake make libbz2-dev libdb++-dev libdb-dev && \
    apt-get install -y libssl-dev openssl libreadline-dev autoconf libtool git gdb liblz4-tool wget jq virtualenv libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev && \
    apt-get install -y autotools-dev build-essential libbz2-dev libicu-dev python-dev wget doxygen python3 python3-dev python3-pip libboost-all-dev curl && \
    apt-get install libncurses5-dev libcurl4-openssl-dev &&  \
    apt-get clean -qy

RUN pip3 install jinja2

###
# Overridable build arguments
# Can override during docker build using '--build-arg' like so:
#
#   docker build --build-arg "ENABLE_MIRA=OFF" --build-arg="STEEM_STATIC_BUILD=OFF" -t steem
#
###

ARG peerplaysd=master
ENV peerplaysd ${peerplaysd}

ARG PEERPLAYS_SOURCE="https://github.com/peerplays-network/peerplays.git"
ENV PEERPLAYS_SOURCE ${PEERPLAYS_SOURCE}

ARG STEEM_STATIC_BUILD=ON
ENV STEEM_STATIC_BUILD ${STEEM_STATIC_BUILD}

ARG ENABLE_MIRA=ON
ENV ENABLE_MIRA ${ENABLE_MIRA}

ARG LOW_MEMORY_MODE=ON
ENV LOW_MEMORY_MODE ${LOW_MEMORY_MODE}

ARG CLEAR_VOTES=ON
ENV CLEAR_VOTES ${CLEAR_VOTES}

ARG SKIP_BY_TX_ID=ON
ENV SKIP_BY_TX_ID ${SKIP_BY_TX_ID}

RUN cd ~ && \
    echo " >>> Cloning tag/branch ${peerplaysd} from repo: ${PEERPLAYS_SOURCE}" && \
	git clone ${PEERPLAYS_SOURCE} peerplays -b ${peerplaysd} && \
	cd peerplays && \
	BOOST_ROOT=$HOME/opt/boost_1_68_0 && \
	wget -c 'http://sourceforge.net/projects/boost/files/boost/1.68.0/boost_1_68_0.tar.bz2/download' -O boost_1_68_0.tar.bz2 && \
	tar xjf boost_1_68_0.tar.bz2 && \
	cd boost_1_68_0/ && \
	./bootstrap.sh "--prefix=$BOOST_ROOT" && \
	./b2 install && \
	git checkout ${peerplaysd} && \
	git submodule update --init --recursive && \
        cd ~/peerplays && \
	cmake -DBOOST_ROOT="$BOOST_ROOT" -DCMAKE_BUILD_TYPE=Release . \
            -DLOW_MEMORY_NODE=${LOW_MEMORY_MODE} \
            -DCLEAR_VOTES=${CLEAR_VOTES} \
            -DSTEEM_STATIC_BUILD=${STEEM_STATIC_BUILD} \
            -DSKIP_BY_TX_ID=${SKIP_BY_TX_ID} \
            -DENABLE_MIRA=${ENABLE_MIRA} && \
	make -j$(nproc) && make install && rm -rf ~/peerplays
VOLUME /peerplays
WORKDIR /peerplays

# P2P (seed) port
EXPOSE 2001
# RPC ports
EXPOSE 5000
EXPOSE 8090
EXPOSE 8091

ARG PEERPLAYSD_BIN="/usr/local/bin/witness_node"
ENV PEERPLAYSD_BIN ${PEERPLAYSD_BIN}

RUN echo "This container has been built with the following options:" >> /peerplays_build.txt && \
    echo "----" >> /steem_build.txt && \
    echo "Git Repository:              ${PEERPLAYS_SOURCE}" >> /peerplays_build.txt && \
    echo "Git version/commit:          ${peerplaysd}\n----" >> /peerplays_build.txt && \
    echo "Default peerplays executable:   ${PEERPLAYSD_BIN}\n---" >> /peerplays_build.txt && \
    echo "--- CMake Config Options ---" >> /peerplays_build.txt && \
    echo "LOW_MEMORY_MODE=${LOW_MEMORY_MODE}\nSTEEM_STATIC_BUILD=${STEEM_STATIC_BUILD}" >> /peerplays_build.txt && \
    echo "SKIP_BY_TX_ID=${SKIP_BY_TX_ID}\nENABLE_MIRA=${ENABLE_MIRA}\nCLEAR_VOTES=${CLEAR_VOTES}" >> /peerplays_build.txt && \
    echo "----\nBuilt at: $(date)\n----" >> /peerplays_build.txt

CMD ["sh", "-c", "${PEERPLAYSD_BIN}"]

