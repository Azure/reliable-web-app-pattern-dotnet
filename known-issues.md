# Known issues
This document helps with troubleshooting and provides an introduction to the most requested features, gotchas, and questions.

## Data consistency for multi-regional deployments

This sample includes a feature to deploy to two Azure regions. The feature is intended to support the high availability scenario by deploying resources in an active/passive configuration. The sample currently supports the ability to fail-over web-traffic so requests can be handled from a second region. However it does not support data synchronization between two regions.