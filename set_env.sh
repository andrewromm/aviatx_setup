#!/bin/bash

export DOCKER_GROUP_ID=$(getent group docker | cut -d: -f3)
