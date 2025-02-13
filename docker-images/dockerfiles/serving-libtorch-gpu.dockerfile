ARG UBUNTU_VERSION

# Base.

FROM "ubuntu:$UBUNTU_VERSION" as base

COPY script/run_server.sh /script/run_server.sh

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        libpng-dev \
        libjpeg-dev &&\
    apt-get clean && \
    find /var/lib/apt/lists -delete

RUN . /etc/os-release && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        gnupg curl software-properties-common && \
    curl "https://developer.download.nvidia.com/compute/cuda/repos/$ID$(echo $VERSION_ID | tr -d .)/x86_64/3bf863cc.pub" | apt-key add - && \
    curl "https://developer.download.nvidia.com/compute/machine-learning/repos/$ID$(echo $VERSION_ID | tr -d .)/x86_64/7fa2af80.pub" | apt-key add - && \
    apt-add-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/$ID$(echo $VERSION_ID | tr -d .)/x86_64 /" && \
    apt-add-repository -u "deb https://developer.download.nvidia.com/compute/machine-learning/repos/$ID$(echo $VERSION_ID | tr -d .)/x86_64 /" && \
    apt-get autoremove --purge -y curl gnupg software-properties-common && \
    apt-get clean && \
    find /var/lib/apt/lists -delete

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        cuda-cufft-dev-10-2 \
        cuda-cupti-dev-10-2 \
        cuda-curand-dev-10-2 \
        cuda-cusolver-dev-10-2 \
        cuda-cusparse-dev-10-2 \
        cuda-nvml-dev-10-2 \
        cuda-nvrtc-10-2 \
        cuda-nvrtc-dev-10-2 \
        cuda-nvtx-10-2 \
        libcublas-dev=10.2.* \
        'libcudnn8=*+cuda10.2' \
        'libcudnn8-dev=*+cuda10.2' && \
    apt-get clean && \
    find /var/lib/apt/lists -delete

RUN apt-mark hold libcudnn8 libcudnn8-dev

RUN ln -s /usr/local/cuda-10.2 /usr/local/cuda
ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64:$LD_LIBRARY_PATH

# Builder.

FROM base as builder

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        git \
        automake \
        libpython2.7-stdlib \
        libpython3-dev \
        libtool \
        libssl-dev \
        make \
        patch \
        python-minimal \
        python3-distutils \
        python3-numpy && \
    apt-get clean && \
    find /var/lib/apt/lists -delete

RUN apt-get update && \
    apt-get install --no-install-recommends -y wget unzip g++ ca-certificates && \
    wget "https://github.com/Kitware/CMake/releases/download/v3.21.5/cmake-3.21.5.zip" && \
    unzip cmake-3.21.5.zip && rm cmake-3.21.5.zip && \
    cd cmake-3.21.5 && ./bootstrap && \
    make && make install && \
    apt-get autoremove --purge -y wget unzip && \
    apt-get clean && \
    find /var/lib/apt/lists -delete

WORKDIR /

RUN apt-get update && \
    apt-get install --no-install-recommends -y wget unzip && \
    wget "https://download.pytorch.org/libtorch/cu102/libtorch-cxx11-abi-shared-with-deps-1.8.1%2Bcu102.zip" && \
    unzip libtorch-cxx11-abi-shared-with-deps-1.8.1+cu102.zip && \
    rm libtorch-cxx11-abi-shared-with-deps-1.8.1+cu102.zip && \
    wget "https://github.com/pytorch/vision/archive/refs/tags/v0.9.1.zip" && \
    unzip v0.9.1.zip && rm v0.9.1.zip && \
    apt-get autoremove --purge -y wget unzip && \
    apt-get clean && \
    find /var/lib/apt/lists -delete

RUN apt-get update && \
    cd /vision-0.9.1 && mkdir build && cd build && \
    cmake -DCMAKE_PREFIX_PATH=/libtorch -DCMAKE_INSTALL_PREFIX=/vision-0.9.1 -DWITH_CUDA=ON -DCMAKE_BUILD_TYPE=Release .. && \
    cmake --build . && make install && \
    apt-get clean && \
    find /var/lib/apt/lists -delete

COPY . /src

WORKDIR /src

RUN ln -s /usr/local/cuda-10.2/include /src/third_party/cuda

RUN apt-get update && \
    apt-get install --no-install-recommends -y wget && \
    wget 'https://storage.googleapis.com/bazel-apt/doc/apt-key.pub.gpg' -O /etc/apt/trusted.gpg.d/bazel.asc && \
    apt-get autoremove --purge -y wget && \
    apt-get clean && \
    find /var/lib/apt/lists -delete

RUN echo 'deb https://storage.googleapis.com/bazel-apt stable jdk1.8' >> /etc/apt/sources.list

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    bazel=4.2.2 && \
    apt-get clean && \
    find /var/lib/apt/lists -delete


RUN bazel build --config=libtorch-gpu --cxxopt='-std=c++14' //adlik_serving

# Runtime.

FROM base

COPY --from=builder /src/bazel-bin/adlik_serving/adlik_serving /usr/local/bin/adlik-serving
COPY --from=builder /libtorch/lib/ /usr/local/lib/
COPY --from=builder /vision-0.9.1/lib/libtorchvision.so /usr/local/lib/libtorchvision.so

ENV LD_LIBRARY_PATH=/usr/local/lib

RUN chmod +x /script/run_server.sh
