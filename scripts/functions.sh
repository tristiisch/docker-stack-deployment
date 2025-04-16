#!/bin/sh
set -eu

KEY_NAME="docker_key"
SSH_FOLDER="$HOME/.ssh"
SSH_CONFIG_PATH="/etc/ssh/ssh_config.d/docker_stack_deployement.conf"
KEY_PATH="$SSH_FOLDER/$KEY_NAME"
KNOWN_HOST_PATH=$SSH_FOLDER/known_hosts_$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 15 | head -n 1)
DOCKER_CONTEXT_NAME="docker-remote"

setup_ssh() {
	if [ -e "$KEY_PATH" ]; then
		debug "SSH key setup already completed; it will be overwritten."
	fi
	SSH_HOST=$INPUT_REMOTE_DOCKER_HOST
	SSH_PORT=$INPUT_REMOTE_DOCKER_PORT

	SSH_VERSION=$(ssh -V 2>&1)
	debug "SSH client version : $SSH_VERSION"

	info "Create SSH folder"
	mkdir -p "$SSH_FOLDER"
	chmod 700 "$SSH_FOLDER"
	if is_debug; then
		debug "Checking permissions on SSH folder at $SSH_FOLDER"
		ls -ld "$SSH_FOLDER"
	fi

	info "Registering SSH key"
	printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > "$KEY_PATH"
	chmod 600 "$KEY_PATH"
	if is_debug; then
		debug "Checking permissions on private key at $KEY_PATH"
		ls -l "$KEY_PATH"
	fi

	cat <<EOF > "$SSH_CONFIG_PATH"
	IdentityFile $KEY_PATH
	UserKnownHostsFile $KNOWN_HOST_PATH
	ControlMaster auto
	ControlPath $SSH_FOLDER/control-%C
	ControlPersist yes
EOF

	STRICT_HOST="accept-new"
	if [ -n "$INPUT_SSH_PUBLIC_KEY" ]; then
		STRICT_HOST="yes"
		if is_debug; then
			SSH_KEY_TYPE=$(echo "$INPUT_SSH_PUBLIC_KEY" | cut -d ' ' -f 1)
			debug "Getting public key $SSH_KEY_TYPE of ssh server $SSH_HOST:$SSH_PORT ..."
			ssh-keyscan -v -t "$SSH_KEY_TYPE" -p "$SSH_PORT" "$SSH_HOST"
		fi

		info "Adding known hosts"
		if [ "$SSH_PORT" = "22" ]; then
			printf '%s %s\n' "$SSH_HOST" "$INPUT_SSH_PUBLIC_KEY" > "$KNOWN_HOST_PATH"
		else
			printf '[%s]:%s %s\n' "$SSH_HOST" "$SSH_PORT" "$INPUT_SSH_PUBLIC_KEY" > "$KNOWN_HOST_PATH"
		fi
		chmod 600 "$KNOWN_HOST_PATH"
		if is_debug; then
			debug "Verify permission on known hosts"
			ls -l "$KNOWN_HOST_PATH"
		fi

		if is_debug; then
			debug "SSH known host $KNOWN_HOST_PATH :"
			cat "$KNOWN_HOST_PATH"
		fi
	fi
	printf '	StrictHostKeyChecking %s\n' $STRICT_HOST >> "$SSH_CONFIG_PATH"
	if is_debug; then
		debug "SSH config $SSH_CONFIG_PATH :"
		cat "$SSH_CONFIG_PATH"
	fi

	info "Testing SSH connection ..."
	if is_running_debug; then
		ssh -v -p "$SSH_PORT" "$DOCKER_USER_HOST" exit
	else
		ssh -p "$SSH_PORT" "$DOCKER_USER_HOST" exit
	fi
	info "Done !"
}

setup_remote_docker() {
	SSH_PORT=$INPUT_REMOTE_DOCKER_PORT
	if ! docker context inspect "$DOCKER_CONTEXT_NAME" >/dev/null 2>&1; then
		info "Create docker context"
		debug "Adding context host=ssh://$DOCKER_USER_HOST:$SSH_PORT"
		docker context create "$DOCKER_CONTEXT_NAME" --docker "host=ssh://$DOCKER_USER_HOST:$SSH_PORT"
	fi

	current_context=$(docker context show)
	info "Current context used is $current_context"
	if [ "$current_context" != "$DOCKER_CONTEXT_NAME" ]; then
		info "Use docker context"
		docker context use "$DOCKER_CONTEXT_NAME"
	fi
}

execute_ssh(){
	SSH_PORT=$INPUT_REMOTE_DOCKER_PORT
	verbose_arg=""
	if is_running_debug; then
		verbose_arg="-v"
	fi
	debug "Execute over SSH : $ $*"
	ssh $verbose_arg -p "$SSH_PORT" "$DOCKER_USER_HOST" "$@" 2>&1
}

execute_ssh_raw(){
	SSH_PORT=$INPUT_REMOTE_DOCKER_PORT
	debug "Execute over SSH with raw response : $ $*"
	output=$(ssh -p "$SSH_PORT" "$DOCKER_USER_HOST" "$@")
	debug "Output : $output"
	export EXECUTE_SSH_RAW_OUTPUT="$output"
}

copy_ssh(){
	SSH_PORT=$INPUT_REMOTE_DOCKER_PORT
	verbose_arg=""
	if is_running_debug; then
		verbose_arg="-v"
	fi
	local_file="$1"
	remote_file="$2"
	debug "Copy Over SSH : $local_file -> $remote_file"
	scp $verbose_arg -P "$SSH_PORT" "$local_file" "$DOCKER_USER_HOST:$remote_file" 2>&1
}

is_trace() {
	if [ -z "${INPUT_TRACE+set}" ] || [ "$INPUT_TRACE" != "true" ]; then
		return 1
	fi
	return 0
}

is_debug() {
	if { [ -z "${INPUT_DEBUG+set}" ] || [ "$INPUT_DEBUG" != "true" ]; } && { [ -z "${RUNNER_DEBUG+set}" ] || [ "$RUNNER_DEBUG" != "1" ]; }; then
		return 1
	fi
	return 0
}

is_running_debug() {
	if [ -z "${RUNNER_DEBUG+set}" ] || [ "$RUNNER_DEBUG" != "1" ]; then
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
	printf "${RED}ERROR\t%s${RESET}\n" "$1"
	shift
	while [ "$#" -gt 0 ]; do
		printf "%s\n" "$1"
		shift
	done
	exit 1
}

warning() {
	printf "${YELLOW}WARNING\t%s${RESET}\n" "$1"
	shift
	while [ "$#" -gt 0 ]; do
		printf "%s\n" "$1"
		shift
	done
}

info() {
	printf "${CYAN}INFO\t%s${RESET}\n" "$1"
	shift
	while [ "$#" -gt 0 ]; do
		printf "%s\n" "$1"
		shift
	done
}

debug() {
	if ! is_debug; then
		return
	fi
	printf "${MAGENTA}DEBUG\t%s${RESET}\n" "$1"
	shift
	while [ "$#" -gt 0 ]; do
		printf "%s\n" "$1"
		shift
	done
}
