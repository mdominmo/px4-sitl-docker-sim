# syntax=docker/dockerfile:1

ARG PX4_VERSION=v1.17.0
ARG MICRO_XRCE_VERSION=v3.0.1

# ═══════════════════════════════════════════════════════════════════════════════
# Stage: base — CUDA runtime + system packages, timezone, locale
# ═══════════════════════════════════════════════════════════════════════════════
FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04 AS base

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Europe/Madrid \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo curl git zip unzip wget \
        lsb-release software-properties-common gnupg ca-certificates \
        locales python3 python3-pip \
        libx11-6 libxext6 libxrender1 libxtst6 libxi6 libxrandr2 \
        libxcursor1 libxcomposite1 libxdamage1 libxfixes3 libxss1 \
        libasound2 libpulse0 libgl1-mesa-glx libgl1-mesa-dri \
        libegl1 libglu1-mesa x11-apps mesa-utils libfuse2 \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ═══════════════════════════════════════════════════════════════════════════════
# Stage: gazebo-ros — Gazebo Harmonic + ROS 2 Humble
# ═══════════════════════════════════════════════════════════════════════════════
FROM base AS gazebo-ros

RUN wget https://packages.osrfoundation.org/gazebo.gpg \
       -O /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] \
       http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
       | tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null \
    && apt-get update && apt-get install -y --no-install-recommends \
       gz-harmonic \
       libgz-transport13-dev \
       python3-gz-transport13 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/apt/keyrings \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
       | gpg --dearmor -o /etc/apt/keyrings/ros-archive-keyring.gpg \
    && add-apt-repository universe \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/ros-archive-keyring.gpg] \
       http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" \
       | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
       ros-humble-desktop \
       ros-dev-tools \
       ros-humble-ament-cmake \
       ros-humble-geographic-msgs \
       ros-humble-ros-gzharmonic \
    && rm -rf /var/lib/apt/lists/*

# ═══════════════════════════════════════════════════════════════════════════════
# Stage: micro-xrce-source — download Micro-XRCE-DDS-Agent repo (cached)
# ═══════════════════════════════════════════════════════════════════════════════
FROM base AS micro-xrce-source

RUN git clone --depth 1 \
        https://github.com/eProsima/Micro-XRCE-DDS-Agent.git \
        /opt/Micro-XRCE-DDS-Agent

# ═══════════════════════════════════════════════════════════════════════════════
# Stage: micro-xrce-builder — checkout version + compile
# ═══════════════════════════════════════════════════════════════════════════════
FROM micro-xrce-source AS micro-xrce-builder

ARG MICRO_XRCE_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake \
    && rm -rf /var/lib/apt/lists/*

RUN cd /opt/Micro-XRCE-DDS-Agent \
    && git fetch --depth 1 origin ${MICRO_XRCE_VERSION} \
    && git checkout FETCH_HEAD \
    && mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /opt/Micro-XRCE-DDS-Agent

# ═══════════════════════════════════════════════════════════════════════════════
# Stage: px4-source — download PX4-Autopilot repo (cached)
# ═══════════════════════════════════════════════════════════════════════════════
FROM gazebo-ros AS px4-source

WORKDIR /workspace/px4_sitl_docker_sim

RUN git clone --depth 1 https://github.com/PX4/PX4-Autopilot.git

# ═══════════════════════════════════════════════════════════════════════════════
# Stage: px4-toolchain — checkout PX4_VERSION + install PX4 build dependencies
# ═══════════════════════════════════════════════════════════════════════════════
FROM px4-source AS px4-toolchain

ARG PX4_VERSION

RUN cd PX4-Autopilot \
    && git fetch --depth 1 origin tag ${PX4_VERSION} \
    && git checkout ${PX4_VERSION} \
    && git submodule update --init --recursive --depth 1

RUN PX4-Autopilot/Tools/setup/ubuntu.sh --no-nuttx --no-sim-tools \
    && rm -rf /var/lib/apt/lists/*

# ═══════════════════════════════════════════════════════════════════════════════
# Stage: px4-builder — compile PX4 SITL firmware
# ═══════════════════════════════════════════════════════════════════════════════
FROM px4-toolchain AS px4-builder

RUN cd PX4-Autopilot && make px4_sitl -j"$(nproc)"

# ═══════════════════════════════════════════════════════════════════════════════
# Stage: runtime — final image
# ═══════════════════════════════════════════════════════════════════════════════
FROM px4-toolchain AS runtime

ARG UID=1000
ARG GID=1000
ARG USERNAME=dev

ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all

COPY --from=micro-xrce-builder /usr/local/ /usr/local/
RUN ldconfig /usr/local/lib/

COPY --from=px4-builder \
     /workspace/px4_sitl_docker_sim/PX4-Autopilot/build/ \
     /workspace/px4_sitl_docker_sim/PX4-Autopilot/build/

RUN groupadd -g ${GID} ${USERNAME} \
    && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME} \
    && usermod -aG video ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

COPY . /workspace/px4_sitl_docker_sim/

RUN chown -R ${USERNAME}:${USERNAME} /workspace \
    && chmod +x scripts/launch_simulator.sh \
               scripts/entrypoint.sh \
    && echo 'source /opt/ros/humble/setup.bash' >> /etc/bash.bashrc

USER ${USERNAME}
WORKDIR /workspace/px4_sitl_docker_sim

RUN echo 'source /opt/ros/humble/setup.bash' >> ~/.bashrc

CMD ["--model", "x500_mono_cam", "--vehicles", "1"]
ENTRYPOINT ["/workspace/px4_sitl_docker_sim/scripts/entrypoint.sh"]
