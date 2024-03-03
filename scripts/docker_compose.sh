#!/bin/sh
set -eu
source /app/scripts/functions.sh

STACK_FILE=${INPUT_STACK_FILE_PATH}
DEPLOYMENT_COMMAND_OPTIONS=""


if [ "$INPUT_COPY_STACK_FILE" = "true" ]; then
	STACK_FILE="$INPUT_DEPLOY_PATH/$STACK_FILE"
else
	DEPLOYMENT_COMMAND_OPTIONS=" --log-level debug"
fi

DEPLOYMENT_COMMAND="docker-compose$DEPLOYMENT_COMMAND_OPTIONS -f $STACK_FILE"

if ! [ -z "$INPUT_DOCKER_PRUNE" ] && [ "$INPUT_DOCKER_PRUNE" = "true" ] ; then
	info "Cleaning up Docker resources with pruning"
	yes | docker --log-level debug system prune -a 2>&1
fi

if [ -z "$INPUT_COPY_STACK_FILE" ] && [ "$INPUT_COPY_STACK_FILE" = "true" ] ; then
	info "Executing command on $INPUT_REMOTE_DOCKER_HOST"
	info "$ $DEPLOYMENT_COMMAND $INPUT_ARGS"
	$DEPLOYMENT_COMMAND "$INPUT_ARGS" 2>&1
else
	info "Create remote folder for docker compose file"
	execute_ssh "mkdir -p $INPUT_DEPLOY_PATH/stacks"
	
	info "Copy docker compose file"
	FILE_NAME="docker-stack-$(date +%Y%m%d%s).yaml"
	copy_ssh "$INPUT_STACK_FILE_PATH" "$INPUT_DEPLOY_PATH/stacks/$FILE_NAME"

	info "Creating symbolic link"
	execute_ssh "ln -nfs $INPUT_DEPLOY_PATH/stacks/$FILE_NAME $INPUT_DEPLOY_PATH/$INPUT_STACK_FILE_PATH"

	info "Removing outdated backup files"
	execute_ssh "ls -t $INPUT_DEPLOY_PATH/stacks/docker-stack-* 2>/dev/null | tail -n +$INPUT_KEEP_FILES | xargs rm --  2>/dev/null || true"

	if ! [ -z "$INPUT_PULL_IMAGES_FIRST" ] && [ "$INPUT_PULL_IMAGES_FIRST" = 'true' ] ; then
		info "Pulling the latest Docker image"
		execute_ssh "$DEPLOYMENT_COMMAND" "pull"
	fi

	if ! [ -z "$INPUT_PRE_DEPLOYMENT_COMMAND_ARGS" ]; then
		info "Executing pre-commands"
		execute_ssh "$DEPLOYMENT_COMMAND $INPUT_PRE_DEPLOYMENT_COMMAND_ARGS" 2>&1
	fi

	info "Restarting stack with updated configuration"
	execute_ssh "$DEPLOYMENT_COMMAND $INPUT_ARGS" 2>&1
fi
