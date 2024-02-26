#!/bin/sh
set -eu
source /app/scripts/functions.sh

if [ -z "$INPUT_REMOTE_DOCKER_PORT" ]; then
	INPUT_REMOTE_DOCKER_PORT=22
fi

if [ -z "$INPUT_REMOTE_DOCKER_HOST" ]; then
	echo "Input remote_docker_host is required!"
	exit 1
fi

if [ -z "$INPUT_SSH_PUBLIC_KEY" ]; then
	echo "Input ssh_public_key is required!"
	exit 1
fi

if [ -z "$INPUT_SSH_PRIVATE_KEY" ]; then
	echo "Input ssh_private_key is required!"
	exit 1
fi

if [ -z "$INPUT_ARGS" ]; then
	echo "Input input_args is required!"
	exit 1
fi

if [ -z "$INPUT_DEPLOY_PATH" ]; then
	INPUT_DEPLOY_PATH=~/docker-deployment
fi

if [ -z "$INPUT_STACK_FILE_NAME" ]; then
	INPUT_STACK_FILE_NAME=docker-compose.yaml
fi

if [ -z "$INPUT_KEEP_FILES" ]; then
	INPUT_KEEP_FILES=4
else
	INPUT_KEEP_FILES=$((INPUT_KEEP_FILES+1))
fi

setup_ssh

case $INPUT_DEPLOYMENT_MODE in

  docker-swarm)
	/app/scripts/docker_swarm.sh
  ;;

  *)
	/app/scripts/docker_compose.sh
  ;;
esac
