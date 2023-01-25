#!/bin/bash

# this runs each time the container starts

echo "$(date)    post-start start" >> ~/status

azd config set auth.useAzCliAuth true

echo "$(date)    post-start complete" >> ~/status
