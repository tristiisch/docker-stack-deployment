#!/bin/sh
set -eu

KEY_NAME="docker_key"
KEY_PATH="$HOME/.ssh/$KEY_NAME"

setup_ssh() {
	SSH_HOST=${INPUT_REMOTE_DOCKER_HOST#*@}

	echo "Registering SSH keys..."

	# register the private key with the agent.
	mkdir -p "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"

	printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > $KEY_PATH
	chmod 600 $KEY_PATH

	echo "Add known hosts"
	printf '%s %s\n' "$SSH_HOST" "$INPUT_SSH_PUBLIC_KEY" > $HOME/.ssh/known_hosts
}

execute_ssh(){
	echo "Execute Over SSH (if failed, verify host public key)"
	echo "$ $@"
	ssh -q -t \
		-i $KEY_PATH \
		-p $INPUT_REMOTE_DOCKER_PORT \
		-o StrictHostKeyChecking=yes \
		"$INPUT_REMOTE_DOCKER_HOST" "$@"
}

copy_ssh(){
	local local_file="$1"
	local remote_file="$2"
	echo "Copy Over SSH (if failed, verify host public key)"
	echo "$ $local_file -> $remote_file"
	scp -o StrictHostKeyChecking=yes \
		-i $KEY_PATH \
		-P $INPUT_REMOTE_DOCKER_PORT \
		$local_file "$INPUT_REMOTE_DOCKER_HOST:$remote_file"
}
