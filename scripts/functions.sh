#!/bin/sh
set -eu

KEY_NAME="docker_key"
KEY_PATH="$HOME/.ssh/$KEY_NAME"
STRICT_HOST="yes"
KNOWN_HOST_PATH=$HOME/.ssh/known_hosts

setup_ssh() {
	SSH_HOST=${INPUT_REMOTE_DOCKER_HOST#*@}
	SSH_KEY_TYPE=$(echo $INPUT_SSH_PUBLIC_KEY | cut -d ' ' -f 1)

	SSH_VERSION=$(ssh -V 2>&1)
	debug "SSH client version : $SSH_VERSION"

	info "Registering SSH key"
	mkdir -p "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"
	printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > $KEY_PATH
	chmod 600 $KEY_PATH

	if [ "$INPUT_DEBUG" = "true" ]; then
		SERVER_PUBLIC_KEY=$(ssh-keyscan -t $SSH_KEY_TYPE $SSH_HOST 2>&1)
		debug "Actual public key of ssh server $SSH_KEY_TYPE :\n$SERVER_PUBLIC_KEY"
	fi

	info "Adding known hosts"
	printf '%s %s\n' "$SSH_HOST" "$INPUT_SSH_PUBLIC_KEY" > $KNOWN_HOST_PATH

	KNOWN_HOST=$(cat $KNOWN_HOST_PATH)
	debug "$KNOWN_HOST"
}

execute_ssh(){
	debug "Execute Over SSH : $ $@"
	ssh -i $KEY_PATH \
		-o UserKnownHostsFile=$KNOWN_HOST_PATH \
		-o StrictHostKeyChecking=$STRICT_HOST \
		-p $INPUT_REMOTE_DOCKER_PORT \
		"$INPUT_REMOTE_DOCKER_HOST" "$@"
}

copy_ssh(){
	local local_file="$1"
	local remote_file="$2"
	debug "Copy Over SSH : $local_file -> $remote_file"
	scp -i $KEY_PATH \
		-o UserKnownHostsFile=$KNOWN_HOST_PATH \
		-o StrictHostKeyChecking=$STRICT_HOST \
		-P $INPUT_REMOTE_DOCKER_PORT \
		$local_file "$INPUT_REMOTE_DOCKER_HOST:$remote_file"
}

# Define color variables
BLACK='\e[0;30m'
RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
BLUE='\e[0;34m'
MAGENTA='\e[0;35m'
CYAN='\e[0;36m'
WHITE='\e[0;37m'
RESET='\e[0m'

error() {
    echo -e "${RED}ERROR\t$1${RESET}" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}WARNING\t$1${RESET}"
}

info() {
    echo -e "${CYAN}INFO\t$1${RESET}"
}

debug() {
	if [ "$INPUT_DEBUG" != "true" ]; then
		return
	fi
    echo -e "${MAGENTA}DEBUG\t$1${RESET}"
}
