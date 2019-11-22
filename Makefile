export IMAGE_NAME=flytehub/objectdetector

docker_build:
	./docker_build.sh

.PHONY: dockerhub_push
dockerhub_push:
	REGISTRY=docker.io ./docker_build.sh
