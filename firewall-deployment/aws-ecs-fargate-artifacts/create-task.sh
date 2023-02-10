#!/bin/bash

# Retrieve the environment variables and flag them as exportablme for envsubst to use
set -a
. ./variables.env
set +a

# Substitute the variables in task.template, and create the resulting task.json
envsubst < task.template > task.json


