# Use an official Python runtime as a parent image
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND noninteractive
ENV WORKDIR /root/
WORKDIR $WORKDIR
RUN export PATH=.:$PATH

# Start the update in front of every added install statement because of the docker cache (update is not deterministic)
RUN apt update && apt install wget rsync curl -y
RUN apt update && apt install colorized-logs -y
RUN apt update && apt install plantuml -y

# Fix nodejs problem on ubuntu
# (See https://github.com/nodesource/distributions/issues/1157#issuecomment-1131212089)
RUN dpkg --remove --force-remove-reinstreq libnode-dev
RUN dpkg --remove --force-remove-reinstreq libnode72:amd64
RUN dpkg --remove --force-remove-reinstreq libnode72:arm64

RUN apt update && apt install nodejs npm -y

# Install buildx and enable it
ENV DOCKER_BUILDKIT=1
RUN mkdir -p ~/.docker/cli-plugins/ \
  && curl -L https://github.com/docker/buildx/releases/download/v0.11.2/buildx-v0.11.2.linux-amd64 -o ~/.docker/cli-plugins/docker-buildx \
  && chmod +x ~/.docker/cli-plugins/docker-buildx

# build all things inside container
ADD entrypoint entrypoint
RUN entrypoint/build.sh

EXPOSE 22
ENTRYPOINT ["entrypoint/start.sh"]
