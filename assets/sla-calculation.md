# Calculating Solution Service Level Agreement

The requirement for the web application is that the combined service level agreement for all components in the hot path is greater than 99.9%.  The components in the hot path comprise of any service that is used in fulfilling a web request from a user.  

## Development

With a development environment, network isolation is not used.  The following services are considered:

| Service           | Azure SLA |
|:------------------|----------:|
| Azure Front Door  | 99.990%   |
| Entra ID          | 99.990%   |
| Azure App Service | 99.950%   |
| Redis Cache       | 99.900%   |
| Azure SQL         | 99.995%   |
| Azure Storage     | 99.900%   |
| Key Vault         | 99.990%   |
| App Configuration | 99.900%   |
| **Combined SLA**  | **99.616%** |

## Production - Single Region

When operating in production, network isolation is used.  We do not consider the availability of the hub resources or VNET peering.

| Service           | Azure SLA |
|:------------------|----------:|
| Azure Front Door  | 99.990%   |
| Entra ID          | 99.990%   |
| Private DNS Zone  | 100.00%   |
| AFD Private Link  | 99.990%   |
| Azure App Service | 99.950%   |
| - Private Link    | 99.990%   |
| Redis Cache       | 99.900%   |
| - Private Link    | 99.990%   |
| Azure SQL         | 99.995%   |
| - Private Link    | 99.990%   |
| Azure Storage     | 99.900%   |
| - Private Link    | 99.990%   |
| Key Vault         | 99.990%   |
| - Private Link    | 99.990%   |
| App Configuration | 99.900%   |
| - Private Link    | 99.990%   |
| **Combined SLA**  | **99.546%** |

## Production - Two Regions

Since the single region SLA is less than the requested 99.9% availability, we have to deploy to two regions.  Azure Front Door, Entra ID, and Private DNS Zones are shared resources.  However, the rest of the services can be doubled up for more reliability.

| Service           | Azure SLA |
|:------------------|----------:|
| **Shared Services** ||
| Azure Front Door  | 99.990%   |
| Entra ID          | 99.990%   |
| Private DNS Zone  | 100.00%   |
| **Regional Services** ||
| AFD Private Link  | 99.990%   |
| Azure App Service | 99.950%   |
| - Private Link    | 99.990%   |
| Redis Cache       | 99.900%   |
| - Private Link    | 99.990%   |
| Azure SQL         | 99.995%   |
| - Private Link    | 99.990%   |
| Azure Storage     | 99.900%   |
| - Private Link    | 99.990%   |
| Key Vault         | 99.990%   |
| - Private Link    | 99.990%   |
| App Configuration | 99.900%   |
| - Private Link    | 99.990%   |
| **Shared Services**   | **99.980%**   |
| **Regional Services** | **99.546%**   |
| **Combined SLA**      | **99.9779%**  |

Using dual regions will help us achieve the requested service level agreement.

For more information on how to calculate effective SLO, please refer to [the Well Architected Framework](https://learn.microsoft.com/azure/well-architected/reliability/metrics).
