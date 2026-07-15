#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="px4_sitl_docker_sim"

EXTRA_MOUNT_ARGS=()
CONTAINER_EXTRA_PATHS=()
FORWARD_ARGS=()
RUN_MODE_ARGS=(-it --rm)
extra_idx=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --extra-assets)
            if [[ -z "$2" ]]; then
                echo "Missing value for --extra-assets"
                exit 1
            fi
            host_dir="$(cd "$2" && pwd)"
            container_dir="/workspace/extra_assets/${extra_idx}"
            EXTRA_MOUNT_ARGS+=(-v "${host_dir}:${container_dir}:ro")
            CONTAINER_EXTRA_PATHS+=("$container_dir")
            extra_idx=$((extra_idx + 1))
            shift 2
            ;;
        --detach|-d)
            RUN_MODE_ARGS=(-d)
            shift
            ;;
        --name)
            if [[ -z "$2" ]]; then
                echo "Missing value for --name"
                exit 1
            fi
            RUN_MODE_ARGS+=(--name "$2")
            shift 2
            ;;
        *)
            FORWARD_ARGS+=("$1")
            shift
            ;;
    esac
done

EXTRA_ASSET_PATHS=""
if (( ${#CONTAINER_EXTRA_PATHS[@]} > 0 )); then
    EXTRA_ASSET_PATHS="$(IFS=':'; echo "${CONTAINER_EXTRA_PATHS[*]}")"
fi

# GZ_IP/GZ_PARTITION are optional Gazebo transport settings a caller may
# need to coordinate this simulator with a separate bridge/client container
# (e.g. obstacle_avoidance_sim's ROS2 bridge) - passed through only if set
# in the calling shell's environment, so the plain standalone case is
# unaffected.
GZ_ENV_ARGS=()
[[ -n "${GZ_IP:-}" ]] && GZ_ENV_ARGS+=(-e GZ_IP)
[[ -n "${GZ_PARTITION:-}" ]] && GZ_ENV_ARGS+=(-e GZ_PARTITION)

xhost +local:docker

docker run "${RUN_MODE_ARGS[@]}" \
    --network host \
    --ipc=host \
    --gpus all \
    -e DISPLAY=$DISPLAY \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -e __NV_PRIME_RENDER_OFFLOAD=1 \
    -e __GLX_VENDOR_LIBRARY_NAME=nvidia \
    -e EXTRA_ASSET_PATHS="$EXTRA_ASSET_PATHS" \
    "${GZ_ENV_ARGS[@]}" \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v "$HOME/.Xauthority:/home/dev/.Xauthority:ro" \
    -v "$REPO_ROOT/gz_assets/models:/workspace/px4_sitl_docker_sim/gz_assets/models" \
    -v "$REPO_ROOT/gz_assets/worlds:/workspace/px4_sitl_docker_sim/gz_assets/worlds" \
    "${EXTRA_MOUNT_ARGS[@]}" \
    "$IMAGE_NAME" "${FORWARD_ARGS[@]}"
