# Resulting service level and cost

Relecloud's solution has a 99.98% availability SLO and has an
estimated cost between $2,000 and $3,000 per month when
deployed to the East US and West US 2 Azure regions.

## Service Level Objective

Relecloud uses multiple Azure Services to achieve a composite
availability SLO of 99.98%.

To calculate this they reviewed their business scenario and
defined that the system is considered *available* when customers
can purchase tickets. This means that we can determine the
solution's availability by finding the availability of the
Azure services that must be functioning to complete the checkout
process.

> This also means that the team *does not* consider Azure
> Monitor a part of their scope for an available web app. This
> means the team accepts that the web app might miss an alert
> or scaling event if there is an issue with Azure Monitor. If
> this were unacceptable then the team would have to add that
> as an additional Azure service for their availability
> calculations.

The next step to calculate the availability was to identify
the SLA of the services that must each be available to complete
the checkout process.

| Azure Service | SLA |
| --- | --- |
| [Azure Active Directory](https://azure.microsoft.com/support/legal/sla/active-directory/v1_1/) | 99.99% |
| [Azure App Configuration](<https://azure.microsoft.com/support/legal/sla/app-configuration/v1_0/>) | 99.9% |
| [Azure App Service: Front-end](https://azure.microsoft.com/support/legal/sla/app-service/) | 99.95% |
| [Azure App Service: API](https://azure.microsoft.com/support/legal/sla/app-service/) | 99.95% |
| [Azure Cache for Redis](https://azure.microsoft.com/support/legal/sla/cache/) |99.9% |
| [Azure Key Vault](https://azure.microsoft.com/support/legal/sla/key-vault/v1_0/) | 99.99% |
| [Azure Private Link](https://azure.microsoft.com/support/legal/sla/private-link/v1_0/) | 99.99%|
| [Azure Storage Accounts](https://azure.microsoft.com/support/legal/sla/storage/v1_5/) |  99.9% |
| [Azure SQL Database](https://azure.microsoft.com/support/legal/sla/azure-sql-database/v1_8/) |  99.99% |

To find the impact that one of these services has to our
availability [we multiply each of these SLAs](https://docs.microsoft.com/en-us/azure/architecture/framework/resiliency/business-metrics#composite-slas).
By combining the numbers we reach the percentage of time that
all services are available.

When combined the SLAs assert that tickets could be sold
99.56% of the time. This availability meant there could be as
much as 38 hours of downtime in a year.

This availability, and risk to brand damage, were unacceptable
for Relecloud so they deploy their web app to two regions. Using
two regions changes the calculation to use the
[multiregional availability formula](https://docs.microsoft.com/en-us/azure/architecture/framework/resiliency/business-metrics#slas-for-multiregion-deployments)
which is
`(1 - (1 − N) ^ R)` to reach 99.99% availability. But, to use two
regions the team must also add Azure Front Door which has an
availibility SLA of 99.99% so the composite availability for
this solution becomes 99.98%.

## Cost

The Relecloud team wants to use lower price SKUs for non-prod
workloads to manage costs while building testing environments.
To do this they added conditionals to their bicep templates
so they could choose different SKUs and optionally choose to
deploy to multiple regions when targeting production.

Pricing Calculator breakouts
- [Non-prod](https://azure.com/e/26f1165c5e9344a4bf814cfe6c85ed8d)
- [Prod](https://azure.com/e/8a574d4811a74928b55956838db71093)

### Production

Additional costs will vary as the web apps scale based
on load and the solution will also have additional costs for the
data transmitted from the Azure data center. The primary forces
driving this estimate are Azure SQL Database and Azure App
Service.

Their solution deploys an Azure SQL Database Premium SKU that
uses the DTU pricing model. The selected SKU provides 500gB for
database storage and 125 DTU of capacity for SQL compute tasks.

> Azure SQL provides many options to choose the
> right fit for your solution. In this deployment the Azure SQL
> Database represents about 45% of the estimated costs. We
> recommend that you review how your solution behaves in
> production as changing your database SKU can provide
> significant cost savings or performance gains.

Their solution also deploys a minimum of two Azure App Services
to run the front-end and API tier websites for this solution.
These web apps target the P1V2 SKU which enables the website to
use horizontal scaling rules to reduce costs when there are
fewer users on the website. Together, these components represent
about 29% of the estimated hosting costs.

Azure Cache for Redis represents about 10% of the estimated
cost. To reduce costs the Relecloud team chooses to share this
resource between the front-end web app and the API backend. The
team found that C1 SKU is more than enough capacity to handle
the responsibilities of session management and data caching.

> We recommend that customers review these prices with their
> account team. Prices vary by region and can be impacted by
> Enterprise Agreements, Dev/Test Pricing, or Reserved capacity
> pricing.

### Non-prod environments

The primary drivers of cost for non-production environments are
the App Service Plans which represent 44% of the total cost.
Customers that want to manage these costs for non-production
workloads should examine if they can use one
[App Service Plan](https://docs.microsoft.com/en-us/azure/app-service/overview-hosting-plans)
to host both the front-end and API web apps.

> We recommend that customers review these prices with their
> account team. Prices vary by region and non-production pricing
> can be impacted by Dev/Test pricing as well as other factors.

## Next Step
- [Find additional resources](additional-resources.md)
