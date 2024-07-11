@minLength(1)
@description('Specifies the name of an existing app service plan that will receive scale rules')
param appServicePlanName string

@description('Enables the template to choose different SKU by environment')
param isProd bool

@description('The Azure location where this solution is deployed')
param location string = resourceGroup().location

@description('An object collection that contains annotations to describe the deployed azure resources to improve operational visibility')
param tags object

var scaleOutThreshold = 85
var scaleInThreshold = 60

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' existing = {
  name: appServicePlanName
} 

resource apiAppScaleRule 'Microsoft.Insights/autoscalesettings@2014-04-01' = if (isProd) {
  name: '${appServicePlanName}-autoscale'
  location: location
  tags: tags
  properties: {
    targetResourceUri: appServicePlan.id
    enabled: true
    profiles: [
      {
        name: 'Auto created scale condition'
        capacity: {
          minimum: string(1)
          maximum: string(10)
          default: string(1)
        }
        rules: [
          {
            metricTrigger: {
              metricResourceUri: appServicePlan.id
              metricName: 'CpuPercentage'
              timeGrain: 'PT5M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: scaleOutThreshold
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: string(1)
              cooldown: 'PT10M'
            }
          }
          {
            metricTrigger: {
              metricResourceUri: appServicePlan.id
              metricName: 'CpuPercentage'
              timeGrain: 'PT5M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: scaleInThreshold
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: string(1)
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
  }
}
