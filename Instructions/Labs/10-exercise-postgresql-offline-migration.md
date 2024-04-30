---
lab:
    title: 'Offline PostgreSQL Database Migration'
    module: 'Migrate to Azure Database for PostgreSQL Flexible Server'
---

# Offline PostgreSQL Database Migration

In this exercise, you'll create an Azure Database for PostgreSQL flexible server and perform an offline database migration from an on-premises PostgreSQL server using the Migration feature within the Azure Database for PostgreSQL Flexible Server.

## Before you start

> [!IMPORTANT]
> You need your own Azure subscription to complete this exercise. If you don't have an Azure subscription, you can create an [Azure free trial](https://azure.microsoft.com/free).

> [!NOTE]
> You will need access to an existing PostgreSQL server with a database and appropriate permissions and network access to complete this exercise.
> The maximum supported version of PostgreSQL for migration is version 16.

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
    az deployment group create --resource-group $RG_NAME --template-file "mslearn-postgresql/Allfiles/Labs/Shared/deploy-postgresql-server.bicep" --parameters restore=false adminLogin=pgAdmin adminLoginPassword=$ADMIN_PASSWORD databaseName=adventureworks
    ```

    The Bicep deployment script provisions the Azure services required to complete this exercise into your resource group. The resource deployed is an Azure Database for PostgreSQL - Flexible Server.

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

## Create a database for migration

Now we need to setup the database which you will migrate to the Azure Database for PostgreSQL Flexible Server. This step needs to be completed on your source PostgreSQL Server instance, this instance will need to be accessible to the Azure Database for PostgreSQL Flexible Server in order to complete this lab.

First of all we need to create an empty database which we will create a table and then load it with data. Firs of all you will need to download the Lab10_setupTable.sql and Lab10_workorder.csv files from the repository [here](https://github.com/MicrosoftLearning/mslearn-postgresql/tree/main/Allfiles/Labs/10) to C:\.
Once you have these file we can create the database using the following command, replace the values for host, port, and username as required for your instance of PostgreSQL.

```bash
psql --host=localhost --port=5432 --username=pgadmin --command="CREATE DATABASE adventureworks;"
```

Now we can create the table and load the data into it using the following commands.

```bash
psql --host=localhost --port=5432 --username=pgadmin --command="CREATE DATABASE adventureworks;"
```

Run the following command to create the `production.workorder` table for loading in data:

```sql
    DROP SCHEMA IF EXISTS production CASCADE;
    CREATE SCHEMA production;
    
    DROP TABLE IF EXISTS production.workorder;
    CREATE TABLE production.workorder
    (
        workorderid integer NOT NULL,
        productid integer NOT NULL,
        orderqty integer NOT NULL,
        scrappedqty smallint NOT NULL,
        startdate timestamp without time zone NOT NULL,
        enddate timestamp without time zone,
        duedate timestamp without time zone NOT NULL,
        scrapreasonid smallint,
        modifieddate timestamp without time zone NOT NULL DEFAULT now()
    )
    WITH (
        OIDS = FALSE
    )
    TABLESPACE pg_default;
    ALTER TABLE production.workorder OWNER to pgAdmin;
```

```sql
psql --host=localhost --port=5432 --username=postgres --dbname=adventureworks --command="\COPY production.workorder FROM 'C:\Lab10_workorder.csv' CSV HEADER"
```

The command output should be `COPY 72591`, indicating that 72591 rows were written into the table from the CSV file.

## Pre-Migration

Prior to starting the offline migration of the database from the source server, we need to ensure that the target server is configured and ready.

1. Migrate users and roles from the source server to the new flexible server. This can be achieved using the pg_dumpall tool with the following code.
    1. Superuser roles are not supported on Azure Database for PostgreSQL so any users with these privileges should have them removed before migration.

```bash
pg_dumpall --globals-only -U <<username>> -f <<filename>>.sql
```

1. Match server parameter values from the source server on the target server.
1. Disable High Availability and Read Replicas on the target.

## Create Database Migration Project in Azure Database for PostgreSQL Flexible Server

1. Select **Migration** from the menu on the left of the flexible server blade.
    [![Azure Database for PostgreSQL Flexible Server migration option.]](./media/10-pgflex-migation.png)
1. Click on the **+ Create** option at the top of the **Migration** blade.
1. On the **Setup** tab, enter each field as follows:
    1. Migration name - Migration-AdventureWorks.
    1. Source server type - On-premise Server.
    1. Migration option - Validate and Migrate.
    1. Select **Next: Connect to source >**.
    [![Setup offline database migration for Azure Database for PostgreSQL Flexible Server.]](./media/10-pgflex-migation-setup.png)
1. On the **Connect to source** tab, enter each field as follows:
    1. Server name - The name of your server that you are using as the source.
    1. Port - The port that your instance of PostgreSQL is using on your source server (default of 5432).
    1. Server admin login name - The name of an admin user for your PostgreSQL instance.
    1. Password - The password for the PostgreSQL admin user you specified in the previous step.
    1. SSL mode - Prefer.
    1. Click on the **Connect to source** option to validate the connectivity details provided.
    1. Click on the **Next: Select migration target** button to progress.
    [![Setup source connection for Azure Database for PostgreSQL Flexible Server migration.]](./media/10-pgflex-migation-source.png)
1. The connectivity details should be automatically completed for the target server we are migrating to.
    1. Provide the password for the demo user we specified when creating the flexible server earlier.
        1. In the password filed - Pa$$w0rd.
    1. Click on the **Connect to target** option to validate the connectivity details provided.
    1. Click on the **Next : Select database(s) for migration >** button to progress.
1. On the **Select database(s) for migration** tab, select the databases from the source server you want to migrate to the flexible server.
    [![Select database(s) for Azure Database for PostgreSQL Flexible Server migration.]](./media/10-pgflex-migation-dbSelection.png)
1. Click on the **Next : Summary >** button to progress and review the data provided.
1. On the **Summary** tab review the information and then click the **Start Validation and Migration** button to start the migration to the flexible server.
1. On the **Migration** tab you can monitor the migration progress by using the **Refresh** button in the top menu of the tab to view the progress through the validation and migration process.
    1. By clicking on the **Migration-AdventureWorks** activity you can view the detailed information about the progress of the migration activity.

Once the migration process is complete then we can perform post-migration tasks such as data validation in the new database, configuring high-availability before pointing the application at the database and turning it on again.

## Exercise Clean-up

The Azure Database for PostgreSQL we deployed in this exercise will incur charges you can delete the server after this exercise. Alternatively, you can delete the **rg-learn-work-with-postgresql-eastus** resource group to remove all resources that we deployed as part of this exercise.