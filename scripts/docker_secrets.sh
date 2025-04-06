#!/bin/sh
set -eu
. $WORKDIR/scripts/functions.sh

get_service_secrets() {
	service_name=$1

	return_secrets=""
	# secrets=$(docker service inspect --format '{{ range .Spec.TaskTemplate.ContainerSpec.Secrets }}{{ .SecretName }} {{ end }}' "$service_name")
	# TODO: verify if secret ID works
	secrets=$(docker service inspect --format '{{ range .Spec.TaskTemplate.ContainerSpec.Secrets }}{{ .SecretID }} {{ end }}' "$service_name") 
	for secret in $secrets; do
		return_secrets="$return_secrets$secret "
	done
	echo "${return_secrets%" "}"
}

calculate_hash() {
	printf "%s" "$1" | sha512sum | cut -d ' ' -f1
}

format_secret_input() {
	secret_values="$1"
	IFS=';'
	dotenv_secret=""
	for pair in $secret_values; do
		key=$(echo "${pair%:*}" | tr '[:lower:]' '[:upper:]')
		value="${pair#*:}"
		dotenv_secret="$dotenv_secret$key=$value\n"
	done
	printf '%s' "$dotenv_secret"
}

# Check if the secrets have been configured by this script
is_secret_exists() {
	old_service_secrets="$1"
	secret_label_hash_name="$2"

	for secret in $old_service_secrets; do
		old_hash=$(docker secret inspect "$secret" --format="{{index .Spec.Labels \"$secret_label_hash_name\"}}")
		if [ -n "$old_hash" ]; then
			return 0
		fi
	done
	return 1
}

get_secrets_with_name() {
	old_service_secrets="$1"
	secret_label_name="$2"
	name_to_retrieve="$3"
	secrets_with_name=""
	new_line=$(printf '\n')

	for secret in $old_service_secrets; do
		old_hash=$(docker secret inspect "$secret" --format="{{index .Spec.Labels \"$secret_label_name\"}}")
		if [ -n "$old_hash" ] && printf "%s" "$old_hash" | grep -q "$new_line" && [ "$old_hash" = "$name_to_retrieve" ]; then
			secrets_with_name="$secrets_with_name$secret "
		fi
	done
	echo "$secrets_with_name"
}

get_secrets_obsolete() {
	old_service_secrets="$1"
	secret_label_hash_name="$2"
	dotenv_secret_hash="$3"
	secret_obsolete=""
	new_line=$(printf '\n')

	for secret in $old_service_secrets; do
		old_hash=$(docker secret inspect "$secret" --format="{{index .Spec.Labels \"$secret_label_hash_name\"}}")
		if [ -n "$old_hash" ] && printf "%s" "$old_hash" | grep -q "$new_line" && [ "$old_hash" != "$dotenv_secret_hash" ]; then
			secret_obsolete="$secret_obsolete$secret "
		fi
	done
	echo "$secret_obsolete"
}

get_secrets_to_preserve() {
	old_service_secrets="$1"
	secret_label_hash_name="$2"
	dotenv_secret_hash="$3"
	secret_to_preserve=""
	new_line=$(printf '\n')

	for secret in $old_service_secrets; do
		old_hash=$(docker secret inspect "$secret" --format="{{index .Spec.Labels \"$secret_label_hash_name\"}}")
		if [ -n "$old_hash" ] && printf "%s" "$old_hash" | grep -q "$new_line" && [ "$old_hash" = "$dotenv_secret_hash" ]; then
			secret_to_preserve="$secret_to_preserve$secret "
		fi
	done
	echo "$secret_to_preserve"
}

prune_secrets() {
	if ! command -v "jq" >/dev/null 2>&1; then
		echo "jq is not installed. Please install it to prune secrets."
		exit 1
	fi
	if is_debug; then
		debug "All secrets :"
		for all_secret in $(docker secret ls -q); do
			all_secret_name=$(get_secret_name "$all_secret")
			printf "\"%s\" " "$all_secret_name"
		done
		printf "\n"
	fi
	used_secrets=$(docker service ls -q | xargs -I {} docker service inspect {} --format '{{json .Spec.TaskTemplate.ContainerSpec.Secrets}}' | jq -r 'select(. != null) | .[].SecretID' | sort -u)
	if is_debug; then
		debug "Secrets currently used :"
		for used_secret in $used_secrets; do
			used_secret_name=$(get_secret_name "$used_secret")
			printf "\"%s\" " "$used_secret_name"
		done
		printf "\n"
	fi

	for secret in $(docker secret ls -q); do
		if ! echo "$used_secrets" | grep -qw "$secret"; then
			secret_name=$(get_secret_name "$secret")
			info "Prune unused secret: \"$secret_name\""
			docker secret rm "$secret"
		fi
	done
}

get_secret_name() {
	secret=$1
	secret_name=$(docker secret inspect "$secret" --format '{{.Spec.Name}}')
	echo "$secret_name"
}

if ! command -v yq >/dev/null 2>&1; then
	echo "yq is needed to use this script." >&2
	exit 1 
fi

debug "$0 \"$*\""

if [ -z "${1+set}" ] || [ -z "${2+set}" ] || [ -z "${3+set}" ] || [ -z "${4+set}" ]; then
	echo "Usage: $0 docker-compose.yml stack_name service_name secret_name key1 value1 key2 value2 ..." >&2
	exit 1
fi

if [ -z "${POST_SCRIPTS_FOLDER+set}" ]; then
	POST_SCRIPTS_FOLDER="/opt/scripts/post"
fi

docker_compose_file_path=$1
stack_name=$2
secret_delete_old=$3
secret_prune=$4
service_name=$5
secret_name=$6
service_fullname=${stack_name}_${service_name}

secret_name_suffix=$(openssl rand -hex 2)
secret_name_full="${secret_name}_${secret_name_suffix}"
secret_values=""
secret_start_after=6
secret_label_hash_name="hash"
secret_label_name="name"

# Check if there are enough arguments for key-value pairs
num_args=$(($# - secret_start_after))
if [ $num_args -eq 0 ] || [ $((num_args % 2)) -ne 0 ]; then
	echo "Error: Insufficient key-value pairs provided for the secret." >&2
	exit 1
fi

info "Retrieving secret keys and values"
# Format humain input
shift $secret_start_after
while [ $# -gt 0 ]; do
	key="$1"
	value="$2"
	secret_values="$secret_values$key:$value;"
	shift 2  # Move to the next pair
done

# Secret in format
# KEY1=value1
# KEY2=value2
info "Formatting secret keys and values"
dotenv_secret=$(format_secret_input "$secret_values")

# Hash indicates when to update the secret
info "Calculating hash for secrets"
dotenv_secret_hash=$(calculate_hash "$dotenv_secret")
debug "Secret hash: $dotenv_secret_hash"

if [ "$secret_prune" = "true" ]; then
	info "Pruning secrets ..."
	prune_secrets
fi

# Check if the service exists; if not, there are no old secrets to handle.
if docker service inspect "$service_fullname" >/dev/null 2>&1; then
	info "Fetching all secrets for service \"$service_fullname\""
	old_service_secrets=$(get_service_secrets "$service_fullname")
	if is_debug; then
		debug "Secrets used by service \"$service_fullname\":"
		for used_secret in $old_service_secrets; do
			used_secret_name=$(get_secret_name "$used_secret")
			printf "\"%s\" " "$used_secret_name"
		done
		printf "\n"
	fi

	# TODO: test more than one secret
	info "Fetching the secrets with name \"$secret_name\" for service \"$service_fullname\""
	old_service_secrets=$(get_secrets_with_name "$old_service_secrets" "$secret_label_name" "$secret_name")
	if is_debug; then
		debug "Secrets with name \"$secret_name\" used by service \"$service_fullname\":"
		for used_secret in $old_service_secrets; do
			used_secret_name=$(get_secret_name "$used_secret")
			printf "\"%s\" " "$used_secret_name"
		done
		printf "\n"
	fi

	info "Identifying secrets for removal"
	secrets_obsolete=$(get_secrets_obsolete "$old_service_secrets" "$secret_label_hash_name" "$dotenv_secret_hash")
	if [ -n "$secrets_obsolete" ]; then
		info "Secrets to remove:"
		for secret_obsolete in $secrets_obsolete; do
			printf "\"%s\" " "$secret_obsolete"
		done
		printf "\n"
	fi

	info "Identifying secrets to preserve"
	secrets_preserves=$(get_secrets_to_preserve "$old_service_secrets" "$secret_label_hash_name" "$dotenv_secret_hash")
	for secret_preserve in $secrets_preserves; do
		secret_preserve_name=$(get_secret_name "$secret_preserve")
		info "Preserve the old secret \"$secret_preserve_name\" into the docker-compose file"
		yq --inplace ".secrets.$secret_preserve_name.external = true" "$docker_compose_file_path"

		info "Updating the \"$service_name\" service within the docker-compose file with the old secret"
		yq --inplace ".services.$service_name.secrets += [\"$secret_preserve_name\"]" "$docker_compose_file_path"
	done

	if is_debug; then
		debug "Docker compose file $docker_compose_file_path :"
		cat "$docker_compose_file_path"
	fi

	if is_secret_exists "$old_service_secrets" "$secret_label_hash_name" && [ "$secrets_obsolete" = "" ]; then
		info "Secret rotation not needed"
		return
	fi
else
	secrets_obsolete=""
fi

info "Generate new secret: \"$secret_name_full\""
printf '%b' "$dotenv_secret" | docker secret create "$secret_name_full" -l "$secret_label_name=$secret_name" -l "$secret_label_hash_name=$dotenv_secret_hash" -

info "Integrating the new secret \"$secret_name_full\" into the docker-compose file"
yq --inplace ".secrets.$secret_name_full.external = true" "$docker_compose_file_path"

info "Updating the $service_name service within the docker-compose file with the new secret"
yq --inplace ".services.$service_name.secrets += [\"$secret_name_full\"]" "$docker_compose_file_path"

if is_debug; then
	debug "Docker compose file $docker_compose_file_path :"
	cat "$docker_compose_file_path"
fi

if [ -n "$secrets_obsolete" ]; then
	if [ "$secret_delete_old" = "true" ]; then
		info "Implementing post-command to delete previous secrets"
		debug "Creating post-script folder $POST_SCRIPTS_FOLDER"
		mkdir -p "$POST_SCRIPTS_FOLDER"
		post_script_path="$POST_SCRIPTS_FOLDER/docker_secret_rm.sh"
		debug "Creating post-script file $post_script_path"
		touch "$post_script_path"
		chmod 700 "$post_script_path"
		{
			echo "#!/bin/sh"
			echo "set -eux"
			for obsolete_secret in $secrets_obsolete; do
				echo "secret=\"$obsolete_secret\""
				echo "secret_name=\$(docker secret inspect \"\$secret\" --format '{{.Spec.Name}}')"
				echo "echo \"Delete unused secret: \$secret_name\""
				echo "docker secret rm \"\$secret\""
			done
		} >> "$post_script_path"
		if is_debug; then
			debug "Post-script file $post_script_path :"
			cat "$post_script_path"
		fi
	else
		info "Secrets not deleted because of secret deletion policy :"
		for secret_obsolete in $secrets_obsolete; do
			printf "\"%s\" " "$secret_obsolete"
		done
		printf "\n"
	fi
fi

info "Completion of Docker secret rotation"
