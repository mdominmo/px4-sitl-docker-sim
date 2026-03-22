#!/bin/bash
set -e

source /opt/ros/humble/setup.bash

exec /workspace/px4_sitl_docker_sim/scripts/launch_simulator.sh "$@"
