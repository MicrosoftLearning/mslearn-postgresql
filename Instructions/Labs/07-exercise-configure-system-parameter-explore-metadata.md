---
lab:
    title: 'Configure and manage Azure Database for PostgreSQL Server'
    module: 'Explore PostgreSQL architecture'
---

> [!IMPORTANT]
> You need your own Azure subscription to complete the exercises in this module. If you don't have an Azure subscription, you can set up a free trial account at [Build in the cloud with an Azure free account](https://azure.microsoft.com/free/).

## Create the exercise environment

### Deploy resources into your Azure subscription

This step guides you through using Azure CLI commands from the Azure Cloud Shell to create a resource group and run a Bicep script to deploy the Azure services necessary for completing this exercise into your Azure subscription.

> Note
>
> If you are doing multiple modules in this learning path, you can share the Azure environment between them. In that case, you only need to complete this resource deployment step once.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/).

2. Select the **Cloud Shell** icon in the Azure portal toolbar to open a new [Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) pane at the bottom of your browser window.

    ![Screenshot of the Azure toolbar with the Cloud Shell icon highlighted by a red box.](media/07-portal-toolbar-cloud-shell.png)

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
    az deployment group create --resource-group $RG_NAME --template-file "mslearn-postgresql/Allfiles/Labs/Shared/deploy-postgresql-server.bicep" --parameters restore=false adminLogin=pgAdmin adminLoginPassword=$ADMIN_PASSWORD databaseName=zoodb
    ```

    The Bicep deployment script provisions the Azure services required to complete this exercise into your resource group. The resources deployed are an Azure Database for PostgreSQL - Flexible Server. The bicep script also creates a database - which can be configured on the commandline as a parameter.

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

## Task 1: Explore the vacuum process in PostgreSQL

1. Open Azure Data Studio.
1. Either navigate to the folder with your exercise script files, or download the **Lab7_vacuum.sql** from [MSLearn PostgreSQL Labs](https://github.com/MicrosoftLearning/mslearn-postgresql/Allfiles/Labs/07).
1. Select File, **Open File**, and select **Lab7_vacuum.sql**.Connect to your Azure Database for PostgreSQL flexible server.
1. Highlight and run the section **Check zoodb database is selected**. If necessary, make zoodb the current database using the drop-down list.
1. Highlight and run the section **Display dead tuples**. This query displays the number of dead and live tuples in the database. Make a note of the number of dead tuples.
1. Highlight and run the section **Change weight** several times. This query updates the weight column for all the animals.
1. Run the section under **Display dead tuples** again. Make a note of the number of dead tuples after the updates have been done.
1. Run the section under **Manually run VACUUM** to run the vacuum process.
1. Run the section under **Display dead tuples** again. Make a note of the number of dead tuples after the vacuum process has been run.

## Task 2: Configure autovacuum server parameters

1. In the Azure portal, navigate to your Azure Database for PostgreSQL flexible server.
1. Under **Settings**, select **Server parameters**.
1. In the search bar, type **vacuum**. Find the following parameters, and change the values as follows:
    1. autovacuum = ON (it should be ON by default)
    1. autovacuum_vacuum_scale_factor = 0.1
    1. autovacuum_vacuum_threshold = 50

    This is like running the autovacuum process when 10% of a table has rows marked for deletion, or 50 rows updated or deleted in any one table.

1. Select **Save**. The server is restarted.

## Task 3: View PostgreSQL metadata in the Azure portal

1. Navigate to [the Azure portal](https://portal.azure.com) and sign in.
1. Select **All resources**.

    :::image type="content" source="../media/4-all-resources.png" alt-text="Screenshot of All resources icon.":::
1. Select the Azure Database for PostgreSQL flexible server that you created for this exercise.
1. In **Monitoring**, select **Metrics**.

    :::image type="content" source="../media/4-metrics.png" alt-text="Screenshot of Metrics icon.":::
1. Select **Metric** and select **CPU percent**.
    :::image type="content" source="../media/4-processor-percent.png" alt-text="Screenshot showing Metric selection." lightbox="../media/4-processor-percent.png":::
1. Take note that you can view various metrics about your databases.

## Task 4: View data in system catalog tables

1. Switch to Azure Data Studio.
1. In **SERVERS**, select your PostgreSQL server and wait until a connection is made and a green circle is displayed on the server.

    :::image type="content" source="../media/4-connection.png" alt-text="Screenshot of connected server.":::
1. Right-click the server and select **New Query**.
1. Type the following SQL and select **Run**:

    ```sql
    SELECT datname, xact_commit, xact_rollback FROM pg_stat_database;
    ```

1. Take note that you can view commits and rollbacks for each database.

## Task 3: View a complex metadata query using a system view

1. Right-click the server and select **New Query**.
1. Type the following SQL and select **Run**:

    ```sql
    SELECT *
    FROM pg_catalog.pg_stats;
    ```

1. Take note that you can view a large amount of statistics information.
1. By using system views, you can reduce the complexity of the SQL that you need to write. The previous query would need the following code if you weren't using the **pg_stats** view:

    ```sql
    SELECT n.nspname AS schemaname,
    c.relname AS tablename,
    a.attname,
    s.stainherit AS inherited,
    s.stanullfrac AS null_frac,
    s.stawidth AS avg_width,
    s.stadistinct AS n_distinct,
        CASE
            WHEN s.stakind1 = 1 THEN s.stavalues1
            WHEN s.stakind2 = 1 THEN s.stavalues2
            WHEN s.stakind3 = 1 THEN s.stavalues3
            WHEN s.stakind4 = 1 THEN s.stavalues4
            WHEN s.stakind5 = 1 THEN s.stavalues5
            ELSE NULL::anyarray
        END AS most_common_vals,
        CASE
            WHEN s.stakind1 = 1 THEN s.stanumbers1
            WHEN s.stakind2 = 1 THEN s.stanumbers2
            WHEN s.stakind3 = 1 THEN s.stanumbers3
            WHEN s.stakind4 = 1 THEN s.stanumbers4
            WHEN s.stakind5 = 1 THEN s.stanumbers5
            ELSE NULL::real[]
        END AS most_common_freqs,
        CASE
            WHEN s.stakind1 = 2 THEN s.stavalues1
            WHEN s.stakind2 = 2 THEN s.stavalues2
            WHEN s.stakind3 = 2 THEN s.stavalues3
            WHEN s.stakind4 = 2 THEN s.stavalues4
            WHEN s.stakind5 = 2 THEN s.stavalues5
            ELSE NULL::anyarray
        END AS histogram_bounds,
        CASE
            WHEN s.stakind1 = 3 THEN s.stanumbers1[1]
            WHEN s.stakind2 = 3 THEN s.stanumbers2[1]
            WHEN s.stakind3 = 3 THEN s.stanumbers3[1]
            WHEN s.stakind4 = 3 THEN s.stanumbers4[1]
            WHEN s.stakind5 = 3 THEN s.stanumbers5[1]
            ELSE NULL::real
        END AS correlation,
        CASE
            WHEN s.stakind1 = 4 THEN s.stavalues1
            WHEN s.stakind2 = 4 THEN s.stavalues2
            WHEN s.stakind3 = 4 THEN s.stavalues3
            WHEN s.stakind4 = 4 THEN s.stavalues4
            WHEN s.stakind5 = 4 THEN s.stavalues5
            ELSE NULL::anyarray
        END AS most_common_elems,
        CASE
            WHEN s.stakind1 = 4 THEN s.stanumbers1
            WHEN s.stakind2 = 4 THEN s.stanumbers2
            WHEN s.stakind3 = 4 THEN s.stanumbers3
            WHEN s.stakind4 = 4 THEN s.stanumbers4
            WHEN s.stakind5 = 4 THEN s.stanumbers5
            ELSE NULL::real[]
        END AS most_common_elem_freqs,
        CASE
            WHEN s.stakind1 = 5 THEN s.stanumbers1
            WHEN s.stakind2 = 5 THEN s.stanumbers2
            WHEN s.stakind3 = 5 THEN s.stanumbers3
            WHEN s.stakind4 = 5 THEN s.stanumbers4
            WHEN s.stakind5 = 5 THEN s.stanumbers5
            ELSE NULL::real[]
        END AS elem_count_histogram
    FROM pg_statistic s
     JOIN pg_class c ON c.oid = s.starelid
     JOIN pg_attribute a ON c.oid = a.attrelid AND a.attnum = s.staattnum
     LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE NOT a.attisdropped AND has_column_privilege(c.oid, a.attnum, 'select'::text) AND (c.relrowsecurity = false OR NOT row_security_active(c.oid));
    ```

## Task 5: Exercise Clean-up

The Azure Database for PostgreSQL we deployed in this exercise will incur charges you can delete the server after this exercise. Alternatively, you can delete the **rg-learn-work-with-postgresql-eastus** resource group to remove all resources that we deployed as part of this exercise.
