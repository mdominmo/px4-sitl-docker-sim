#!/bin/bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

usage() {
    echo "Usage: $0 [--px4-version VERSION]"
    echo "  --px4-version, -v   PX4-Autopilot git tag/branch to build (default: v1.17.0)"
}

IMAGE_NAME="px4_sitl_docker_sim"
PX4_VERSION="v1.17.0"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --px4-version|-v)
            if [[ -z "$2" ]]; then
                echo "Missing value for --px4-version"
                usage
                exit 1
            fi
            PX4_VERSION="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

docker build \
    --build-arg UID=$(id -u) \
    --build-arg GID=$(id -g) \
    --build-arg PX4_VERSION="$PX4_VERSION" \
    -t "$IMAGE_NAME" \
    ../
