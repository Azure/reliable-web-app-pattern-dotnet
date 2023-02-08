# Reliable Web App Pattern

This repository provides resources to help developers build a Reliable web app on Azure. A Reliable Web App is a set of services, code, and infrastructure deployed in Azure that applies practices from the Well-Architected Framework. This pattern is designed to help you build a web app that follows Microsoft's recommended guidance for achieving reliability, scalability, and security in the cloud.

**Steps to get started**:

1. <img src="assets/icons/microsoft.png" height="20px" /> [Watch Introduction Video (12~ mins)](https://aka.ms/eap-intro-video)
1. <img src="assets/icons/microsoft.png" height="20px" /> [Business scenario](business-scenario.md)
1. <img src="assets/icons/dotnetbot.png" height="20px" /> [Read the reference architecture](reliable-web-app.md)
1. <img src="assets/icons/dotnetbot.png" height="20px" /> [Deploy solution](deploy-solution.md)
    1. <img src="assets/icons/dotnetbot.png" height="20px" /> [Known issues](known-issues.md)
1. <img src="assets/icons/dotnetbot.png" height="20px" /> [Utilizing DevContainers](dev-containers.md)
1. <img src="assets/icons/dotnetbot.png" height="20px" /> [Developer patterns](patterns.md)
1. <img src="assets/icons/microsoft.png" height="20px" /> [Understand service level objectives and cost](slo-and-cost.md)
1. <img src="assets/icons/dotnetbot.png" height="20px" /> [Find additional resources](additional-resources.md)
1. <img src="assets/icons/microsoft.png" height="20px" /> [Report security concerns](SECURITY.md)
1. <img src="assets/icons/microsoft.png" height="20px" /> [Find Support](SUPPORT.md)
1. <img src="assets/icons/microsoft.png" height="20px" /> [Contributing](CONTRIBUTING.md)

[![screenshot azd env new](./assets/Guide/Intro-video.jpg)](https://aka.ms/eap-intro-video)

## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft's privacy statement. Our privacy statement is located at https://go.microsoft.com/fwlink/?LinkId=521839. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.

### Telemetry Configuration

Telemetry collection is on by default.

To opt out, run the following command `azd env set ENABLE_TELEMETRY` to `false` in your environment.