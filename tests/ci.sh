#!/bin/bash
set -eu

check_memory_usage() {
  dirName=/sys/fs/cgroup/memory/docker/$1
  # /sys/fs/cgroup/memory/actions_job/${containerID}
  set +x
  while [ -d $dirName ] ; do
    awk '/(^cache |^rss |^shmem )/' $dirName/memory.stat | cut -f2 -d' ' | paste -s -d,
    sleep 1
  done
  set -x
}

IMG_NAME=ci-test-weather
BUILD="false"
RUN="false"
TEST_NAME=""
BUILD_CASE=""
TEST_CASE=""

while getopts :b:r:n: opt; do
  case $opt in
    b)
      BUILD="true"
      BUILD_CASE=$OPTARG
      ;;
    r)
      RUN="true"
      TEST_CASE=$OPTARG
      ;;
    n)
      TEST_NAME=$OPTARG
      ;;
  esac
done

# Read in TEST_NAME if not passed on
TEST_NAME=${TEST_NAME:-$(sed -n 1p ci.test)}

if [ $BUILD = "true" ] && [ $RUN = "true" ]; then
  echo "Specify either build (-b) or run (-r) option, not both"
  exit 2
fi

if [ $BUILD = "false" ] && [ $RUN = "false" ]; then
  echo "Specify either build (-b) or run (-r) option"
  exit 2
fi

if [ $BUILD = "true" ]; then
  sed -i -e '/affinity.c/d' ../CMakeLists.txt

  sudo docker build --build-arg test_name=$TEST_NAME \
                    --build-arg build_case=$BUILD_CASE \
                    --no-cache \
                    --squash --compress \
                    -f ../Dockerfile -t ${IMG_NAME} ..
  exit $?

elif [ $RUN == "true" ]; then
  sudo docker run -e test_case=${TEST_CASE} -d ${IMG_NAME}
  echo 'cache,rss,shmem' >memory_stat
  sleep 3
  containerID=$(sudo docker ps -q --no-trunc)
  check_memory_usage $containerID >>memory_stat &
  sudo docker logs -f $containerID
  exit $(sudo docker inspect $containerID --format='{{.State.ExitCode}}')

fi
