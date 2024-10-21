#!/bin/sh
set -eu

KEY_NAME="docker_key"
SSH_FOLDER="$HOME/.ssh"
SSH_CONFIG_PATH="/etc/ssh/ssh_config.d/docker_stack_deployement.conf"
KEY_PATH="$SSH_FOLDER/$KEY_NAME"
KNOWN_HOST_PATH=$SSH_FOLDER/known_hosts
DOCKER_CONTEXT_NAME="docker-remote"

setup_ssh() {
	if [ -e "$KEY_PATH" ]; then
		debug "SSH key setup already completed"
		return 0
	fi
	SSH_HOST=$INPUT_REMOTE_DOCKER_HOST
	SSH_PORT=$INPUT_REMOTE_DOCKER_PORT

	SSH_VERSION=$(ssh -V 2>&1)
	debug "SSH client version : $SSH_VERSION"

	info "Registering SSH key"
	mkdir -p "$SSH_FOLDER"
	chmod 700 "$SSH_FOLDER"
	printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > "$KEY_PATH"
	chmod 600 "$KEY_PATH"

	cat <<EOF >> "$SSH_CONFIG_PATH"
IdentityFile $SSH_FOLDER/$KEY_NAME
UserKnownHostsFile $KNOWN_HOST_PATH
ControlMaster auto
ControlPath $SSH_FOLDER/control-%C
ControlPersist yes
EOF

	STRICT_HOST="no"
	if [ -n "$INPUT_SSH_PUBLIC_KEY" ]; then
		STRICT_HOST="yes"
		if is_debug; then
			SSH_KEY_TYPE=$(echo "$INPUT_SSH_PUBLIC_KEY" | cut -d ' ' -f 1)
			debug "Getting public key $SSH_KEY_TYPE of ssh server $SSH_HOST:$SSH_PORT ..."
			ssh-keyscan -v -t "$SSH_KEY_TYPE" -p "$SSH_PORT" "$SSH_HOST"
		fi

		info "Adding known hosts"
		printf '[%s]:%s %s\n' "$SSH_HOST" "$SSH_PORT" "$INPUT_SSH_PUBLIC_KEY" > "$KNOWN_HOST_PATH"

		KNOWN_HOST=$(cat "$KNOWN_HOST_PATH")
		debug "$KNOWN_HOST_PATH :\\n$KNOWN_HOST"
	fi
	printf 'StrictHostKeyChecking %s\n' $STRICT_HOST >> "$SSH_CONFIG_PATH"
	SSH_CONFIG=$(cat "$SSH_CONFIG_PATH")
	debug "$SSH_CONFIG_PATH :\\n$SSH_CONFIG"
}

setup_remote_docker() {
	if ! docker context inspect "$DOCKER_CONTEXT_NAME" >/dev/null 2>&1; then
		info "Create docker context"
		docker context create "$DOCKER_CONTEXT_NAME" --docker "host=ssh://$DOCKER_USER_HOST:$INPUT_REMOTE_DOCKER_PORT"
	fi

	current_context=$(docker context show)
	info "Current context used is $current_context"
	if [ "$current_context" != "$DOCKER_CONTEXT_NAME" ]; then
		info "Use docker context"
		docker context use $DOCKER_CONTEXT_NAME
	fi
}

execute_ssh(){
	verbose_arg=""
	if is_debug; then
		verbose_arg="-v"
	fi
	debug "Execute Over SSH : $ $*"
	ssh $verbose_arg -p "$INPUT_REMOTE_DOCKER_PORT" "$DOCKER_USER_HOST" "$@" 2>&1
}

copy_ssh(){
	verbose_arg=""
	if is_debug; then
		verbose_arg="-v"
	fi
	local_file="$1"
	remote_file="$2"
	debug "Copy Over SSH : $local_file -> $remote_file"
	scp $verbose_arg -P "$INPUT_REMOTE_DOCKER_PORT" "$local_file" "$DOCKER_USER_HOST:$remote_file" 2>&1
}

is_debug() {
    if { [ -z "${INPUT_DEBUG+set}" ] || [ "$INPUT_DEBUG" != "true" ]; } && { [ -z "${RUNNER_DEBUG+set}" ] || [ "$RUNNER_DEBUG" != "1" ]; }; then
        return 1
    fi
	return 0
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
    printf "${RED}ERROR\t%s${RESET}\n" "$*"
    exit 1
}

warning() {
    printf "${YELLOW}WARNING\t%s${RESET}\n" "$*"
}

info() {
    printf "${CYAN}INFO\t%s${RESET}\n" "$*"
}

debug() {
    if ! is_debug; then
        return
    fi
    printf "${MAGENTA}DEBUG\t%s${RESET}\n" "$*"
}
