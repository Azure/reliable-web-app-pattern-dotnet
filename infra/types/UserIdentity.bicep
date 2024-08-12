@export()
@description('Type describing a user identity.')
type UserIdentity = {
  @description('The ID of the user')
  principalId: string

  @description('The name of the user')
  principalName: string
}
