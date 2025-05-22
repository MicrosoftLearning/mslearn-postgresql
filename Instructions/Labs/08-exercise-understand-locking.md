---
lab:
    title: 'Understand locking'
    module: 'Understand concurrency in PostgreSQL'
---

# Understand locking

In this exercise, you look at system parameters and metadata in PostgreSQL.

## Before you start

You need your own Azure subscription to complete this exercise. If you don't have an Azure subscription, you can create an [Azure free trial](https://azure.microsoft.com/free).

Additionally, you need to have the following installed on your computer:

- Visual Studio Code.
- Postgres Visual Studio Code Extension by Microsoft.
- Azure CLI.
- Git.

## Create the exercise environment

In this and later exercises, you use a Bicep script to deploy the Azure Database for PostgreSQL - Flexible Server and other resources into your Azure subscription. The Bicep scripts are located in the `/Allfiles/Labs/Shared` folder of the GitHub repository you cloned earlier.

### Download and install Visual Studio Code and the PostgreSQL extension

If you don't have Visual Studio Code installed:

1. In a browser, navigate to [Download Visual Studio Code](https://code.visualstudio.com/download) and select the appropriate version for your operating system.

1. Follow the installation instructions for your operating system.

1. Open Visual Studio Code.

1. From the left menu, select **Extensions** to display the Extensions panel.

1. In the search bar, enter **PostgreSQL**. The PostgreSQL extension for Visual Studio Code icon is displayed. Make sure you select the one by Microsoft.

1. Select **Install**. The extension installs.

### Download and install Azure CLI and Git

If you don't have Azure CLI or Git installed:

1. In a browser, navigate to [Install the Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) and follow the instructions for your operating system.

1. In a browser, navigate to [Download and install Git](https://git-scm.com/downloads) and follow the instructions for your operating system.

### Download the exercise files

If you already cloned the GitHub repository containing the exercise files, *Skip downloading the exercise files*.

To download the exercise files, you clone the GitHub repository containing the exercise files to your local machine. The repository contains all the scripts and resources you need to complete this exercise.

1. Open Visual Studio Code if it isn't already open.

1. Select **Show all commands** (Ctrl+Shift+P) to open the command palette.

1. In the command palette, search for **Git: Clone** and select it.

1. In the command palette, enter the following to clone the GitHub repo containing exercise resources and press **Enter**:

    ```bash
    https://github.com/MicrosoftLearning/mslearn-postgresql.git
    ```

1. Follow the prompts to select a folder to clone the repository into. The repository is cloned into a folder named `mslearn-postgresql` in the location you selected.

1. When asked if you want to open the cloned repository, select **Open**. The repository opens in Visual Studio Code.

### Deploy resources into your Azure subscription

If your Azure resources are already installed, *Skip deploying resources*.

This step guides you through using Azure CLI commands from Visual Studio Code to create a resource group and run a Bicep script to deploy the Azure services necessary for completing this exercise into your Azure subscription.

> &#128221; If you are doing multiple modules in this learning path, you can share the Azure environment between them. In that case, you only need to complete this resource deployment step once.

1. Open Visual Studio Code if it isn't already open, and open the folder where you cloned the GitHub repository.

1. Expand the **mslearn-postgresql** folder in the Explorer pane.

1. Expand the **Allfiles/Labs/Shared** folder.

1. Right-click the **Allfiles/Labs/Shared** folder and select **Open in Integrated Terminal**. This selection opens a terminal window at in the Visual Studio Code window.

1. The terminal might open a **powershell** window by default. For this section of the lab, you want to use the **bash shell**. Besides the **+** icon, there's a dropdown arrow. Select it and select **Git Bash** or **Bash** from the list of available profiles. This selection opens a new terminal window with the **bash shell**.

    > &#128221; You can close the **powershell** terminal window if you want to, but it is not necessary. You can have multiple terminal windows open at the same time.

1. In the terminal window, run the following command to sign-in to your Azure account:

    ```bash
    az login
    ```

    This command opens a new browser window prompting you to sign-in to your Azure account. After logging in, return to the terminal window.

1. Next, you run three commands to define variables to reduce redundant typing when using Azure CLI commands to create Azure resources. The variables represent the name to assign to your resource group (`RG_NAME`), the Azure region (`REGION`) into which resources are deployed, and a randomly generated password for the PostgreSQL administrator sign-in (`ADMIN_PASSWORD`).

    In the first command, the region assigned to the corresponding variable is `eastus`, but you can also replace it with a location of your preference.

    ```bash
    REGION=eastus
    ```

    The following command assigns the name to be used for the resource group that houses all the resources used in this exercise. The resource group name assigned to the corresponding variable is `rg-learn-work-with-postgresql-$REGION`, where `$REGION` is the location you previously specified. *However, you can change it to any other resource group name that suits your preference or that you might already have*.

    ```bash
    RG_NAME=rg-learn-work-with-postgresql-$REGION
    ```

    The final command randomly generates a password for the PostgreSQL admin sign-in. Make sure you copy it to a safe place so that you can use it later to connect to your PostgreSQL flexible server.

    ```bash
    #!/bin/bash
    
    # Define array of allowed characters explicitly
    chars=( {a..z} {A..Z} {0..9} '!' '@' '#' '$' '%' '^' '&' '*' '(' ')' '_' '+' )
    
    a=()
    for ((i = 0; i < 100; i++)); do
        rand_char=${chars[$RANDOM % ${#chars[@]}]}
        a+=("$rand_char")
    done
    
    # Join first 18 characters without delimiter
    ADMIN_PASSWORD=$(IFS=; echo "${a[*]:0:18}")
    
    echo "Your randomly generated PostgreSQL admin user's password is:"
    echo "$ADMIN_PASSWORD"
    echo "Please copy it to a safe place, as you will need it later to connect to your PostgreSQL flexible server."
    ```

1. (Skip if using your default subscription.) If you have access to more than one Azure subscription, and your default subscription *isn't* the one in which you want to create the resource group and other resources for this exercise, run this command to set the appropriate subscription, replacing the `<subscriptionName|subscriptionId>` token with either the name or ID of the subscription you want to use:

    ```azurecli
    az account set --subscription 16b3c013-d300-468d-ac64-7eda0820b6d3
    ```

1. (Skip if you're using an existing resource group) Run the following Azure CLI command to create your resource group:

    ```azurecli
    az group create --name $RG_NAME --location $REGION
    ```

1. Finally, use the Azure CLI to execute a Bicep deployment script to provision Azure resources in your resource group:

    ```azurecli
    az deployment group create --resource-group $RG_NAME --template-file "Allfiles/Labs/Shared/deploy-postgresql-server.bicep" --parameters adminLogin=pgAdmin adminLoginPassword=$ADMIN_PASSWORD databaseName=adventureworks
    ```

    The Bicep deployment script provisions the Azure services required to complete this exercise into your resource group. The resources deployed are an Azure Database for PostgreSQL - Flexible Server. The bicep script also creates the adventureworks database.

    The deployment typically takes several minutes to complete. You can monitor it from the bash terminal or navigate to the **Deployments** page for the resource group you previously created and observe the deployment progress there.

1. Since the script creates a random name for the PostgreSQL server, you can find the name of the server by running the following command:

    ```azurecli
    az postgres flexible-server list --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" --output table
    ```

    Write down the name of the server, as you need it to connect to the server later in this exercise.

    > &#128221; You can also find the name of the server in the Azure portal. In the Azure portal, navigate to **Resource groups** and select the resource group you previously created. The PostgreSQL server is listed in the resource group.

### Troubleshooting deployment errors

You might encounter a few errors when running the Bicep deployment script. The most common messages and the steps to resolve them are:

- If you previously ran the Bicep deployment script for this learning path and then deleted the resources, you might receive an error message like the following if you're attempting to rerun the script within 48 hours of deleting the resources:

    ```bash
    {"code": "InvalidTemplateDeployment", "message": "The template deployment 'deploy' is not valid according to the validation procedure. The tracking id is '4e87a33d-a0ac-4aec-88d8-177b04c1d752'. See inner errors for details."}
    
    Inner Errors:
    {"code": "FlagMustBeSetForRestore", "message": "An existing resource with ID '/subscriptions/{subscriptionId}/resourceGroups/rg-learn-postgresql-ai-eastus/providers/Microsoft.CognitiveServices/accounts/{accountName}' has been soft-deleted. To restore the resource, you must specify 'restore' to be 'true' in the property. If you don't want to restore existing resource, please purge it first."}
    ```

    If you receive this message, modify the previous `azure deployment group create` command to set the `restore` parameter equal to `true` and rerun it.

- If the selected region is restricted from provisioning specific resources, you must set the `REGION` variable to a different location and rerun the commands to create the resource group and run the Bicep deployment script.

    ```bash
    {"status":"Failed","error":{"code":"DeploymentFailed","target":"/subscriptions/{subscriptionId}/resourceGroups/{resourceGrouName}/providers/Microsoft.Resources/deployments/{deploymentName}","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.","details":[{"code":"ResourceDeploymentFailure","target":"/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.DBforPostgreSQL/flexibleServers/{serverName}","message":"The resource write operation failed to complete successfully, because it reached terminal provisioning state 'Failed'.","details":[{"code":"RegionIsOfferRestricted","message":"Subscriptions are restricted from provisioning in this region. Please choose a different region. For exceptions to this rule please open a support request with Issue type of 'Service and subscription limits'. See https://review.learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-request-quota-increase for more details."}]}]}}
    ```

- If the lab requires AI resources, you might get the following error. This error occurs when the script is unable to create an AI resource due to the requirement to accept the responsible AI agreement. If that is the case, use the Azure portal user interface to create an Azure AI Services resource, and then rerun the deployment script.

    ```bash
    {"code": "InvalidTemplateDeployment", "message": "The template deployment 'deploy' is not valid according to the validation procedure. The tracking id is 'f8412edb-6386-4192-a22f-43557a51ea5f'. See inner errors for details."}
     
    Inner Errors:
    {"code": "ResourceKindRequireAcceptTerms", "message": "This subscription cannot create TextAnalytics until you agree to Responsible AI terms for this resource. You can agree to Responsible AI terms by creating a resource through the Azure Portal then trying again. For more detail go to https://go.microsoft.com/fwlink/?linkid=2164190"}
    ```

### Install psql

Since we need to copy the data from the CSV file into the PostgreSQL database, we need to install `psql` on your local machine. *If you already have `psql` installed, skip this section.*

1. To check if **psql** is already installed in your environment, open command line/terminal, and run the command ***psql***. If it returns a message like "*psql: error: connection to server on socket...*", that means that the **psql** tool is already installed in your environment and there's no need to reinstall it and you can skip this section.

1. Install [psql](https://sbp.enterprisedb.com/getfile.jsp?fileid=1258893).

1. In the setup wizard, follow the prompt until you reach the **Select Components** dialog box, select **Command Line Tools**. You can uncheck the other components if you aren't planning to use them. Complete the installation by following the prompts.

1. Open a new command prompt or terminal window and run **psql** to verify that the installation was successful. If you see a message like "*psql: error: connection to server on socket...*", that means that the **psql** tool is installed successfully. Otherwise, you might need to add the PostgreSQL bin directory to your system PATH variable.

    1. If you're using Windows, make sure to add the PostgreSQL bin directory to your system PATH variable. The bin directory is typically located at `C:\Program Files\PostgreSQL\<version>\bin`.
        1. You can check if the bin directory is in your PATH variable by running the command `echo %PATH%` in a command prompt and checking if the PostgreSQL bin directory is listed. If it isn't, you can add it manually.
        1. To add it manually, right-click on the **Start** button.
        1. Select **System** and then select **Advanced system settings**.
        1. Select the **Environment Variables** button.
        1. Double-click on the **Path** variable in the **System variables** section.
        1. Select **New**, and add the path to the PostgreSQL bin directory.
        1. After adding it, close and reopen the command prompt for the changes to take effect.

    1. If you're using macOS or Linux, the PostgreSQL `bin` directory is typically located at `/usr/local/pgsql/bin`.  
        1. You can check whether this directory is in your `PATH` environment variable by running `echo $PATH` in a terminal.  
        1. If it’s not, you can add it by editing your shell configuration file, usually `.bash_profile`, `.bashrc`, or `.zshrc`, depending on your shell.

### Populate the database with data

Once you verified that **psql** is installed, you can connect to your PostgreSQL server using the command line, by opening a command prompt or terminal window.

> &#128221; If you are using Windows, you can use the **Windows PowerShell** or **Command Prompt**. If you are using macOS or Linux, you can use the **Terminal** application.

The syntax for connecting to the server is:

```sql
psql -h <servername> -p <port> -U <username> <dbname>
```

1. At the command prompt or terminal, enter **`--host=<servername>.postgres.database.azure.com`** where `<servername>` is the name of the Azure Database for PostgreSQL previously created.

    You can find the Server name in **Overview** in the Azure portal or as an output from the bicep script or on the Azure portal.

    ```sql
   psql -h <servername>.postgres.database.azure.com -p 5432 -U pgAdmin postgres
    ```

    You're prompted for the password for the admin account you previously copied.

1. You need to create a table within the database and populate it with sample data so you have information to work with as you review locking in this exercise.

1. Run the following command to create the `production.workorder` table for loading in data:

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
    ```

1. Next, use the `COPY` command to load data from CSV files into the table you previously created. Start by running the following command to populate the `production.workorder` table:

    ```sql
    \COPY production.workorder FROM 'mslearn-postgresql/Allfiles/Labs/08/Lab8_workorder.csv' CSV HEADER
    ```

    The command output should be `COPY 72591`, indicating that 72,591 rows were written into the table from the CSV file.

1. Close the command prompt or terminal window.

### Connect to the database with Visual Studio Code

1. Open Visual Studio Code if it isn't already opened and open the folder where you cloned the GitHub repository.

1. Select the **PostgreSQL** icon in the left menu.

    > &#128221; If you do not see the PostgreSQL icon, select the **Extensions** icon and search for **PostgreSQL**. Select the **PostgreSQL** extension by Microsoft and select **Install**.

1. If you already created a connection to your PostgreSQL server, skip to the next step. To create a new connection:

    1. In the **PostgreSQL** extension, select **+ Add Connection** to add a new connection.

    1. In the **NEW CONNECTION** dialog box, enter the following information:

        - **Server name**: `<your-server-name>`.postgres.database.azure.com
        - **Authentication type**: Password
        - **User name**: pgAdmin
        - **Password**: The random password you previously generated.
        - Check the **Save password** checkbox.
        - **Connection name**: `<your-server-name>`

    1. Test the connection by selecting **Test Connection**. If the connection is successful, select **Save & Connect** to save the connection, otherwise review the connection information, and try again.

1. If not already connected, select **Connect** for your PostgreSQL server. You're connected to the Azure Database for PostgreSQL server.

1. Expand the Server node and its databases. The existing databases are listed.

## Task 1: Investigate default locking behavior

1. Open Visual Studio Code if it isn't already open.

1. Bring up the command palette (Ctrl+Shift+P) and select **PGSQL: New Query**. Select the new connection you created from the list in the command palette. If it asks for a password, enter the password you created for the new role.

1. On the lower right of the **New Query** window, make sure the connection is green. If it isn't, it should say **PGSQL Disconnected**. Select the **PGSQL Disconnected** text and then select your PostgreSQL server connection from the list in the command palette. If it asks for a password, enter the password you previously generated.

1. On the **New Query** window, copy, highlight, and execute the following SQL statement:

    ```sql
    SELECT current_database();
    ```

1. If the current database isn't set to **adventureworks**, you need to change the database to **adventureworks**. To change the database, select the ellipsis in the menu bar with the *run* icon and selecting **Change PostgreSQL Database**. Select `adventureworks` from the list of databases. Verify that the database is now set to `adventureworks` by running the **SELECT current_database();** statement.

1. On the **New Query** window, copy, highlight, and execute the following SQL statement:

    ```sql
    SELECT * FROM production.workorder
    ORDER BY scrappedqty DESC;
    ```

1. Notice that the **scrappedqty** value for the first row is **673**.

1. We need to open a second query window to simulate a transaction that updates the data in the first query window. Bring up the command palette (Ctrl+Shift+P) and select **PGSQL: New Query**. Select the new connection you created from the list in the command palette. If it asks for a password, enter the password you created for the new role.

1. On the lower right of the **New Query** window, make sure the connection is green. If it isn't, it should say **PGSQL Disconnected**. Select the **PGSQL Disconnected** text and then select your PostgreSQL server connection from the list in the command palette. If it asks for a password, enter the password you previously generated.

1. On the **New Query** window, copy, highlight, and execute the following SQL statement:

    ```sql
    SELECT current_database();
    ```

1. If the current database isn't set to **adventureworks**, you need to change the database to **adventureworks**. To change the database, select the ellipsis in the menu bar with the *run* icon and selecting **Change PostgreSQL Database**. Select `adventureworks` from the list of databases. Verify that the database is now set to `adventureworks` by running the **SELECT current_database();** statement.

1. On the **New Query** window, copy, highlight, and execute the following SQL statement:

    ```sql
    BEGIN TRANSACTION;
    UPDATE production.workorder
        SET scrappedqty=scrappedqty+1;
    ```

1. Notice that the second query begins a transaction, but doesn't commit the transaction.

1. Return to *first* query window and run the query in that window again.

1. Notice that the **stockedqty** value for the first row is still **673**. The query is using a snapshot of the data and isn't seeing the updates from the other transaction.

1. Select the *second* query tab, delete the existing query, type the following query and select **Run**.

    ```sql
    ROLLBACK TRANSACTION;
    ```

## Task 2: Apply table locks to a transaction

1. Select the *second* query tab, type the following query and select **Run**.

    ```sql
    BEGIN TRANSACTION;
    LOCK TABLE production.workorder IN ACCESS EXCLUSIVE MODE;
    UPDATE production.workorder
        SET scrappedqty=scrappedqty+1;
    ```

1. Notice that the second query begins a transaction, but doesn't commit the transaction.

1. Return to the *first* query and run the query again.

1. Notice that the transaction is blocked and doesn't complete, however long you wait.

1. Select the *second* query tab, delete the existing query, type the following query and select **Run**.

    ```sql
    ROLLBACK TRANSACTION;
    ```

1. Return to the *first* query tab, wait for a few seconds and notice that the query completed once the block was removed.

## Clean-Up

1. If you don't need this PostgreSQL server anymore for other exercises, to avoid incurring unnecessary Azure costs, delete the resource group created in this exercise.

1. If you want to keep the PostgreSQL server running, you can leave it running. If you don't want to leave it running, you can stop the server to avoid incurring unnecessary costs in the bash terminal. To stop the server, run the following command:

    ```azurecli
    az postgres flexible-server stop --name <your-server-name> --resource-group $RG_NAME
    ```

    Replace `<your-server-name>` with the name of your PostgreSQL server.

    > &#128221; You can also stop the server from the Azure portal. In the Azure portal, navigate to **Resource groups** and select the resource group you previously created. Select the PostgreSQL server and then select **Stop** from the menu.

1. If needed, delete the git repository you cloned earlier.

In this exercise, we reviewed the default locking behavior. We then applied locks explicitly and saw that although some locks provide high levels of protection, these locks can also have performance implications.
