FROM ubuntu:18.04 as builder
WORKDIR /app
ENV VENV /app/venv
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV PYTHONPATH /app

WORKDIR /app

# avoid python-tk questions
# not sure I actually need python-tk, maybe that's just for rendering
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y python-pip virtualenv make build-essential libssl-dev curl python-tk unzip

# Run this before dealing with our own virtualenv. The AWS CLI uses its own virtual environment
RUN pip install awscli wheel

RUN curl -L --output /tmp/proto.zip https://github.com/protocolbuffers/protobuf/releases/download/v3.10.1/protoc-3.10.1-linux-x86_64.zip && unzip /tmp/proto.zip -d /

# Tensorflow 2.0 is installed
# but object_decection requires v1 
# we need to sed replace the import
RUN curl -L --output /tmp/models.tgz https://codeload.github.com/tensorflow/models/tar.gz/master \
  && tar -xvf /tmp/models.tgz -C /tmp \
  && mkdir object_detection \
  && mv /tmp/models-master/research/object_detection/__init__.py object_detection/ \
  && mv /tmp/models-master/research/object_detection/core object_detection/ \
  && mv /tmp/models-master/research/object_detection/utils object_detection/ \
  && mv /tmp/models-master/research/object_detection/protos object_detection/ \
  && mv /tmp/models-master/research/object_detection/data object_detection/ \
  && rm -rf /tmp/models-master && protoc object_detection/protos/*.proto --python_out=. \
  && sed -i 's/import tensorflow as tf/import tensorflow.compat.v1 as tf/' object_detection/utils/label_map_util.py \
  && sed -i '/import tensorflow.compat.v1 as tf/a tf.disable_v2_behavior()' object_detection/utils/label_map_util.py 

RUN pip --no-cache-dir install --upgrade \
    pip \
    setuptools

COPY ./requirements.txt .
RUN pip install --user --no-cache --ignore-installed -r requirements.txt
# add user path
ENV PATH=$PATH:/root/.local/bin

COPY . .

# slim image
FROM python:2.7.17-slim-buster
COPY --from=builder /root/.local /root/.local
ENV PATH=$PATH:/root/.local/bin
COPY --from=builder /app /app
RUN ln -s /usr/local/bin/python /usr/bin/python
ENV PYTHONPATH /app
ENV VENV /app/venv
WORKDIR /app
