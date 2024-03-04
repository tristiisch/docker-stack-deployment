#!/bin/sh
set -eu
. scripts/functions.sh

get_service_secrets() {
    service_name=$1

	return_secrets=""
    secrets=$(docker service inspect --format '{{ range .Spec.TaskTemplate.ContainerSpec.Secrets }}{{ .SecretName }} {{ end }}' "$service_name")
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
	old_service_sercrets="$1"
	secret_label_hash_name="$2"

	for secret in $old_service_sercrets; do
		old_hash=$(docker secret inspect "$secret" --format="{{index .Spec.Labels \"$secret_label_hash_name\"}}")
		if [ -n "$old_hash" ]; then
			return 0
		fi
	done
	return 1
}

get_secret_obsolete() {
	old_service_sercrets="$1"
	secret_label_hash_name="$2"
	dotenv_secret_hash="$3"
	secret_obsolete=""
	new_line=$(printf '\n')

	for secret in $old_service_sercrets; do
		old_hash=$(docker secret inspect "$secret" --format="{{index .Spec.Labels \"$secret_label_hash_name\"}}")
		if [ -n "$old_hash" ] && printf "%s" "$old_hash" | grep -q "$new_line" && [ "$old_hash" != "$dotenv_secret_hash" ]; then
			secret_obsolete="$secret_obsolete$secret "
		fi
	done
	echo "$secret_obsolete"
}

if ! command -v yq >/dev/null 2>&1; then
    echo "yq is needed to use this script." >&2
    exit 1 
fi

debug "docker_secret.sh $*"

# Check if service_name is provided
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
    echo "Usage: $0 docker-compose.yml stack_name service_name secret_name key1 value1 key2 value2 ..." >&2
    exit 1
fi

if [ -z "${POST_SCRIPTS_FOLDER+set}" ]; then
	POST_SCRIPTS_FOLDER="/opt/scripts/post"
fi

docker_compose_file_path=$1
stack_name=$2
service_name=$3
secret_name=$4
service_fullname=${stack_name}_${service_name}

# Check if service exists
if ! docker service inspect "$service_fullname" >/dev/null 2>&1; then
    echo "The service $service_fullname didn't exists"
	exit 1
fi

secret_name_suffix=$(openssl rand -hex 2)
secret_name_full="${secret_name}_${secret_name_suffix}"
secret_values=""
secret_start_after=4
secret_label_hash_name="hash"

# Check if there are enough arguments for key-value pairs
num_args=$(($# - secret_start_after))
if [ $num_args -eq 0 ] || [ $((num_args % 2)) -ne 0 ]; then
	echo "Error: Insufficient key-value pairs provided for the secret." >&2
	exit 1
fi

info "Read secrets key and values"
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
info "Format secrets key and values"
dotenv_secret=$(format_secret_input "$secret_values")

# Hash indicates when to update the secret
info "Caculate hash of secrets"
dotenv_secret_hash=$(calculate_hash "$dotenv_secret")
debug "Result: $dotenv_secret_hash"

info "Get current secret of service $service_fullname"
old_service_sercrets=$(get_service_secrets "$service_fullname")
debug "Result: $old_service_sercrets"

info "Get secrets to remove"
secrets_obsolete=$(get_secret_obsolete "$old_service_sercrets" "$secret_label_hash_name" "$dotenv_secret_hash")
debug "Result: $secrets_obsolete"

if is_secret_exists "$old_service_sercrets" "$secret_label_hash_name" && [ "$secrets_obsolete" = "" ]; then
	echo "Secret rotation not needed"
	exit 0
fi

info "Create a new secret"
printf '%b' "$dotenv_secret" | docker secret create "$secret_name_full" -l "$secret_label_hash_name=$(calculate_hash \"$dotenv_secret\")" -

info "Add secret to docker-compose file"
yq --inplace ".secrets.$secret_name_full.external = true" "$docker_compose_file_path"

info "Add secret to service $service_name in docker-compose file"
yq --inplace ".services.$service_name.secrets += [\"$secret_name_full\"]" "$docker_compose_file_path"

info "Add post-command to delete previous secrets"
mkdir -p "$POST_SCRIPTS_FOLDER"
post_script_path="$POST_SCRIPTS_FOLDER\docker_secret_rm.sh"
touch "$post_script_path"
chmod 700 "$post_script_path"

for obsolete_secret in $secrets_obsolete; do
	echo "docker secret remove \"$obsolete_secret\"" >> "$post_script_path"
done

info "Docker secret rotation done"
