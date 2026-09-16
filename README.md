# Logic Apps Standard extension test template

This is a minimal Azure Developer CLI (`azd`) template for testing the
`azure.logicappsstandard` extension introduced by
[Azure/azure-dev#8005](https://github.com/Azure/azure-dev/pull/8005).

The template provisions a real Logic Apps Standard app on a Workflow Standard
WS1 plan and deploys a stateful HTTP request-response workflow. The workflow and
project structure are based on the official
[Azure/logicapps](https://github.com/Azure/logicapps) repository:

- [`requestresponseworkflow.json`](https://github.com/Azure/logicapps/blob/master/LogicAppsSampleTestFramework/TestCases/TestFiles/requestresponseworkflow.json)
- [`github-sample/logic/host.json`](https://github.com/Azure/logicapps/blob/master/github-sample/logic/host.json)
- [`github-sample/logic/.funcignore`](https://github.com/Azure/logicapps/blob/master/github-sample/logic/.funcignore)

The official sample uses ARM templates. This repository supplies equivalent
minimal Bicep infrastructure so the complete scenario can be tested with
`azd up`.

> [!WARNING]
> The Workflow Standard WS1 plan incurs Azure charges while it exists. Run
> `azd down --purge` when you finish testing.

## Storage authentication limitation

Logic Apps Standard on a normal Workflow Service Plan currently requires
shared-key access to its hosting storage account. The runtime uses the account
for `AzureWebJobsStorage` and an Azure Files content share configured through
`WEBSITE_CONTENTAZUREFILECONNECTIONSTRING`.

The system-assigned managed identity on the logic app can be used by workflows
and connectors, but it does not replace shared-key authentication for this host
storage configuration. Microsoft documents disabling storage account key access
for this scenario only when the logic app runs in an App Service Environment
v3. This small test template intentionally does not provision an ASEv3 because
of its complexity and cost.

If your subscription has a policy that disallows local authentication methods
on storage accounts, `azd up` fails while provisioning the storage account. In
that subscription, use the [package-only test](#test-packaging-without-deploying)
below, or deploy the template in a test subscription that permits shared-key
storage access.

References:

- [Create a Standard workflow in Azure](https://learn.microsoft.com/azure/logic-apps/create-single-tenant-workflows-azure-portal)
- [Standard Logic Apps app and host settings](https://learn.microsoft.com/azure/logic-apps/edit-app-settings-host-settings)
- [Prevent Shared Key authorization for Azure Storage](https://learn.microsoft.com/azure/storage/common/shared-key-authorization-prevent)

## Prerequisites

- Azure Developer CLI 1.28.1 or later
- An Azure subscription
- The preview extension bundle from the upstream-owned test PR

## Install the preview extension

This is an unsigned development build. Install it only if you trust
[Azure/azure-dev#10058](https://github.com/Azure/azure-dev/pull/10058).

```sh
azd ext install "https://azuresdkartifacts.z5.web.core.windows.net/azd/extensions/pr/10058/azure-logicappsstandard.zip"
```

Confirm that the extension is installed:

```sh
azd ext list
```

## Deploy

Initialize a new project from this template:

```sh
mkdir logicappsstandard-test
cd logicappsstandard-test
azd init -t https://github.com/vhvb1989/azd-logicappsstandard-extension-test
```

Authenticate and deploy:

```sh
azd auth login
azd up
```

`azd up` provisions:

- A resource group
- A storage account
- A Workflow Standard WS1 App Service plan
- A Logic Apps Standard `workflowapp`

It then packages `src/workflows` by resolving
`language: logicappsstandard` through the extension and deploys the package to
the workflow app.

## Invoke the workflow

Get the deployed workflow's callback URL:

```sh
subscriptionId="$(azd env get-value AZURE_SUBSCRIPTION_ID)"
resourceGroup="$(azd env get-value AZURE_RESOURCE_GROUP)"
logicAppName="$(azd env get-value SERVICE_WORKFLOWS_NAME)"

callbackUrl="$(
  az rest \
    --method post \
    --uri "https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Web/sites/${logicAppName}/hostruntime/runtime/webhooks/workflow/api/management/workflows/Hello/triggers/manual/listCallbackUrl?api-version=2018-11-01" \
    --query value \
    --output tsv
)"

curl --request POST "$callbackUrl"
```

Expected response:

```text
Hello from Logic Apps!
```

## Test packaging without deploying

The extension can also be tested without creating Azure resources:

```sh
mkdir -p dist
azd package workflows --output-path ./dist/workflows.zip
unzip -t ./dist/workflows.zip
unzip -l ./dist/workflows.zip
```

The archive should contain:

```text
host.json
Hello/workflow.json
```

Files matched by `src/workflows/.funcignore` must not appear in the archive.

## Redeploy a workflow change

Change the message in `src/workflows/Hello/workflow.json`, then deploy only the
workflow service:

```sh
azd deploy workflows
```

Invoke the callback URL again and confirm that the response changed.

## Clean up

```sh
azd down --purge
```

## License and attribution

The source material from `Azure/logicapps` is available under the MIT License.
This repository retains that license and links to the original files above.
