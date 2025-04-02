#!/bin/sh
set -eu
. $WORKDIR/scripts/functions.sh

DOCKER_OPTIONS=" --log-level debug"

DEPLOYMENT_COMMAND="docker$DOCKER_OPTIONS stack deploy"

if [ -n "$INPUT_DOCKER_REMOVE_ORPHANS" ] && [ "$INPUT_DOCKER_REMOVE_ORPHANS" = "true" ] ; then
	DEPLOYMENT_COMMAND="$DEPLOYMENT_COMMAND --prune"
fi
if [ "$INPUT_COPY_STACK_FILE" = "true" ] ; then
	info "Checking remote docker version"
	execute_ssh_raw "docker --version"
	docker_version=$(echo "$EXECUTE_SSH_RAW_OUTPUT" | cut -d ' ' -f 3 | cut -d '.' -f 1)
	info "Docker version is $docker_version"
	if [ "$docker_version" -ge 26 ]; then
		if [ "$INPUT_DEPLOY_FOREGROUND" = "true" ] ; then
			DEPLOYMENT_COMMAND="$DEPLOYMENT_COMMAND --detach=false"
		elif [ "$INPUT_DEPLOY_FOREGROUND" = "false" ] ; then
			DEPLOYMENT_COMMAND="$DEPLOYMENT_COMMAND --detach=true"
		fi
	elif [ "$INPUT_DEPLOY_FOREGROUND" = "true" ]; then
		warning "Cannot deploy in foreground, it require Docker version 26, but you use Docker version $docker_version"
	fi
fi

if [ -n "$INPUT_DOCKER_PRUNE" ] && [ "$INPUT_DOCKER_PRUNE" = "true" ] ; then
	info "Cleaning up Docker resources with pruning"
	yes | docker "$DOCKER_OPTIONS" system prune -a 2>&1
fi

if [ "$INPUT_COPY_STACK_FILE" = "true" ] ; then
	STACK_FINAL_PATH="$INPUT_DEPLOY_PATH/$STACK_LOCAL_FILE"
	DEPLOYMENT_COMMAND="$DEPLOYMENT_COMMAND -c \"$STACK_FINAL_PATH\""

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
	execute_ssh "$DEPLOYMENT_COMMAND $INPUT_STACK_NAME $INPUT_ARGS" 2>&1

else
	DEPLOYMENT_COMMAND="$DEPLOYMENT_COMMAND -c \"$INPUT_STACK_FILE_PATH\""

	info "Executing command on $DOCKER_USER_HOST"
	info "$ $DEPLOYMENT_COMMAND \"$INPUT_STACK_NAME\" $INPUT_ARGS"
	$DEPLOYMENT_COMMAND "$INPUT_STACK_NAME" $INPUT_ARGS
fi
