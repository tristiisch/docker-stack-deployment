# Docker Stack Deployment Action

Docker Stack Deployment Action is a versatile tool designed for effortless docker-compose and Docker Swarm deployments within GitHub Actions workflows.

## Example

Below is a concise example demonstrating the utilization of this action:

```yaml
- name: Deploy to Docker
  uses: tristiisch/docker-stack-deployment@v1
  with:
    remote_docker_host: user@myswarm.com
    ssh_private_key: ${{ secrets.DOCKER_SSH_PRIVATE_KEY }}
    ssh_public_key: ${{ secrets.DOCKER_SSH_PUBLIC_KEY }}
    deployment_mode: docker-swarm
    copy_stack_file: true
    deploy_path: /root/my-deployment
    stack_file_name: docker-compose.yaml
    keep_files: 5
    args: my_application
```

## Input Configurations

Below is a comprehensive list of all supported inputs. Certain inputs are sensitive and should be stored as secrets.

### `args`

Specify arguments to pass to the deployment command, either `docker` or `docker-compose`. The action automatically generates the following commands for each case:
- `docker stack deploy --compose-file $FILE --log-level debug --host $HOST`
- `docker-compose -f $INPUT_STACK_FILE_NAME`

### `remote_docker_host`

Specify the Remote Docker host in the format `user@host`.

### `remote_docker_port`

Specify the Remote Docker SSH port if it's not the default (22), e.g., (2222).

### `ssh_public_key`

Provide the SSH public key for the Remote Docker. Do not provide the content of `id_rsa.pub`. Instead, provide the content of `~/.ssh/known_hosts`, obtainable by connecting to the host once using your machine.

Example:
```
1.1.1.1 ecdsa-sha2-nistp256 AAAAE2VjZHNhLNTYAAAAIbmlzdHAyNCN5F3TLxUllpSRx8y+9C2uh+lWZDFmAsFMjcz2Zgq4d5F+oGicGaRk=
```

### `ssh_private_key`

Provide the SSH private key used to connect to the Docker host. Ensure the SSH key is in PEM format (begins with -----BEGIN RSA PRIVATE KEY-----), or you may encounter an "invalid format" error. Convert it from OPENSSH format (beginning with -----BEGIN OPENSSH PRIVATE KEY-----) using `ssh-keygen -p -m PEM -f ~/.ssh/id_rsa`.

### `deployment_mode`

Specify the deployment mode as either docker-swarm or docker-compose. The default is docker-compose.

### `copy_stack_file`

Toggle to copy the stack file to the remote server and deploy from there. Default is false.

### `deploy_path`

Specify the path where the stack files will be copied. Default is ~/docker-deployment.

### `stack_file_name`

Specify the Docker stack file to be used. Default is docker-compose.yaml.

### `keep_files`

Specify the number of files to be retained on the server. Default is 3.

### `docker_prune`

A boolean input to trigger the docker prune command.

### `pre_deployment_command_args`

Specify the arguments for the pre-deployment command. Applicable only for docker-compose.

### `pull_images_first`

Toggle to pull Docker images before deploying. Applicable only for docker-compose.

### `debug`

Enable verbose messages for debugging purposes.

## License

This project is licensed under the MIT license. See the [LICENSE](LICENSE) file for details.