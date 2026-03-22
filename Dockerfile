FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04

ARG UID=1000
ARG GID=1000
ARG USERNAME=dev

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Madrid
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

# ── Timezone ───────────────────────────────────────────────────────────────────
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ── Base system packages ───────────────────────────────────────────────────────
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

# ── Gazebo Harmonic (from osrfoundation) ──────────────────────────────────────
# Installed before ROS2 and PX4 as the single Gazebo source.
# The project uses SDF 1.10 + gz-transport13, both specific to Gazebo Harmonic.
# ubuntu.sh will later run with --no-sim-tools so it does not touch Gazebo.
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

# ── ROS2 Humble ────────────────────────────────────────────────────────────────
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

# ── User setup ─────────────────────────────────────────────────────────────────
RUN groupadd -g ${GID} ${USERNAME} \
    && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME} \
    && usermod -aG video ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ── PX4-Autopilot ──────────────────────────────────────────────────────────────
WORKDIR /workspace/px4_sitl_docker_sim

RUN git clone \
        --branch v1.15.4 \
        --depth 1 \
        --recurse-submodules \
        https://github.com/PX4/PX4-Autopilot.git

# --no-nuttx     : skip embedded ARM toolchain, not needed for SITL
# --no-sim-tools : skip Gazebo — already installed above as gz-harmonic
RUN PX4-Autopilot/Tools/setup/ubuntu.sh --no-nuttx --no-sim-tools \
    && rm -rf /var/lib/apt/lists/*

# CMake will detect gz-transport13 (Harmonic) and build accordingly
RUN cd PX4-Autopilot && make px4_sitl -j"$(nproc)"

# ── Micro-XRCE-DDS-Agent ──────────────────────────────────────────────────────
# Bridges PX4 uXRCE-DDS with ROS2. Binary installed to /usr/local/bin.
RUN git clone \
        --branch v3.0.1 \
        --depth 1 \
        https://github.com/eProsima/Micro-XRCE-DDS-Agent.git \
        /tmp/Micro-XRCE-DDS-Agent \
    && cd /tmp/Micro-XRCE-DDS-Agent \
    && mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig /usr/local/lib/ \
    && rm -rf /tmp/Micro-XRCE-DDS-Agent

# ── Copy project files ─────────────────────────────────────────────────────────
# PX4-Autopilot, Micro-XRCE-DDS-Agent and gz_assets/ are excluded via .dockerignore
COPY . /workspace/px4_sitl_docker_sim/

# ── Permissions & ROS2 sourcing ────────────────────────────────────────────────
RUN chown -R ${USERNAME}:${USERNAME} /workspace \
    && chmod +x scripts/launch_simulator.sh \
               scripts/entrypoint.sh \
    && echo 'source /opt/ros/humble/setup.bash' >> /etc/bash.bashrc

USER ${USERNAME}
WORKDIR /workspace/px4_sitl_docker_sim

RUN echo 'source /opt/ros/humble/setup.bash' >> ~/.bashrc

# Default: x500_mono_cam, 1 vehicle in testbed world. Override with: docker run ... px4_sitl_docker_sim --model x500|x500_mono_cam|rc_cessna --vehicles N --world WORLD
CMD ["--model", "x500_mono_cam", "--vehicles", "1"]
ENTRYPOINT ["/workspace/px4_sitl_docker_sim/scripts/entrypoint.sh"]
