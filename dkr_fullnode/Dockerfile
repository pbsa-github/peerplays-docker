FROM ubuntu:20.04
LABEL Peerplays Blockchain Standards Association

#===============================================================================
# Ubuntu setup
#===============================================================================

RUN \
    apt-get update -y && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y \
      apt-utils \
      autoconf \
      bash \
      build-essential \
      ca-certificates \
      cmake \
      dnsutils \
      doxygen \
      expect \
      git \
      graphviz \
      libboost1.67-all-dev \
      libbz2-dev \
      libcurl4-openssl-dev \
      libncurses-dev \
      libsnappy-dev \
      libssl-dev \
      libtool \
      libzip-dev \
      locales \
      lsb-release \
      mc \
      nano \
      net-tools \
      ntp \
      openssh-server \
      pkg-config \
      perl \
      python3 \
      python3-jinja2 \
      sudo \
      systemd-coredump \
      wget

ENV HOME /home/peerplays
RUN useradd -rm -d /home/peerplays -s /bin/bash -g root -G sudo -u 1000 peerplays
RUN echo "peerplays  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/peerplays
RUN chmod 440 /etc/sudoers.d/peerplays

RUN service ssh start
RUN echo 'peerplays:peerplays' | chpasswd

# SSH
EXPOSE 22

#===============================================================================
# libzmq setup
#===============================================================================

WORKDIR /home/peerplays/

RUN \
    wget https://github.com/zeromq/libzmq/archive/refs/tags/v4.3.4.zip && \
    unzip v4.3.4.zip && \
    cd libzmq-4.3.4 && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j$(nproc) install && \
    ldconfig

#===============================================================================
# cppzmq setup
#===============================================================================

WORKDIR /home/peerplays/

RUN \
    wget https://github.com/zeromq/cppzmq/archive/refs/tags/v4.8.1.zip && \
    unzip v4.8.1.zip && \
    cd cppzmq-4.8.1 && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j$(nproc) install && \
    ldconfig


###
# Overridable build arguments
# Can override during docker build using '--build-arg' like so:
#
#   docker build --build-arg "ENABLE_MIRA=OFF" --build-arg="PEERPLAYS_STATIC_BUILD=OFF" -t peerplays
#
###

ARG PEERPLAYS_VERSION=master
ENV PEERPLAYS_VERSION ${PEERPLAYS_VERSION}

ARG PEERPLAYS_SOURCE="https://gitlab.com/pbsa/peerplays.git"
ENV PEERPLAYS_SOURCE ${PEERPLAYS_SOURCE}

ARG PEERPLAYS_STATIC_BUILD=ON
ENV PEERPLAYS_STATIC_BUILD ${PEERPLAYS_STATIC_BUILD}

ARG ENABLE_MIRA=ON
ENV ENABLE_MIRA ${ENABLE_MIRA}

ARG LOW_MEMORY_MODE=ON
ENV LOW_MEMORY_MODE ${LOW_MEMORY_MODE}

ARG CLEAR_VOTES=ON
ENV CLEAR_VOTES ${CLEAR_VOTES}

ARG SKIP_BY_TX_ID=ON
ENV SKIP_BY_TX_ID ${SKIP_BY_TX_ID}

RUN \
    echo " >>> Cloning tag/branch ${PEERPLAYS_VERSION} from repo: ${PEERPLAYS_SOURCE}" && \
	git clone ${PEERPLAYS_SOURCE} peerplays -b ${PEERPLAYS_VERSION} && \
	cd peerplays && \
	git checkout ${PEERPLAYS_VERSION} && \
	git submodule update --init --recursive && \
    mkdir build && \ 
    cd build && \
	cmake -DBOOST_ROOT="$BOOST_ROOT" -DCMAKE_BUILD_TYPE=Release .. \
            -DLOW_MEMORY_NODE=${LOW_MEMORY_MODE} \
            -DCLEAR_VOTES=${CLEAR_VOTES} \
            -DPEERPLAYS_STATIC_BUILD=${PEERPLAYS_STATIC_BUILD} \
            -DSKIP_BY_TX_ID=${SKIP_BY_TX_ID} \
            -DENABLE_MIRA=${ENABLE_MIRA} && \
	make -j$(nproc) cli_wallet witness_node && \
    make install 

WORKDIR /home/peerplays/peerplays-network
RUN \
    ln -s /home/peerplays/peerplays/build/programs/cli_wallet/cli_wallet ./ && \
    ln -s /home/peerplays/peerplays/build/programs/witness_node/witness_node ./


VOLUME /peerplays-network


# P2P (seed) port
EXPOSE 2001
# RPC ports
EXPOSE 5000
EXPOSE 8090
EXPOSE 8091

ARG PEERPLAYSD_BIN="/usr/local/bin/witness_node"
ENV PEERPLAYSD_BIN ${PEERPLAYSD_BIN}

RUN echo "This container has been built with the following options:" >> /peerplays_build.txt && \
    echo "----" >> /peerplays_build.txt && \
    echo "Git Repository:              ${PEERPLAYS_SOURCE}" >> /peerplays_build.txt && \
    echo "Git version/commit:          ${PEERPLAYS_VERSION}\n----" >> /peerplays_build.txt && \
    echo "Default peerplays executable:   ${PEERPLAYSD_BIN}\n---" >> /peerplays_build.txt && \
    echo "--- CMake Config Options ---" >> /peerplays_build.txt && \
    echo "LOW_MEMORY_MODE=${LOW_MEMORY_MODE}\nPEERPLAYS_STATIC_BUILD=${PEERPLAYS_STATIC_BUILD}" >> /peerplays_build.txt && \
    echo "SKIP_BY_TX_ID=${SKIP_BY_TX_ID}\nENABLE_MIRA=${ENABLE_MIRA}\nCLEAR_VOTES=${CLEAR_VOTES}" >> /peerplays_build.txt && \
    echo "----\nBuilt at: $(date)\n----" >> /peerplays_build.txt

CMD ["sh", "-c", "${PEERPLAYSD_BIN}"]
