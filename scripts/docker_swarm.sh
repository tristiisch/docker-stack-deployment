#!/bin/sh
set -eu
. $WORKDIR/scripts/functions.sh

STACK_FINAL_PATH="$INPUT_STACK_FILE_PATH"
DEPLOYMENT_COMMAND_OPTIONS=""

if [ "$INPUT_COPY_STACK_FILE" = "true" ]; then
	STACK_FINAL_PATH="$INPUT_DEPLOY_PATH/$STACK_LOCAL_FILE"
else
	DEPLOYMENT_COMMAND_OPTIONS=" --log-level debug"
fi

DEPLOYMENT_COMMAND="docker$DEPLOYMENT_COMMAND_OPTIONS stack deploy --compose-file $STACK_FINAL_PATH"

if [ -n "$INPUT_DOCKER_PRUNE" ] && [ "$INPUT_DOCKER_PRUNE" = "true" ] ; then
	info "Cleaning up Docker resources with pruning"
	yes | docker --log-level debug system prune -a 2>&1
fi

if [ -z "$INPUT_COPY_STACK_FILE" ] && [ "$INPUT_COPY_STACK_FILE" = "true" ] ; then
	info "Executing command on $DOCKER_USER_HOST"
	info "$ $DEPLOYMENT_COMMAND $INPUT_ARGS"
	$DEPLOYMENT_COMMAND $INPUT_ARGS 2>&1
else
	info "Create a remote folder for the docker-compose file"
	execute_ssh "mkdir -p $INPUT_DEPLOY_PATH/stacks"

	info "Transferring the docker-compose file"
	FILE_NAME="docker-stack-$(date +%Y%m%d%s).yaml"
	copy_ssh "$INPUT_STACK_FILE_PATH" "$INPUT_DEPLOY_PATH/stacks/$FILE_NAME"

	info "Creating symbolic link"
	execute_ssh "ln -nfs $INPUT_DEPLOY_PATH/stacks/$FILE_NAME $INPUT_DEPLOY_PATH/$STACK_LOCAL_FILE"

	info "Cleaning up outdated backup files"
	execute_ssh "ls -t $INPUT_DEPLOY_PATH/stacks/docker-stack-* 2>/dev/null | tail -n +$((INPUT_KEEP_FILES - 1)) | xargs rm --  2>/dev/null || true"

	info "Restarting stack with updated configuration"
	execute_ssh "$DEPLOYMENT_COMMAND $INPUT_ARGS" 2>&1
fi
