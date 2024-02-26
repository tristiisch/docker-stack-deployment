#!/bin/sh
set -eu

setup_ssh() {
	KEY_NAME="docker_key"
	SSH_HOST=${INPUT_REMOTE_DOCKER_HOST#*@}

	echo "Registering SSH keys..."

	# register the private key with the agent.
	mkdir -p "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"

	printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > "$HOME/.ssh/$KEY_NAME"
	chmod 600 "$HOME/.ssh/$KEY_NAME"

	eval $(ssh-agent)
	ssh-add "$HOME/.ssh/$KEY_NAME"

	echo "Add known hosts"
	printf '%s %s\n' "$SSH_HOST" "$INPUT_SSH_PUBLIC_KEY" > $HOME/.ssh/known_hosts
}

execute_ssh(){
	echo "Execute Over SSH (if failed, verify host public key)"
	echo "$ $@"
	ssh -q -t \
		-p $INPUT_REMOTE_DOCKER_PORT \
		-o StrictHostKeyChecking=yes "$INPUT_REMOTE_DOCKER_HOST" "$@" 2>&1
}

copy_ssh(){
	local local_file="$1"
	local remote_file="$2"
	echo "Copy Over SSH (if failed, verify host public key)"
	echo "$ $local_file -> $remote_file"
	scp \
		-o StrictHostKeyChecking=yes \
		-P $INPUT_REMOTE_DOCKER_PORT \
		$local_file "$INPUT_REMOTE_DOCKER_HOST:$remote_file" 2>&1
}
