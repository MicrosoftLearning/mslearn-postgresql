---
lab:
    title: 'Assess query performance using Query Store'
    module: 'Tune queries in Azure Database for PostgreSQL'
---

# Assess query performance using Query Store

In this exercise, learn how to query performance metrics using the Query Store in Azure Database for PostgreSQL.

## Before you start

You need your own Azure subscription to complete the exercises in this module. If you don't have an Azure subscription, you can set up a free trial account at [Build in the cloud with an Azure free account](https://azure.microsoft.com/free/).

## Create the exercise environment

### Deploy resources into your Azure subscription

This step guides you through using Azure CLI commands from the Azure Cloud Shell to create a resource group and run a Bicep script to deploy the Azure services necessary for completing this exercise into your Azure subscription.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/).

2. Select the **Cloud Shell** icon in the Azure portal toolbar to open a new [Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) pane at the bottom of your browser window.

    ![Screenshot of the Azure toolbar with the Cloud Shell icon highlighted by a red box.](media/09-portal-toolbar-cloud-shell.png)

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
    az deployment group create --resource-group $RG_NAME --template-file "mslearn-postgresql/Allfiles/Labs/Shared/deploy-postgresql-server.bicep" --parameters adminLogin=pgAdmin adminLoginPassword=$ADMIN_PASSWORD databaseName=adventureworks
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


### Connect to the database with Azure Data Studio

1. Download and install Azure Data Studio from [Download and install Azure Data Studio](/sql/azure-data-studio/download-azure-data-studio).
1. Start Azure Data Studio.
1. Select the **View** menu and select **Extensions**.
1. In **Search Extensions in Marketplace**, type **PostgreSQL** and select **Install**.
1. Select **Connections**.
1. Select **Servers** and select **New connection**.
1. In **Connection type**, select **PostgreSQL**.
1. In **Server name**, type the value that you specified when you deployed the server.
1. In **User name**, type **pgAdmin**.
1. In **Password**, type enter the randomly generated password for the **pgAdmin** login you generated
1. Select **Remember password**.
1. Click **Connect**

### Create tables within the database

1. Either navigate to the folder with your exercise script files, or download the **Lab8_setupTables.sql** from [MSLearn PostgreSQL Labs](https://github.com/MicrosoftLearning/mslearn-postgresql/tree/main/Allfiles/Labs/08).
1. Select **File**, **Open file** and navigate to the folder where you saved the scripts. Select **../Allfiles/Labs/08/Lab8_setupTables** and **Open**. Run the script.
1. Expand **Databases**, right-click **adventureworks** and select **New Query**.
   
    ![Screenshot of adventureworks database highlighting New Query context menu item](media/09-new-query.png)

1. Select the **SQLQuery_1** tab, type the following query and select **Run**.

    ```sql
    SELECT * FROM production.workorder;
    ```

## Task 1: Turn on query capture mode

1. Navigate to the Azure portal and sign in.
1. Select your Azure Database for PostgreSQL server for this exercise.
1. In **Settings**, select **Server parameters**.
1. Navigate to the **pg_qs.query_capture_mode** setting.
1. Select **TOP**.

   ![Screenshot of settings to turn Query Store on](media/09-settings-turn-query-store-on.png)

1. Navigate to **pgms_wait_sampling.query_capture_mode**, select **ALL**, and select **Save**.
   
    ![Screenshot of settings to turn p g m s_wait_sampling.query_capture_mode on](media/09-query-capture-mode.png)
   
1. Wait for the server parameters to update.

## View pg_stat data

1. Start Azure Data Studio.
1. Select **Connect**.
   
    ![Screenshot showing Connect icon](media/09-connect.png)
   
1. Select your PostgreSQL server and select **Connect**.
1. Type each of the following query and select **Run**.

    ```sql
    SELECT * FROM pg_stat_activity;
    ```

1. Review the metrics that are available.
1. Leave Azure Data Studio open for the next task.

## Task 2: Examine query statistics

> [!NOTE]
> For a newly created database, there might be limited statistics, if any. If you wait for 30 minutes there will be statistics from background processes.

1. Select the **azure_sys** database.

    ![Screenshot of the database selector](media/09-database-selector.png)

1. Type each of the following queries and select **Run**.

    ```sql
    SELECT * FROM query_store.query_texts_view;
    ```

    ```sql
    SELECT * FROM query_store.qs_view;
    ```

    ```sql
    SELECT * FROM query_store.runtime_stats_view;
    ```

    ```sql
    SELECT * FROM query_store.pgms_wait_sampling_view;
    ```

1. Review the metrics that are available.

## Exercise Clean-up

The Azure Database for PostgreSQL we deployed in this exercise will incur charges you can delete the server after this exercise. Alternatively, you can delete the **rg-learn-work-with-postgresql-eastus** resource group to remove all resources that we deployed as part of this exercise.
