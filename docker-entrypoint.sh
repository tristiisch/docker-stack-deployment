#!/bin/sh
set -eu

WORKDIR=$(dirname "$(readlink -f "$0")")
export WORKDIR

. $WORKDIR/scripts/functions.sh

if [ -z "$INPUT_REMOTE_DOCKER_PORT" ]; then
	INPUT_REMOTE_DOCKER_PORT=22
fi

if [ -z "$INPUT_REMOTE_DOCKER_HOST" ]; then
	error "Input remote_docker_host is required."
fi

if [ -z "$INPUT_REMOTE_DOCKER_USERNAME" ]; then
	error "Input remote_docker_username is required."
fi

if [ -z "$INPUT_SSH_PRIVATE_KEY" ]; then
	error "Input ssh_private_key is required."
fi

if [ -z "$INPUT_KEEP_FILES" ]; then
	INPUT_KEEP_FILES=4
else
	INPUT_KEEP_FILES=$((INPUT_KEEP_FILES+1))
fi

if [ -z "$INPUT_DEPLOY_PATH" ]; then
	INPUT_DEPLOY_PATH=~/docker-deployment
fi

if [ -z "$INPUT_STACK_FILE_PATH" ]; then
	INPUT_STACK_FILE_PATH=docker-compose.yaml
fi

if [ ! -f "$INPUT_STACK_FILE_PATH" ]; then
	error "Docker compose file \"$INPUT_STACK_FILE_PATH\" didn't exists."
fi

set +e
if ! docker compose -f "$INPUT_STACK_FILE_PATH" config >/dev/null 2>&1; then
	error "Docker compose file \"$INPUT_STACK_FILE_PATH\" syntax is invalid."
fi
set -e

# Copy docker compose file to temp file
TEMP_FILE="$(dirname "$INPUT_STACK_FILE_PATH")/compose-$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 15 | head -n 1).yml"
cp "$INPUT_STACK_FILE_PATH" "$TEMP_FILE"

# Get docker compose file name (without path of folder)
STACK_LOCAL_FILE=$(basename "$INPUT_STACK_FILE_PATH")
export STACK_LOCAL_FILE

# Remplace docker compose file var by temp file
INPUT_STACK_FILE_PATH="$TEMP_FILE"
export INPUT_STACK_FILE_PATH

# Get local path to temp file
STACK_LOCAL_FOLDER=$(dirname "$INPUT_STACK_FILE_PATH")
export STACK_LOCAL_FOLDER

# Create format of user@host for ssh
DOCKER_USER_HOST="$INPUT_REMOTE_DOCKER_USERNAME@$INPUT_REMOTE_DOCKER_HOST"
export DOCKER_USER_HOST

# Create ssh config
setup_ssh
# Create docker remote config
setup_remote_docker

case $INPUT_DEPLOYMENT_MODE in

# Deploy to docker swarm
  docker-swarm)
	if [ -z "$INPUT_STACK_NAME" ]; then
		error "Input input_stack_name is required."
	fi

	# Rotate secret if any
	POST_SCRIPTS_FOLDER=""
	if [ -n "${INPUT_SECRETS+set}" ] && [ -n "$INPUT_SECRETS" ]; then
		POST_SCRIPTS_FOLDER="/opt/scripts/post"
		export POST_SCRIPTS_FOLDER
		"$WORKDIR/scripts/docker_secrets.sh" "$INPUT_STACK_FILE_PATH" "$INPUT_STACK_NAME" "$INPUT_SECRET_PRUNE" $INPUT_SECRETS
	fi

	"$WORKDIR/scripts/docker_swarm.sh"
  ;;

# Deploy to docker compose
  *)
	"$WORKDIR/scripts/docker_compose.sh"
  ;;
esac

# Execute post commands if any
if [ -n "$POST_SCRIPTS_FOLDER" ] && [ -d "$POST_SCRIPTS_FOLDER" ]; then
	find "$POST_SCRIPTS_FOLDER" -type f -executable -exec sh {} \;
fi

# Delete temp file
rm "$INPUT_STACK_FILE_PATH"
