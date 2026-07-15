# PX4 SITL Docker Sim
![GitHub tag](https://img.shields.io/github/v/tag/mdominmo/px4-sitl-docker-sim)
![GitHub](https://img.shields.io/github/license/mdominmo/px4-sitl-docker-sim)

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

1. Extract `gz_assets.zip` before building the Docker image:

```bash
unzip -o gz_assets.zip
```

2. Build the Docker image:

```bash
./scripts/build_docker.sh
```

To build against a different PX4-Autopilot version (default: `v1.17.0`):

```bash
./scripts/build_docker.sh --px4-version v1.16.0
```

3. Run the simulator (default: `x500_mono_cam`, 1 vehicle, `testbed` world):

```bash
./scripts/run_docker.sh
```

4. Run with custom options:

```bash
./scripts/run_docker.sh --model x500 --vehicles 2 --world testbed
```

## Runtime Options

- `--model` or `-m`: `x500` | `x500_mono_cam` | `rc_cessna`
- `--vehicles` or `-n`: number of vehicles to spawn
- `--world` or `-w`: world name from `gz_assets/worlds` (with or without `.sdf`)
- Default world: `testbed`
- If the selected world does not exist in `gz_assets/worlds` or any `--extra-assets` path, the launcher returns an error with available world names
- `run_docker.sh --detach --name <container_name>`: run the container in the background under a fixed name instead of interactively, for callers that need to start/stop/inspect it programmatically (e.g. alongside a second, dependent container)

## Custom Models And Worlds

For your own local, one-off assets: add models in
`gz_assets/models/<your_model_name>/...` and worlds in
`gz_assets/worlds/<your_world_name>.sdf` (mounted as volumes by
`run_docker.sh`, no rebuild needed), then run:

```bash
./scripts/run_docker.sh --world <your_world_name>
```

For a tool/project built on top of this simulator: don't copy files into
`gz_assets/` — pass your own asset directories in instead, so this repo's
own `gz_assets/` stays generic:

```bash
./scripts/run_docker.sh --world <your_world_name> \
    --extra-assets /path/to/your/models \
    --extra-assets /path/to/your/generated/worlds
```

`--extra-assets <dir>` (repeatable) mounts `<dir>` read-only into the
container and adds it to Gazebo's `GZ_SIM_RESOURCE_PATH`, so both models and
world files inside it are found the same way as `gz_assets/models`/
`gz_assets/worlds` - without ever touching this repo's own files.
