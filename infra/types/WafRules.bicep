@export()
type WAFRuleSet = {
  @description('The name of the rule set')
  name: string

  @description('The version of the rule set')
  version: string
}

@export()
type CustomRule = {
  @description('The name of the custom rule')
  name: string

  @description('The priority of the custom rule')
  priority: int

  @description('The state of the custom rule')
  enabledState: string

  @description('The rule type "MatchRule" or "RateLimitRule".')
  ruleType: string

  @description('The action to take when the rule is triggered')
  action: string

  @description('Number of allowed requests per client within the time window.')
  rateLimitThreshold: int

  @description('Time window for resetting the rate limit count. Default is 1 minute.')
  rateLimitDurationInMinutes: int

  @description('The match conditions for the rule')
  matchConditions: {
    @description('The match variable')
    matchVariable: string

    @description('The operator to use for the match')
    operator: string

    @description('Describes if the result of this condition should be negated.')
    negateCondition: bool

    @description('The values to match against')
    matchValue: string[]
  }[]
}

@export()
type CustomRuleList = {
  @description('A list of custom rules to apply')
  rules: CustomRule[]
}
