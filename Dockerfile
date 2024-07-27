FROM ubuntu:noble

LABEL org.opencontainers.image.author="Anyshpm Chen<anyshpm@anyshpm.com>"
LABEL org.opencontainers.image.source=https://github.com/anyshpm/docker-openpose

ARG OPENPOSE_BRANCH
ENV OPENPOSE_BRANCH=${OPENPOSE_BRANCH:-master}

# -----------------------------------
# set apt and pypi sources
#RUN echo "deb https://mirrors.ustc.edu.cn/ubuntu/ noble main restricted universe multiverse" > /etc/apt/sources.list  \
#    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ noble-security main restricted universe multiverse" >> /etc/apt/sources.list  \
#    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ noble-updates main restricted universe multiverse" >> /etc/apt/sources.list  \
#    echo "deb https://mirrors.ustc.edu.cn/ubuntu/ noble-backports main restricted universe multiverse" >> /etc/apt/sources.list
#RUN pip config --user set global.index     https://mirror.baidu.com/pypi/
#RUN pip config --user set global.index-url https://mirror.baidu.com/pypi/simple/

# -----------------------------------
# let pip do not cache
#ENV PIP_NO_CACHE_DIR=true 
# let albumentations do not check for update
#ENV NO_ALBUMENTATIONS_UPDATE=1

# -----------------------------------
# set working directory
ENV WORK_DIR="/src" 
ENV SRC_DIR="${WORK_DIR}/openpose" 
ENV BUILD_DIR="${WORK_DIR}/build"
#ENV VIRTUAL_ENV="${WORK_DIR}/venv" 
#ENV PATH="${VIRTUAL_ENV}/bin:${PATH}" 

# -----------------------------------
# install essentials for build
RUN set -ex && \
    apt-get update && \
    apt-get install -y --no-install-recommends unzip \
        git protobuf-compiler cmake g++ make \
        ca-certificates \
        libprotobuf-dev libgoogle-glog-dev libopencv-dev \
        libboost-thread-dev libboost-filesystem-dev \
        libhdf5-dev \
        libatlas-base-dev \
        python-dev-is-python3 \
        python3-opencv

# -----------------------------------
# download openpose source code
WORKDIR "${WORK_DIR}"
RUN set -ex && \
    git config --global advice.detachedHead false && \
    git clone --branch=$OPENPOSE_BRANCH https://github.com/CMU-Perceptual-Computing-Lab/openpose.git $SRC_DIR && \
    cd $SRC_DIR && \
    git submodule update --init --recursive --remote && \
    sed -i 's#coded_input->SetTotalBytesLimit(kProtoReadBytesLimit, 536870912);#coded_input->SetTotalBytesLimit(kProtoReadBytesLimit);#g' $SRC_DIR/3rdparty/caffe/src/caffe/util/io.cpp

# -----------------------------------
# build
WORKDIR "${BUILD_DIR}"
RUN set -ex && \
    mkdir -p $BUILD_DIR && \
    cmake -D GPU_MODE=CPU_ONLY -D BUILD_PYTHON=1 \
          -D DOWNLOAD_BODY_25_MODEL=0 -D DOWNLOAD_FACE_MODEL=0 -D DOWNLOAD_HAND_MODEL=0 \
          -G "Unix Makefiles" -S $SRC_DIR -B . && \
    make -j$(nproc)

# -----------------------------------
# remove build tools and apt cache
RUN set -ex && \
    apt-get remove -y --no-install-recommends git protobuf-compiler cmake make gcc g++ && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/* && \
    rm -rf $SRC_DIR
