# Docker Stack Deployment Action

Docker Stack Deployment Action is a versatile tool designed for effortless docker-compose and Docker Swarm deployments within GitHub Actions workflows.

## Example

Below is a concise example demonstrating the utilization of this action:

```yaml
- name: Deploy to Docker
  uses: tristiisch/docker-stack-deployment@v2.3
  with:
    remote_docker_host: 203.0.113.0
    remote_docker_username: johndoe
    ssh_private_key: ${{ secrets.DOCKER_SSH_PRIVATE_KEY }}
    ssh_public_key: ${{ secrets.DOCKER_SSH_PUBLIC_KEY }}
    deployment_mode: docker-swarm
    copy_stack_file: true
    deploy_path: /opt/docker/stack-name
    stack_file_path: ./docker-compose.production.yaml
    keep_files: 5
    docker_remove_orphans: true
    stack_name: stack-name
    secrets: compose-service-name secret-prefix VAR_KEY_1 var_value_1 VAR_KEY_2 var_value_2
    secrets_prune: false
    args: ""
```

## Input Configurations

Below is a comprehensive list of all supported inputs. Certain inputs are sensitive and should be stored as secrets.

### `remote_docker_host`

Specify the Remote Docker host like `203.0.113.0`.

### `remote_docker_port`

Specify the Remote Docker SSH port if it's not the default (22), e.g., (2222).

### `remote_docker_username`

Specify the Remote Docker username like `johndoe`.

### `ssh_public_key`

Provide the SSH public key for the remote Docker server. **Do not use the content of `id_rsa.pub`**. Instead:

1. Run `ssh-keyscan -t <algorithm> <host>` (replace `<algorithm>` with `rsa`, `ecdsa`, or `ed25519`, and `<host>` with the server's hostname or IP).
   
   Example for RSA:
   ```
   ssh-keyscan -t rsa <host>
   ```

2. Choose the line matching your private key’s algorithm and **copy only the key** (exclude the host and algorithm name).

Examples:
```
ecdsa-sha2-nistp256 AAAAE2VjZHNhLNTYAAAAIbmlzdHAyNCN5F3TLxUllpSRx8y+9C2uh+lWZDFmAsFMjcz2Zgq4d5F+oGicGaRk=
```
or
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5pKf6j0c6sCIoJxg2tO9Xj7UOCmX...
```

### `ssh_private_key`

Provide the SSH private key used to connect to the Docker host.

Exemple:
```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAACFwAAAAdzc2gtcn
...
Cd1OwTxgE6cAAAAPcm9vdEBzd2FybS10ZXN0AQIDBA==
-----END OPENSSH PRIVATE KEY-----
```
> If this doesn't work, you may want to try ensuring that the SSH key is in PEM format, identifiable by the header starting with -----BEGIN RSA PRIVATE KEY-----. Failure to do so might lead to encountering an 'invalid format' error. Convert it from the OPENSSH format, which begins with -----BEGIN OPENSSH PRIVATE KEY-----, by using the command `ssh-keygen -p -m PEM -f ~/.ssh/id_rsa`.

### `deployment_mode`

Specify the deployment mode as either docker-swarm or docker-compose. The default is docker-compose.

### `copy_stack_file`

Toggle to copy the stack file to the remote server and deploy from there. Default is false.

### `deploy_path`

Specify the path where the stack files will be copied. Default is ~/docker-deployment.

### `stack_file_path`

Specify the Docker stack path to be used. Default is ./docker-compose.yaml.

### `keep_files`

Specify the number of files to be retained on the server. Default is 3.

### `docker_prune`

A boolean input to trigger the docker prune command.

### `pre_deployment_command_args`

Specify the arguments for the pre-deployment command. Applicable only for Docker Compose.

### `pull_images_first`

Toggle to pull Docker images before deploying. Applicable only for Docker Compose.

### `stack_name`

Specify the name of the stack. This is only applicable for Docker Swarm.

### `secrets`

Create [Docker Swarm secrets](https://docs.docker.com/compose/how-tos/use-secrets/) for a specific service.  
Each secret will be mounted inside the container at `/run/secrets/<secret_name>` with content like:

```
VAR_KEY_1=var_value_1
VAR_KEY_2=var_value_2
```

**Format of the `secrets` input:**

```yaml
secrets: <compose-service-name> <secret-prefix> VAR_KEY_1 var_value_1 VAR_KEY_2 var_value_2 ...
```

- `<compose-service-name>`: name of the service in your `docker-compose.yml`
- `<secret-prefix>`: prefix added to secret names to avoid collisions
- Each `VAR_KEY` / `var_value` pair is turned into a Docker secret containing the line `VAR_KEY=var_value`
- The final secret_name is built using:
<secret-prefix>-<random> where <random> is a short random string of length 8 to ensure uniqueness

### `args`

Specify arguments to pass to the deployment command, either `docker` or `docker-compose`. The action automatically generates the following commands for each case:
- `docker stack deploy --compose-file $STACK_FILE_PATH $STACK_NAME $ARGS`
- `docker compose -f $STACK_FILE_PATH $ARGS`

### `debug`

Enable verbose logging for debugging purposes. This is automatically enabled when running the job in GitHub debug mode.

### `trace`

Enable detailed logging to capture each executed instruction

## TODO

- [x] **Create external Docker Secrets**  
- [ ] **Create external Docker Networks**  
- [ ] **Create and rotate Docker Configs**
- [ ] **Populate Dockerfile variables with pipeline variables**
- [ ] **Read multiple docker-compose files**

## License

This project is licensed under the MIT license. See the [LICENSE](LICENSE) file for details.
