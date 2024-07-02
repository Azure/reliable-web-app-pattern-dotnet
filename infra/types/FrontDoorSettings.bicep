@export()
@description('Type describing the settings for Azure Front Door.')
type FrontDoorSettings = {
  @description('The name of the Azure Front Door endpoint')
  endpointName: string

  @description('Front Door Id used for traffic restriction')
  frontDoorId: string

  @description('The hostname that can be used to access Azure Front Door content.')
  hostname: string

  @description('The profile name that is used for configuring Front Door routes.')
  profileName: string
}
