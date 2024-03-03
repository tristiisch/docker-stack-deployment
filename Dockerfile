FROM docker:latest

LABEL 'name'='Docker Swarm Deployment Action'
LABEL 'maintainer'='Tristiisch <tristiisch@outlook.fr>'

LABEL 'com.github.actions.name'='Docker Swarm Deployment'
LABEL 'com.github.actions.description'='supports docker-compose and Docker Swarm deployments'
LABEL 'com.github.actions.icon'='send'
LABEL 'com.github.actions.color'='green'

RUN apk --no-cache add openssh-client docker-compose

WORKDIR /app

COPY ./docker-entrypoint.sh ./docker-entrypoint.sh
COPY ./scripts ./scripts

RUN chmod 755 docker-entrypoint.sh
RUN chmod -R 755 ./scripts

ENTRYPOINT ["/app/docker-entrypoint.sh"]
