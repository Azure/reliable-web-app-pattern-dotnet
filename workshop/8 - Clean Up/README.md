## 8 - Clean Up

Thank you for engaging with our workshop on RWA. We hope the chapters provided valuable insights and practical knowledge to enhance your Azure experience.

### Cleaning up the cost optimization web application

As we conclude our journey, it’s crucial to ensure that we leave our environment clean and cost-efficient. Here’s how you can decommission the resources effectively:

1. Open a PowerShell terminal.
2. Run the command `azd down --force --purge --no-prompt`.

You may also log on to the Azure portal, select the resource group and press **Delete Resource group**.  The resource group is named similar to **<USERNAME>-cost-rg**.

### Cleaning up the reliable web app sample

1. Change directory to the `src` directory.
2. Run the command `azd down --force --purge --no-prompt`.

You may also log on to the Azure portal, select each resource group and press **Delete Resource group**.  There are two resource groups: **<USERNAME>-rg** and **<USERNAME>-secondary-rg**.

This process leaves the app registrations used in place. You can clean these up in the Azure Portal.  Go to the Azure Active Directory blade, then **App Registrations** > **Owned applications**.  Remove each app registration associated with your username individually.

We appreciate your dedication to learning and applying these practices. Your efforts contribute to a more sustainable and efficient cloud ecosystem. Thank you for reading, and we look forward to your continued growth and success in using the Reliable Web Apps Pattern in your next production app.
