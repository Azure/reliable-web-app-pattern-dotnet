targetScope = 'resourceGroup'

/*
** Budget
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Provides a recurring budget for the resource group.  You must specify
** the amount minimally.
*/

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The name of the primary resource')
param name string

@description('The total amount of cost or usage to track with the budget; this is in the currency of the billing account.')
param amount int = 1000

@description('The time covered by a budget. Tracking of the amount will be reset based on the time grain.')
@allowed([ 'Monthly', 'Quarterly', 'Annually' ])
param timeGrain string = 'Monthly'

@description('The start date must be first of the month in YYYY-MM-DD format. Future start date should not be more than three months. Past start date should be selected within the timegrain preiod.')
param startDate string = utcNow('yyyy-MM')

@description('The end date for the budget in YYYY-MM-DD format. If not provided, we default this to 10 years from the start date.')
param endDate string = dateTimeAdd(utcNow(), 'P10Y', 'yyyy-MM')

@description('Threshold value associated with a notification. Notification is sent when the cost exceeded the threshold. It is always percent and has to be between 0.01 and 1000.')
param firstThreshold int = 75

@description('Threshold value associated with a notification. Notification is sent when the cost exceeded the threshold. It is always percent and has to be between 0.01 and 1000.')
param secondThreshold int = 95

@description('The list of email addresses to send the budget notification to when the threshold is exceeded.')
param contactEmails string[]

@description('The set of values for the resource group filter.')
param resourceGroups string[]

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource budget 'Microsoft.Consumption/budgets@2021-10-01' = {
  name: name
  properties: {
    timePeriod: {
      startDate: '${startDate}-01'
      endDate: '${endDate}-01'
    }
    timeGrain: timeGrain
    amount: amount
    category: 'Cost'
    notifications: {
      NotificationForExceededBudget1: {
        enabled: true
        operator: 'GreaterThan'
        threshold: firstThreshold
        contactEmails: contactEmails
      }
      NotificationForExceededBudget2: {
        enabled: true
        operator: 'GreaterThan'
        threshold: secondThreshold
        contactEmails: contactEmails
      }
      NotificationForExceededBudget3: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        contactEmails: contactEmails
      }
    }
    filter: {
      dimensions: {
        name: 'ResourceGroupName'
        operator: 'In'
        values: resourceGroups
      }
    }
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = budget.id
output name string = budget.name

