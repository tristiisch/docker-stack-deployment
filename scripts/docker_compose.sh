#!/bin/sh
set -eu
source /app/scripts/functions.sh

STACK_FILE=${INPUT_STACK_FILE_NAME}
DEPLOYMENT_COMMAND_OPTIONS=""


if [ "$INPUT_COPY_STACK_FILE" = "true" ]; then
	STACK_FILE="$INPUT_DEPLOY_PATH/$STACK_FILE"
else
	DEPLOYMENT_COMMAND_OPTIONS=" --log-level debug --host ssh://$INPUT_REMOTE_DOCKER_HOST:$INPUT_REMOTE_DOCKER_PORT"
fi

DEPLOYMENT_COMMAND="docker-compose$DEPLOYMENT_COMMAND_OPTIONS -f $STACK_FILE"

if ! [ -z "$INPUT_DOCKER_PRUNE" ] && [ $INPUT_DOCKER_PRUNE = 'true' ] ; then
	yes | docker --log-level debug --host "ssh://$INPUT_REMOTE_DOCKER_HOST:$INPUT_REMOTE_DOCKER_PORT" system prune -a 2>&1
fi

if [ -z "$INPUT_COPY_STACK_FILE" ] && [ $INPUT_COPY_STACK_FILE = 'true' ] ; then
	echo "Connecting to $INPUT_REMOTE_DOCKER_HOST... Command: ${DEPLOYMENT_COMMAND} ${INPUT_ARGS}"
	${DEPLOYMENT_COMMAND} ${INPUT_ARGS} 2>&1
else
	execute_ssh "mkdir -p $INPUT_DEPLOY_PATH/stacks"

	FILE_NAME="docker-stack-$(date +%Y%m%d%s).yaml"

	copy_ssh $INPUT_STACK_FILE_NAME "$INPUT_DEPLOY_PATH/stacks/$FILE_NAME"

	execute_ssh "ln -nfs $INPUT_DEPLOY_PATH/stacks/$FILE_NAME $INPUT_DEPLOY_PATH/$INPUT_STACK_FILE_NAME"
	execute_ssh "ls -t $INPUT_DEPLOY_PATH/stacks/docker-stack-* 2>/dev/null | tail -n +$INPUT_KEEP_FILES | xargs rm --  2>/dev/null || true"

	if ! [ -z "$INPUT_PULL_IMAGES_FIRST" ] && [ $INPUT_PULL_IMAGES_FIRST = 'true' ] ; then
		execute_ssh ${DEPLOYMENT_COMMAND} "pull"
	fi

	if ! [ -z "$INPUT_PRE_DEPLOYMENT_COMMAND_ARGS" ]; then
		execute_ssh "${DEPLOYMENT_COMMAND} $INPUT_PRE_DEPLOYMENT_COMMAND_ARGS" 2>&1
	fi

	execute_ssh ${DEPLOYMENT_COMMAND} "$INPUT_ARGS" 2>&1
fi
