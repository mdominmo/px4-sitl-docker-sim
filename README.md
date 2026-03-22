# PX4 SITL Docker Sim

![Version](https://img.shields.io/github/v/release/mdominmo/px4-sitl-docker-sim?style=flat-square) ![License](https://img.shields.io/badge/license-Apache%202.0-3fb950?style=flat-square)

Built for fast robotics development, the simulator connects seamlessly through `px4_msgs` (uXRCE-DDS), MAVROS, and MAVSDK.

`px4-sitl-docker-sim` is a tool to run PX4 SITL with Gazebo Harmonic through Docker, using the NVIDIA Container Toolkit to take advantage of NVIDIA GPU acceleration.

The main strength of this project is that developers do not need to manage the manual installation of PX4 SITL and all its dependencies on the host machine.

## What You Get

- PX4 Autopilot SITL environment inside Docker
- Gazebo Harmonic preinstalled and ready to use
- ROS 2 Humble available in the container
- Micro XRCE-DDS Agent included
- GPU rendering support with NVIDIA

## Requirements

- Linux with Docker installed
- NVIDIA GPU + NVIDIA drivers
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- X11 access for GUI simulation

## Quick Start

1. Build the Docker image:

```bash
./scripts/build_docker.sh
```

2. Run the simulator (default: `x500_mono_cam`, 1 vehicle, `testbed` world):

```bash
./scripts/run_docker.sh
```

3. Run with custom options:

```bash
./scripts/run_docker.sh --model x500 --vehicles 2 --world testbed
```

## Runtime Options

- `--model` or `-m`: `x500` | `x500_mono_cam` | `rc_cessna`
- `--vehicles` or `-n`: number of vehicles to spawn
- `--world` or `-w`: world name from `gz_assets/worlds` (with or without `.sdf`)
- Default world: `testbed`
- If the selected world does not exist in `gz_assets/worlds`, the launcher returns an error with available world names

## Custom Models And Worlds

You can add your own assets without changing the scripts:

- Add new models in `gz_assets/models/<your_model_name>/...`
- Add new worlds in `gz_assets/worlds/<your_world_name>.sdf`

Then run the simulator using the new world:

```bash
./scripts/run_docker.sh --world <your_world_name>
```

`run_docker.sh` mounts `gz_assets/models` and `gz_assets/worlds` as volumes, so your local assets are used directly by Gazebo.
