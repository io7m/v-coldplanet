#!/usr/bin/env bash

FRAME_COUNT=12600
RENDER_HOST="jenkins-renders@mustard.int.arc7.info"
RENDER_BASE_DIRECTORY="/shared/jenkins-renders/"

set -o pipefail

fatal()
{
  echo "fatal: $1" 1>&2
  exit 1
}

info()
{
  echo "info: $1" 1>&2
}

if [ $# -ne 2 ]
then
  fatal "usage: node-index node-count"
fi

NODE_INDEX="$1"
shift
NODE_COUNT="$1"
shift

if [ -z "${NODE_INDEX}" ]
then
  fatal "node index must be non-empty string"
fi
if [ -z "${NODE_COUNT}" ]
then
  fatal "node count must be non-empty string"
fi
if [ -z "${NODE_NAME}" ]
then
  NODE_NAME=$(hostname -s) || fatal "could not get hostname"
fi

info "node index ${NODE_INDEX}"
info "node count ${NODE_COUNT}"
info "node name  ${NODE_NAME}"

if [ -z "${WORKSPACE}" ]
then
  WORKSPACE=.
fi
if [ -z "${BUILD_ID}" ]
then
  BUILD_ID=0
fi

TIME_START=$(date "+%Y-%m-%dT%H:%M:%S")
OUTPUT="${WORKSPACE}/renders/${BUILD_ID}/"
LOG_FILE="${OUTPUT}/${NODE_NAME}-"$(date "+%Y%m%dT%H%M%S.log")

mkdir -p "${OUTPUT}" || fatal "mkdir failed"

(
env | sort
echo

cat <<EOF
Rendering started ${TIME_START}
------------------------------------------------------------------------
EOF
) | tee -a "${LOG_FILE}"

time blender \
  --background \
  master.blend \
  --scene Scene \
  --render-output "${OUTPUT}/########.png" \
  --render-format PNG \
  --frame-start "${NODE_INDEX}" \
  --frame-end "${FRAME_COUNT}" \
  --frame-jump "${NODE_COUNT}" \
  --render-anim 2>&1 | tee -a "${LOG_FILE}" || fatal "Blender failed!"

(
cat <<EOF
------------------------------------------------------------------------
Rendering finished ${TIME_END}
EOF
) | tee -a "${LOG_FILE}"

echo "Time: ${DIFF}"

RENDER_DIRECTORY="${RENDER_BASE_DIRECTORY}/${JOB_BASE_NAME}/${BUILD_ID}/"
RENDER_TARGET="${RENDER_HOST}:${RENDER_DIRECTORY}"

ssh "${RENDER_HOST}" "mkdir -p ${RENDER_DIRECTORY}" || fatal "ssh failed"

exec rsync -avz --progress "${OUTPUT}/" "${RENDER_TARGET}"
