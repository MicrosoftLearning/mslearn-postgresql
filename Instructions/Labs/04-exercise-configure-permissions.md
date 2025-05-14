---
lab:
    title: 'Configure permissions in Azure Database for PostgreSQL'
    module: 'Secure Azure Database for PostgreSQL'
---

# Configure permissions in Azure Database for PostgreSQL

In this lab exercises, you assign role-based access control (RBAC) roles to control access to Azure Database for PostgreSQL resources and PostgreSQL GRANTS to control access to database operations.

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
    az deployment group create --resource-group $RG_NAME --template-file "Allfiles/Labs/Shared/deploy-postgresql-server.bicep" --parameters adminLogin=pgAdmin adminLoginPassword=$ADMIN_PASSWORD
    ```

    The Bicep deployment script provisions the Azure services required to complete this exercise into your resource group. The resources deployed are an Azure Database for PostgreSQL - Flexible Server. The bicep script also creates a database - which can be configured on the commandline as a parameter.

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

## Connect to the PostgreSQL extension in Visual Studio Code

In this section, you connect to the PostgreSQL server using the PostgreSQL extension in Visual Studio Code. You use the PostgreSQL extension to run SQL scripts against the PostgreSQL server.

1. Open Visual Studio Code if it isn't already opened and open the folder where you cloned the GitHub repository.

1. Select the **PostgreSQL** icon in the left menu.

    > &#128221; If you do not see the PostgreSQL icon, select the **Extensions** icon and search for **PostgreSQL**. Select the **PostgreSQL** extension by Microsoft and select **Install**.

1. If you already created a connection to your PostgreSQL server, skip to the next step. To create a new connection:

    1. In the **PostgreSQL** extension, select **+ Add Connection** to add a new connection.

    1. In the **NEW CONNECTION** dialog box, enter the following information:

        - **Server name**: <your-server-name>.postgres.database.azure.com
        - **Authentication type**: Password
        - **User name**: pgAdmin
        - **Password**: The random password you previously generated.
        - Check the **Save password** checkbox.
        - **Connection name**: <your-server-name>

    1. Test the connection by selecting **Test Connection**. If the connection is successful, select **Save & Connect** to save the connection, otherwise review the connection information, and try again.

1. If not already connected, select **Connect** for your PostgreSQL server. You're connected to the Azure Database for PostgreSQL server.

1. Expand the Server node and its databases. The existing databases are listed.

1. If you didn't create the zoodb database already, select **File**, **Open file** and navigate to the folder where you saved the scripts. Select **../Allfiles/Labs/02/Lab2_ZooDb.sql** and **Open**.

1. On the lower right of Visual Studio Code, make sure the connection is green. If it isn't, it should say **PGSQL Disconnected**. Select the **PGSQL Disconnected** text and then select your PostgreSQL server connection from the list in the command palette. If it asks for a password, enter the password you previously generated.

    > &#128221; You can also change the database on the query pane. You can note the server name and database name under the query tab itself. Selecting the database name will show a list of databases. Select the `zoodb` database from the list.

1. Time to create the database.

    1. Highlight the **DROP** and **CREATE** statements and run them.

    1. If you highlight just the **SELECT current_database()** statement and run it, you notice that the database is currently set to `postgres`. You need to change it to `zoodb`.

    1. Select the ellipsis in the menu bar with the *run* icon and select **Change PostgreSQL Database**. Select `zoodb` from the list of databases.

    1. Run the **SELECT current_database()** statement again to confirm that the database is now set to `zoodb`.

    1. Highlight the **Created tables**, **Create foreign keys**, and **Populate tables** sections and run them.

    1. Highlight the 3 **SELECT** statements at the end of the script and run them to verify that the tables were created and populated.

## Create a new user account in Microsoft Entra ID

> &#128221; In most production or development environments, it's possible you don't have the subscription account privileges to create accounts on your Microsoft Entra ID service. In that case, if allowed by your organization, try asking your Microsoft Entra ID administrator to create a test account for you. *If you're unable to get the test Microsoft Entra account, skip this section and continue to the **GRANT access to Azure Database for PostgreSQL** section*.

1. In the [Azure portal](https://portal.azure.com), sign in using an Owner account and navigate to Microsoft Entra ID.

1. Under **Manage**, select **Users**.

1. At the top-left, select **New user** and then select **Create new user**.

1. In the **New user** page, enter these details and then select **Create**:
    - **User principal name:** Choose a Principle name
    - **Display Name:** Choose a Display Name
    - **Password:** Untick **Auto-generate password** and then enter a strong password. Take note of the principal name and password.
    - Select **Review + create**

    > &#128161; When the user is created, make a note of the full **User principal name** so that you can use it later to sign-in.

### Assign the Reader role

1. In the Azure portal, select **All resources** and then select your Azure Database for PostgreSQL resource.

1. Select **Access control (IAM)** and then select **Role assignments**. The new account doesn't appear in the list.

1. Select **+ Add** and then select **Add role assignment**.

1. Select the **Reader** role, and then select **Next**.

1. Choose **+ Select members** and add the new account you added in the previous step to the list of members and then select **Next**.

1. Select **Review + Assign**.

### Test the Reader role

1. In the top-right of the Azure portal, select your user account and then select **Sign out**.

1. Sign in as the new user, with the user principal name and the password that you noted. Replace the default password if you're prompted to and make a note of the new one.

1. Choose **Ask me later** if prompted for multifactor authentication

1. In the portal home page, select **All resources** and then select your Azure Database for PostgreSQL resource.

1. Select **Stop**. An error is displayed, because the Reader role enables you to see the resource but not change it.

### Assign the Contributor role

1. In the top-right of the Azure portal, select the new account's user account and then select **Sign out**.

1. Sign in using your original Owner account.

1. Navigate to your Azure Database for PostgreSQL resource, and then select **Access Control (IAM)**.

1. Select **+ Add** and then select **Add role assignment**.

1. Choose **Privileged administrator roles**

1. Select the **Contributor** role, and then select **Next**.

1. Add the new account you previously added to the list of members and then select **Next**.

1. Select **Review + Assign**.

1. Select **Role Assignments**. The new account now has assignments for both Reader and Contributor roles.

## Test the Contributor role

1. In the top-right of the Azure portal, select your user account and then select **Sign out**.

1. Sign in as the new account, with the user principal name and password that you noted.

1. In the portal home page, select **All resources** and then select your Azure Database for MySQL resource.

1. Select **Stop** and then select **Yes**. This time, the server stops without errors because the new account has the necessary role assigned.

1. Select **Start** to ensure that the PostgreSQL server is ready for the next steps.

1. In the top-right of the Azure portal, select the new account's user account and then select **Sign out**.

1. Sign in using your original Owner account.

## GRANT access to Azure Database for PostgreSQL

In this section, you create a new role in the PostgreSQL database and assign it permissions to access the database. You also test the new role to ensure that it has the correct permissions.

1. Open Visual Studio Code if it isn't already open.

1. Bring up the command palette (Ctrl+Shift+P) and select **PGSQL: New Query**.

1. Select your PostgreSQL server connection from the list in the command palette. If it asks for a password, enter the password you previously generated.

1. In the **New Query** window, change the database to **zoodb**. To change the database, select the ellipsis in the menu bar with the *run* icon and selecting **Change PostgreSQL Database**. Select `zoodb` from the list of databases. Verify that the database is now set to `zoodb` by running the **SELECT current_database();** statement.

1. In the query pane, copy, highlight, and execute the following SQL statement against Postgres database. Several user roles should be returned, including the **pgAdmin** role that you're using to connect:

    ```SQL
    SELECT rolname FROM pg_catalog.pg_roles;
    ```

1. To create a new role, execute this code

    ```SQL
    -- Make sure to change the password to a complex one
    -- and replace the password in the script below
    CREATE ROLE dbuser WITH LOGIN NOSUPERUSER INHERIT CREATEDB NOCREATEROLE NOREPLICATION PASSWORD 'R3placeWithAComplexPW!';
    GRANT CONNECT ON DATABASE zoodb TO dbuser;
    ```

    > &#128221; Make sure to replace the password in the previous script for a complex password.

1. To list the new role, execute the previous SELECT query in **pg_catalog.pg_roles** again. You should see the **dbuser** role listed.

1. To enable the new role to query and modify data in the **animal** table in the **zoodb** database, 

    1. In the **New Query** window, change the database to **zoodb**. To change the database, select the ellipsis in the menu bar with the *run* icon and selecting **Change PostgreSQL Database**. Select `zoodb` from the list of databases. Verify that the database is now set to `zoodb` by running the **SELECT current_database();** statement.

    1. execute this code against the `zoodb` database:

        ```SQL
        GRANT SELECT, INSERT, UPDATE, DELETE ON animal TO dbuser;
        ```

## Test the new role

Let's test the new role to ensure that it has the correct permissions.

1. In the **PostgreSQL** extension, select **+ Add Connection** to add a new connection.

1. In the **NEW CONNECTION** dialog box, enter the following information:

    - **Server name**: <your-server-name>.postgres.database.azure.com
    - **Authentication type**: Password
    - **User name**: dbuser
    - **Password**: The password you used when creating the new role.
    - Check the **Save password** checkbox.
    - **Database name**: zoodb
    - **Connection name**: <your-server-name> + "-dbuser"

1. Test the connection by selecting **Test Connection**. If the connection is successful, select **Save & Connect** to save the connection, otherwise review the connection information, and try again.

1. Bring up the command palette (Ctrl+Shift+P) and select **PGSQL: New Query**. Select the new connection you created from the list in the command palette. If it asks for a password, enter the password you created for the new role.

1. The connection should be displaying the **zoodb** database by default. If it isn't, you can change the database to **zoodb**. To change the database, select the ellipsis in the menu bar with the *run* icon and selecting **Change PostgreSQL Database**. Select `zoodb` from the list of databases. Verify that the database is now set to `zoodb` by running the **SELECT current_database();** statement.

1. On the **New Query** window, copy, highlight, and execute the following SQL statement against the **zoodb** database:

    ```SQL
    SELECT * FROM animal;
    ```

1. To test whether you have the UPDATE privilege, copy, highlight, and execute this code:

    ```SQL
    UPDATE animal SET name = 'Linda Lioness' WHERE ani_id = 7;
    SELECT * FROM animal;
    ```

1. To test whether you have the DROP privilege, execute this code. If there's an error, examine the error code:

    ```SQL
    DROP TABLE animal;
    ```

1. To test whether you have the GRANT privilege, execute this code:

    ```SQL
    GRANT ALL PRIVILEGES ON animal TO dbuser;
    ```

These tests demonstrate that the new user can execute Data Manipulation Language (DML) commands to query and modify data. However, the new user can't use Data Definition Language (DDL) commands to change the schema. Additionally, the new user can't GRANT any new privileges to circumvent the permissions.

## Clean-Up

1. If you don't need this PostgreSQL server anymore for other exercises, to avoid incurring unnecessary Azure costs, delete the resource group created in this exercise.

1. If needed, delete the git repository you cloned earlier.
