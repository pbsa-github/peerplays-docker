
FROM ubuntu:bionic

# cd ~/dkr && docker build -t peerplays .
# docker run -p 0.0.0.0:2001:2001 -v $PWD/data:/PEERPLAYS -d -t peerplays


RUN apt-get update && \
    apt-get install -y gcc g++ cmake make libbz2-dev libdb++-dev libdb-dev && \
    apt-get install -y libssl-dev openssl libreadline-dev autoconf libtool git gdb liblz4-tool wget jq virtualenv libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev && \
    apt-get install -y autotools-dev build-essential libbz2-dev libicu-dev python-dev wget doxygen python3 python3-dev python3-pip libboost-all-dev curl && \
    apt-get clean -qy

RUN pip3 install jinja2

###
# Overridable build arguments
# Can override during docker build using '--build-arg' like so:
#
#   docker build --build-arg "ENABLE_MIRA=OFF" --build-arg="PEERPLAYS_STATIC_BUILD=OFF" -t peerplays
#
###

ARG PEERPLAYSd_version=stable
ENV PEERPLAYSd_version ${PEERPLAYSd_version}

ARG PEERPLAYS_SOURCE="local_src_folder"
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

COPY src/ /root/PEERPLAYS/

RUN cd ~ && \
    echo " >>> Building PEERPLAYS ${PEERPLAYSd_version} from local source code in src/" && \
	cd PEERPLAYS && \
	git submodule update --init --recursive && \
	cmake -DCMAKE_BUILD_TYPE=Release . \
            -DLOW_MEMORY_NODE=${LOW_MEMORY_MODE} \
            -DCLEAR_VOTES=${CLEAR_VOTES} \
            -DPEERPLAYS_STATIC_BUILD=${PEERPLAYS_STATIC_BUILD} \
            -DSKIP_BY_TX_ID=${SKIP_BY_TX_ID} \
            -DENABLE_MIRA=${ENABLE_MIRA} && \
	make -j$(nproc) && make install && rm -rf ~/PEERPLAYS
VOLUME /PEERPLAYS
WORKDIR /PEERPLAYS

# P2P (seed) port
EXPOSE 2001
# RPC ports
EXPOSE 5000
EXPOSE 8090
EXPOSE 8091

ARG PEERPLAYSD_BIN="/usr/local/bin/PEERPLAYSd"
ENV PEERPLAYSD_BIN ${PEERPLAYSD_BIN}

RUN echo "This container has been built with the following options:" >> /PEERPLAYS_build.txt && \
    echo "----" >> /PEERPLAYS_build.txt && \
    echo "Git Repository:              ${PEERPLAYS_SOURCE}" >> /PEERPLAYS_build.txt && \
    echo "Git version/commit:          ${PEERPLAYSd_version}\n----" >> /PEERPLAYS_build.txt && \
    echo "Default PEERPLAYSd executable:   ${PEERPLAYSD_BIN}\n---" >> /PEERPLAYS_build.txt && \
    echo "--- CMake Config Options ---" >> /PEERPLAYS_build.txt && \
    echo "LOW_MEMORY_MODE=${LOW_MEMORY_MODE}\nPEERPLAYS_STATIC_BUILD=${PEERPLAYS_STATIC_BUILD}" >> /PEERPLAYS_build.txt && \
    echo "SKIP_BY_TX_ID=${SKIP_BY_TX_ID}\nENABLE_MIRA=${ENABLE_MIRA}\nCLEAR_VOTES=${CLEAR_VOTES}" >> /PEERPLAYS_build.txt && \
    echo "----\nBuilt at: $(date)\n----" >> /PEERPLAYS_build.txt

RUN echo "Please configure me! You need to mount a data directory onto /PEERPLAYS of this container to it to function correctly. (if you're using PEERPLAYS-in-a-box most of this is handled automatically)"
CMD ["sh", "-c", "${PEERPLAYSD_BIN}"]


