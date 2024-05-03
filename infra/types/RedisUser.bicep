// From: infra/types/RedisUser.bicep
@description('Type describing the user for redis.')
type RedisUser = {
  @description('The object id of the user.')
  objectId: string

  @description('The alias of the user')
  alias: string

  @description('Specify name of built-in access policy to use as assignment.')
  accessPolicy: 'Data Owner' | 'Data Contributor' | 'Data Reader'
}
