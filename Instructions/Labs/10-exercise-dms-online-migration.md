---
uid: learn.wwl.exercise-online-postgresql-database-migration
title: Exercise – Online PostgreSQL Database Migration
description: Exercise – Online PostgreSQL Database Migration
durationInMinutes: 20
---
> [!IMPORTANT]
> You need your own Azure subscription to complete this exercise. If you don't have an Azure subscription, you can create an [Azure free trial](https://azure.microsoft.com/free).

In this exercise, you'll create an Azure Database for PostgreSQL flexible server and perform an online database migration from an on-premises PostgreSQL server using the Database Migration Service.

> [!NOTE]
> You will need access to an existing PostgreSQL server with a database and appropriate permissions and network access to complete this exercise. Details related to the configuration options which need to be in place to allow for Database Migration Service to perform an online migration can be found in the article [Known issues/limitations with online migrations from PostgreSQL to Azure Database for PostgreSQL](https://learn.microsoft.com/en-us/azure/dms/known-issues-azure-postgresql-online).
>
> The maximum supported version of PostgreSQL for migration is version 14.

### Deploy resources into your Azure subscription

This step guides you through using Azure CLI commands from the Azure Cloud Shell to create a resource group and run a Bicep script to deploy the Azure services necessary for completing this exercise into your Azure subscription.

> Note
>
> If you are doing multiple modules in this learning path, you can share the Azure environment between them. In that case, you only need to complete this resource deployment step once.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/).

2. Select the **Cloud Shell** icon in the Azure portal toolbar to open a new [Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) pane at the bottom of your browser window.

    ![Screenshot of the Azure toolbar with the Cloud Shell icon highlighted by a red box.](media/11-portal-toolbar-cloud-shell.png)

3. At the Cloud Shell prompt, enter the following to clone the GitHub repo containing exercise resources:

    ```bash
    git clone https://github.com/MicrosoftLearning/mslearn-postgresql.git
    ```

4. Next, you run three commands to define variables to reduce redundant typing when using Azure CLI commands to create Azure resources. The variables represent the name to assign to your resource group (`RG_NAME`), the Azure region (`REGION`) into which resources will be deployed, and a randomly generated password for the PostgreSQL administrator login (`ADMIN_PASSWORD`).

    In the first command, the region assigned to the corresponding variable is `eastus`, but you can also replace it with a location of your preference. However, if replacing the default, you must select another [Azure region that supports abstractive summarization](https://learn.microsoft.com/azure/ai-services/language-service/summarization/region-support) to ensure you can complete all of the tasks in the modules in this learning path.

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
    az deployment group create --resource-group $RG_NAME --template-file "mslearn-postgresql/Allfiles/Labs/Shared/deploy-postgresql-server.bicep" --parameters restore=false adminLogin=pgAdmin adminLoginPassword=$ADMIN_PASSWORD postgresVersion=14
    ```

    The Bicep deployment script provisions the Azure services required to complete this exercise into your resource group. The resource deployed is an Azure Database for PostgreSQL - Flexible Server - version 14 as this is the maximum allowed for the Database Migraiton Service.

    The deployment typically takes several minutes to complete. You can monitor it from the Cloud Shell or navigate to the **Deployments** page for the resource group you created above and observe the deployment progress there.

    You may encounter a few errors when running the Bicep deployment script. The most common messages and the steps to resolve them are:

    - If you previously ran the Bicep deployment script for this learning path and subsequently deleted the resources, you may receive an error message like the following if you are attempting to rerun the script within 48 hours of deleting the resources:

        ```bash
        {"code": "InvalidTemplateDeployment", "message": "The template deployment 'deploy' is not valid according to the validation procedure. The tracking id is '4e87a33d-a0ac-4aec-88d8-177b04c1d752'. See inner errors for details."}
    
        Inner Errors:
        {"code": "FlagMustBeSetForRestore", "message": "An existing resource with ID '/subscriptions/{subscriptionId}/resourceGroups/rg-learn-postgresql-ai-eastus/providers/Microsoft.CognitiveServices/accounts/{accountName}' has been soft-deleted. To restore the resource, you must specify 'restore' to be 'true' in the property. If you don't want to restore existing resource, please purge it first."}
        ```

        If you receive this message, modify the `azure deployment group create` command above to set the `restore` parameter equal to `true` and rerun it.

    - If the selected region is restricted from provisioning specific resources, you must set the `REGION` variable to a different location and rerun the Bicep deployment script.

        ```bash
        {"status":"Failed","error":{"code":"DeploymentFailed","target":"/subscriptions/{subscriptionId}/resourceGroups/{resourceGrouName}/providers/Microsoft.Resources/deployments/{deploymentName}","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.","details":[{"code":"ResourceDeploymentFailure","target":"/subscriptions/{subscriptionId}/resourceGroups/{resourceGrouName}/providers/Microsoft.DBforPostgreSQL/flexibleServers/{serverName}","message":"The resource write operation failed to complete successfully, because it reached terminal provisioning state 'Failed'.","details":[{"code":"RegionIsOfferRestricted","message":"Subscriptions are restricted from provisioning in this region. Please choose a different region. For exceptions to this rule please open a support request with Issue type of 'Service and subscription limits'. See https://review.learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-request-quota-increase for more details."}]}]}}
        ```

8. Close the Cloud Shell pane once your resource deployment is complete.

## Create a test database for migration

The AdventureWorks sample database for PostgreSQL can be found [here](../dbBackup/) for download and can be used for this migration exercise. You can restore the database from the tar file using the following command and supplying the values for your specific server details.

```bash

pg_restore.exe --verbose --clean --no-acl --no-owner --host=<<Servename>> --port=<<Instance Port>> --username=<<Username>> --dbname=adventureworks "<Path to file>\adventureworks.tar"

```

## Migrate the Database Schema

1. Under Azure services, select **Resource Groups**, then select the resource group **rg-learn-work-with-postgresql-eastus**, then select the Azure Database for PostgreSQL Flexible server we created earlier in this exercise.
    1. Select **Databases** under the Azure Database for PostgreSQL Flexible Server.
    1. Click **+ Add** then enter the database name of the database you want to migrate.
    1. Click **save** to create and empty database on the Azure Database for PostgreSQL Flexible Server.
1. Connect to your on-premises PostgreSQL server and use pg_dump to export the database schema from the source database using the following command.
    1. Replace the values as appropriate for your server and database system.

``` Bash

pg_dump -O --host=localhost --port=5432 --username=adminuser --dbname=adventureworks --schema-only > adventureworks.sql

```

1. Now import the schema into a new database on our Azure Database for PostgreSQL flexible server using the following command.
    1. Replace the values as appropriate for your server and database system.

``` Bash

psql --host=<your database name>.postgres.database.azure.com --username=demo --dbname=adventureworks < adventureworks.sql

```

## Create an Azure Database Migration Service

> [!NOTE]
> PostgreSQL migration projects are only supported on Premium SKU Migration Services.

1. Under Azure services, select **+ Create a resource**. Under **Categories**, select **Migration**. Under **Azure Database Migration Service**, select **Create**.
1. On the **Select migration scenario and Database Migration Service** tab, enter each field as follows:
    1. Source Server Type - PostgreSQL.
    1. Target Server Type - Azure Database for PostgreSQL.
    1. Database Migration Service - Database Migration Service (classic).
1. Click the **Select** button.
1. On the **Create Migration Service** tab, enter each field as follows:
    1. Subscription - your subscription.
    1. Resource Group - **rg-learn-work-with-postgresql-eastus**.
    1. Migration Service Name - **dms-mslearn-pgsql-1**.
    1. Location - select the same region as the resource group.
    1. Service mode - **Azure**.
    1. Pricing Tier - **Standard**. Select **Configure Tier** and examine the configuration options. Select the **Premium** option and click **Apply**.
1. On the Create Migration Service **Networking** tab, enter each field as follows:
    1. Do not select an existing virtual network if any are listed.
    1. Virtual network name - **vnet-mslearn-pgsql-1**.
1. Select **Review + create**. Review your settings, then select **Create** to create your Azure Database migration service. When the deployment is complete, select **Go to resource** ready for the next step.

## Create a Database Migration Project

1. In the Database Migration Service resource **dms-mslearn-pgsql-1** select **New Migration project**, enter each field as follows:
    1. Project Name - AdventureWorks-Migration.
    1. Source server Type - PostgreSQL.
    1. Target server type - Azure Database for PostgreSQL.
    1. Migration activity type - Online data migration.
1. Click on the **Create and run activity** button.
1. In the **Select source** section provide the following values depending on your environment configuration.
    1. Source server name - The hostname of the server with the database you want to migrate.
    1. Server port - The port your source server is listening on for the PostgreSQL instance containing the database you want to migrate.
    1. Database - The name of the database you are going to migrate.
    1. User Name - The name of a user on the source server with the authorization required to access the source server.
    1. Password - The password of the user used in the previous field.
1. click on **select Target** and the information you have provided will be verified and if there are any issues you will receive the relevant notification.
1. In the **Select Target** section enter each field as follows:
    1. Subscription - your subscription.
    1. Azure PostgreSQL - the Azure Database for PostgreSQL Flexible server we created earlier.
    1. Database - the name of the database created created earlier which will be migrated.
    1. Username - demo
    1. Password - Pa$$w0rd
1. Select **Next : Select databases > >** to validate the input and progress to the next step.
1. In the **Select Databases** section enter each field as follows:
    1. Check the box beside the source database you want to migrate.
    1. From the dropdown select the database we created on the Azure Database for PostgreSQL Flexible Server earlier.
1. Click the **Select Databases** button to validate and proceed.
1. Expand the database and ensure that all the tables you want to migrate are selected.
1. Click the **Next: Configure migration settings > >** button to proceed.
1. In the **Configure migration settings** section.
    1. Expand the database and then the **Advanced online migration settings** section.
    1. Review the configured value and do not change anything.
1. Click the **Next: Summary > >** button to proceed.
1. In the **Summary** section enter the fields as follows:
    1. Activity name - Database-Migration.
1. Review the configuration details entered through the creation process and make sure they are correct.
1. Click the **Start migration** button to initiate the migration activity.
1. On the **Database-Migration** pane you can use the **Refresh** button on the top left of the blade to update the status information for the activity to review the current status.

## Perform Migration Cutover

Once the **Migration details** column in the migration activity has a status of **Ready to cutover** for the database we want to migrate, we can complete the migration activity.

1. Click on the database name to view the details of the migration activity.
    1. Review the details here to see how many tables have been migrated as well as any updates applied and pending changes.
1. Click the **Start Cutover** button in the top left of the blade.
    1. In the **Complete cutover** notification area that appears ensure there are no pending changes.
    1. Check the **Confirm** checkbox.
    1. Click on the **Apply** button to complete the cutover activity.
    1. Monitor the progress bar that appears and close the **Complete Cutover** notification blade once it is **Completed**.
1. Close the database activity blade to return to the **Database-Migration** blade and review the details now that the migration activity has been completed.

Now that the migration has been completed we would perform post-migration tasks related to the source database and database updates that needed to be completed such as recreating sequences or updating the database schema to remove temporary changes.

## Exercise Clean-up

The Azure Database for PostgreSQL we deployed in this exercise will incur charges you can delete the server after this exercise. Alternatively, you can delete the **rg-learn-work-with-postgresql-eastus** resource group to remove all resources that we deployed as part of this exercise.
