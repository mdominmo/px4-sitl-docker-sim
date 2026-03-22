#!/bin/bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

PIDS=()
SIM_STARTED=false

handle_exit() {
    if ! $SIM_STARTED; then
        return 0
    fi

    echo "Exiting simulation."
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid"
        fi
    done

    pkill -9 MicroXRCEAgent 2>/dev/null || true
}

trap handle_exit EXIT

usage() {
    echo "Usage: $0 [--model MODEL] [--vehicles N] [--world WORLD]"
    echo "Allowed models: x500, x500_mono_cam, rc_cessna"
    echo "WORLD can be provided with or without the .sdf extension"
}

run_cmd() {
    local cmd="$1"
    (eval "$cmd > /dev/null 2>&1" &)
    PIDS+=("$!")
}

MODEL="x500_mono_cam"
NUM_VEHICLES=1
WORLD="testbed"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model|-m)
            if [[ -z "$2" ]]; then
                echo "Missing value for --model"
                usage
                exit 1
            fi
            MODEL="$2"
            shift 2
            ;;
        --vehicles|-n)
            if [[ -z "$2" || ! "$2" =~ ^[1-9][0-9]*$ ]]; then
                echo "Invalid value for --vehicles: '$2'. Use a positive integer."
                usage
                exit 1
            fi
            NUM_VEHICLES="$2"
            shift 2
            ;;
        --world|-w)
            if [[ -z "$2" ]]; then
                echo "Missing value for --world"
                usage
                exit 1
            fi
            WORLD="$2"
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

if [[ "$WORLD" == *.sdf ]]; then
    WORLD="${WORLD%.sdf}"
fi

if [[ "$WORLD" == *"/"* ]]; then
    echo "Invalid world '$WORLD'. Use only the world name, not a path."
    usage
    exit 1
fi

case "$MODEL" in
    x500)
        SYS_AUTOSTART=4001
        ;;
    x500_mono_cam)
        SYS_AUTOSTART=4010
        ;;
    rc_cessna)
        SYS_AUTOSTART=4003
        ;;
    *)
        echo "Unknown model: $MODEL"
        usage
        exit 1
        ;;
esac

PX4_FOLDER="$(pwd)/../PX4-Autopilot"
WORLD_FILE="$(pwd)/../gz_assets/worlds/${WORLD}.sdf"

if [[ ! -f "$WORLD_FILE" ]]; then
    echo "World not found: $WORLD"
    echo "Expected file: $WORLD_FILE"
    echo "Available worlds:"
    shopt -s nullglob
    world_files=("$(pwd)/../gz_assets/worlds/"*.sdf)
    if (( ${#world_files[@]} == 0 )); then
        echo "  (none found in gz_assets/worlds)"
    else
        for file in "${world_files[@]}"; do
            echo "  - $(basename "$file" .sdf)"
        done
    fi
    shopt -u nullglob
    exit 1
fi

echo "Setting up the simulation environment..."
echo "  Model       : $MODEL (autostart $SYS_AUTOSTART)"
echo "  Vehicles    : $NUM_VEHICLES"
echo "  World       : $WORLD"

export PX4_GZ_WORLD="$WORLD"
export GZ_SIM_RESOURCE_PATH="$(pwd)/../gz_assets/models/:$(pwd)/../gz_assets/worlds/"

echo "starting gz server..."
SIM_STARTED=true
run_cmd "gz sim -r ${PX4_GZ_WORLD}.sdf"
sleep 10

y_0="0"
for ((vehicle=1; vehicle<=NUM_VEHICLES; vehicle++)); do
    export PX4_SIM_MODEL="$MODEL"
    export PX4_SYS_AUTOSTART=$SYS_AUTOSTART

    y_n=$((y_0 - (vehicle - 1) * 2))
    export PX4_UXRCE_DDS_NS="px4_${vehicle}"
    export PX4_GZ_MODEL_POSE="0,${y_n},3,0,0,0"

    run_cmd "${PX4_FOLDER}/build/px4_sitl_default/bin/px4 -i $vehicle"
    sleep 5
done

run_cmd "MicroXRCEAgent udp4 -p 8888"
sleep 8

echo "Simulation started."
while true; do
    sleep 5
done
