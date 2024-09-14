---
lab:
    title: 'Execute the EXPLAIN statement'
    module: 'Understand PostgreSQL query processing'
---

# Execute the EXPLAIN statement

In this exercise, you look at the EXPLAIN function and how it can display the execution plan that the PostgreSQL planner generates for a supplied statement.

## Before you start

You need your own Azure subscription to complete this exercise. If you do not have an Azure subscription, you can create an [Azure free trial](https://azure.microsoft.com/free).

## Create the exercise environment

In this exercise and all later exercises you will use Bicep in the Azure Cloud Shell to deploy your PostgreSQL server.
Skip deploying resources and installing Azure Data Studio if you have already have these installed.

### Deploy resources into your Azure subscription

This step guides you through using Azure CLI commands from the Azure Cloud Shell to create a resource group and run a Bicep script to deploy the Azure services necessary for completing this exercise into your Azure subscription.

> Note
>
> If you are doing multiple modules in this learning path, you can share the Azure environment between them. In that case, you only need to complete this resource deployment step once.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/).

2. Select the **Cloud Shell** icon in the Azure portal toolbar to open a new [Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) pane at the bottom of your browser window.

    ![Screenshot of the Azure toolbar with the Cloud Shell icon highlighted by a red box.](media/03-portal-toolbar-cloud-shell.png)

    If prompted, select the required options to open a *Bash* shell. If you have previously used a *PowerShell* console, switch it to a *Bash* shell.

3. At the Cloud Shell prompt, enter the following to clone the GitHub repo containing exercise resources:

    ```bash
    git clone https://github.com/MicrosoftLearning/mslearn-postgresql.git
    ```

4. Next, you run three commands to define variables to reduce redundant typing when using Azure CLI commands to create Azure resources. The variables represent the name to assign to your resource group (`RG_NAME`), the Azure region (`REGION`) into which resources will be deployed, and a randomly generated password for the PostgreSQL administrator login (`ADMIN_PASSWORD`).

    In the first command, the region assigned to the corresponding variable is `eastus`, but you can also replace it with a location of your preference.

    ```bash
    REGION=eastus
    ```

    The following command assigns the name to be used for the resource group that will house all the resources used in this exercise. The resource group name assigned to the corresponding variable is `rg-learn-work-with-postgresql-$REGION`, where `$REGION` is the location you specified above. However, you can change it to any other resource group name that suits your preference.

    ```bash
    RG_NAME=rg-learn-work-with-postgresql-$REGION
    ```

    The final command randomly generates a password for the PostgreSQL admin login. Make sure you copy it to a safe place so that you can use it later to connect to your PostgreSQL flexible server.

    ```bash
    a=()
    for i in {a..z} {A..Z} {0..9}; 
       do
       a[$RANDOM]=$i
    done
    ADMIN_PASSWORD=$(IFS=; echo "${a[*]::18}")
    echo "Your randomly generated PostgreSQL admin user's password is:"
    echo $ADMIN_PASSWORD
    ```

5. If you have access to more than one Azure subscription, and your default subscription is not the one in which you want to create the resource group and other resources for this exercise, run this command to set the appropriate subscription, replacing the `<subscriptionName|subscriptionId>` token with either the name or ID of the subscription you want to use:

    ```azurecli
    az account set --subscription <subscriptionName|subscriptionId>
    ```

6. Run the following Azure CLI command to create your resource group:

    ```azurecli
    az group create --name $RG_NAME --location $REGION
    ```

7. Finally, use the Azure CLI to execute a Bicep deployment script to provision Azure resources in your resource group:

    ```azurecli
    az deployment group create --resource-group $RG_NAME --template-file "mslearn-postgresql/Allfiles/Labs/Shared/deploy-postgresql-server.bicep" --parameters adminLogin=pgAdmin adminLoginPassword=$ADMIN_PASSWORD
    ```

    The Bicep deployment script provisions the Azure services required to complete this exercise into your resource group. The resources deployed are an Azure Database for PostgreSQL - Flexible Server. The bicep script also creates a database - which can be configured on the commandline as a parameter.

    The deployment typically takes several minutes to complete. You can monitor it from the Cloud Shell or navigate to the **Deployments** page for the resource group you created above and observe the deployment progress there.

8. Close the Cloud Shell pane once your resource deployment is complete.

### Troubleshooting deployment errors

You may encounter a few errors when running the Bicep deployment script. The most common messages and the steps to resolve them are:

- If you previously ran the Bicep deployment script for this learning path and subsequently deleted the resources, you may receive an error message like the following if you are attempting to rerun the script within 48 hours of deleting the resources:

    ```bash
    {"code": "InvalidTemplateDeployment", "message": "The template deployment 'deploy' is not valid according to the validation procedure. The tracking id is '4e87a33d-a0ac-4aec-88d8-177b04c1d752'. See inner errors for details."}
    
    Inner Errors:
    {"code": "FlagMustBeSetForRestore", "message": "An existing resource with ID '/subscriptions/{subscriptionId}/resourceGroups/rg-learn-postgresql-ai-eastus/providers/Microsoft.CognitiveServices/accounts/{accountName}' has been soft-deleted. To restore the resource, you must specify 'restore' to be 'true' in the property. If you don't want to restore existing resource, please purge it first."}
    ```

    If you receive this message, modify the `azure deployment group create` command above to set the `restore` parameter equal to `true` and rerun it.

- If the selected region is restricted from provisioning specific resources, you must set the `REGION` variable to a different location and rerun the commands to create the resource group and run the Bicep deployment script.

    ```bash
    {"status":"Failed","error":{"code":"DeploymentFailed","target":"/subscriptions/{subscriptionId}/resourceGroups/{resourceGrouName}/providers/Microsoft.Resources/deployments/{deploymentName}","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.","details":[{"code":"ResourceDeploymentFailure","target":"/subscriptions/{subscriptionId}/resourceGroups/{resourceGrouName}/providers/Microsoft.DBforPostgreSQL/flexibleServers/{serverName}","message":"The resource write operation failed to complete successfully, because it reached terminal provisioning state 'Failed'.","details":[{"code":"RegionIsOfferRestricted","message":"Subscriptions are restricted from provisioning in this region. Please choose a different region. For exceptions to this rule please open a support request with Issue type of 'Service and subscription limits'. See https://review.learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-request-quota-increase for more details."}]}]}}
    ```

- If the script is unable to create an AI resource due to the requirement to accept the responsible AI agreement, you may experience the following error; in which case use the Azure Portal user interface to create an Azure AI Services resource, and then re-run the deployment script.

    ```bash
    {"code": "InvalidTemplateDeployment", "message": "The template deployment 'deploy' is not valid according to the validation procedure. The tracking id is 'f8412edb-6386-4192-a22f-43557a51ea5f'. See inner errors for details."}
     
    Inner Errors:
    {"code": "ResourceKindRequireAcceptTerms", "message": "This subscription cannot create TextAnalytics until you agree to Responsible AI terms for this resource. You can agree to Responsible AI terms by creating a resource through the Azure Portal then trying again. For more detail go to https://go.microsoft.com/fwlink/?linkid=2164190"}
    ```

## Before you continue

Make sure you have:

1. You have installed and started Azure Database for PostgreSQL flexible server. This should have been installed by the previous Bicep script.
1. You have already cloned the lab scripts from [PostgreSQL Labs](https://github.com/MicrosoftLearning/mslearn-postgresql.git). If you haven't done so, clone the repository locally:
    1. Open a command line/terminal.
    1. Run the command:
       ```bash
       md .\DP3021Lab
       git clone https://github.com/MicrosoftLearning/mslearn-postgresql.git .\DP3021Lab
       ```
       > NOTE
       > 
       > If **git** is not installed, [download and install the ***git*** app](https://git-scm.com/download) and try running the previous commands again.
1. You have installed Azure Data Studio. If you haven't then [download and install ***Azure Data Studio***](https://go.microsoft.com/fwlink/?linkid=2282284).
1. Install the **PostgreSQL** extension in Azure Data Studio.
1. Open Azure Data Studio and connect to your Azure Database for PostgreSQL flexible server created by the Bicep script. Enter the user name **pgAdmin** and password **the random admin password** you previously created.
1. If you haven't created the zoodb database yet, select **File**, **Open file** and navigate to the folder where you saved the scripts. Select **../Allfiles/Labs/02/Lab2_ZooDb.sql** and **Open**.
   1. Highlight the **DROP** and **CREATE** statements and run them.
   1. At the top of the screen, use the drop-down arrow to display the databases on the server, including zoodb and system databases. Select the **zoodb** database.
   1. Highlight the **Create tables**, **Create foreign keys**, and **Populate tables** sections and run them.
   1. Highlight the 3 **SELECT** statements at the end of the script and run them to verify that the tables were created and populated.

## Practice EXPLAIN ANALYZE

1. In the [Azure portal](https://portal.azure.com), navigate to your Azure Database for PostgreSQL flexible server. Check the server is started or restart it if necessary.
1. Open Azure Data Studio and connect to your Azure Database for PostgreSQL flexible server.
1. Select **File**, **Open File**, and navigate to the folder where you saved the scripts. Open **../Allfiles/Labs/03/Lab3_RepopulateZoo.sql**. Reconnect to the server if necessary.
1. Select **Run** to execute the query. This repopulates the zoodb database.
1. Select File, **Open File**, and select **../Allfiles/Labs/03/Lab3_explain.sql**.
1. In the Lab file, in the section **1. Investigate EXPLAIN ANALYZE** highlight and run Statement A and Statement B separately.
    1. Which statement updated the database, and why?
    1. How many milliseconds did it take to plan Statement A?
    1. What was the execution time for Statement B?

## Practice EXPLAIN

1. In the Lab file, in the section **2. Investigate EXPLAIN** highlight and run that statement.
    1. What sort key was used, and why?
1. In the Lab file, in the section **3. Investigate EXPLAIN options** highlight and run each statement separately. Compare the query plan statistics for each option.

## Clean-up

1. Delete the resource group created in this exercise to avoid incurring unnecessary Azure costs.
1. If needed, delete the **.\DP3021Lab** folder.

