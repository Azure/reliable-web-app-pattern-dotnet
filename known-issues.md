# Known issues
This document helps with troubleshooting and provides an introduction to the most requested features, gotchas, and questions.

## Azure Subscription is not registered with CDN Provider

When you create the FIRST CDN profile or Azure Front Door profile in a subscription, you need to register your subscription with the CDN provider.  This is normally done as part of the subscription setup so it does not need to be done in the majority of cases.  To register the CDN profile, use the following PowerShell command:

```powershell
Register-AzResourceProvider -ProviderNamespace Microsoft.CDN
```

Or use the following Azure CLI command:

```bash
az provider register --namespace Microsoft.CDN
```

For more details (including methods of resolving this error without using PowerShell), see [Resolve errors for resource provider registration](https://learn.microsoft.com/azure/azure-resource-manager/troubleshooting/error-register-resource-provider?tabs=azure-cli).

## Data consistency for multi-regional deployments

This sample includes a feature to deploy to two Azure regions. The feature is intended to support the high availability scenario by deploying resources in an active/passive configuration. The sample currently supports the ability to fail-over web-traffic so requests can be handled from a second region. However it does not support data synchronization between two regions.