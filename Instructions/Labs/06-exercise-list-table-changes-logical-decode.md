---
lab:
    title: 'List table changes with logical decoding'
    module: 'Understand write-ahead logging'
---

# List table changes with logical decoding

In this exercise, you configure logical replication, which is native to PostgreSQL. You create two servers, which act as publisher and subscriber. Data in the zoodb is replicated between them.

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

## Create resource group

In this section, you create a resource group to contain the Azure Database for PostgreSQL servers. The resource group is a logical container that holds related resources for an Azure solution.

1. Sign in to the Azure portal. Your user account must be an Owner or Contributor for the Azure subscription.

1. Select **Resource groups** and then select **+ Create**.

1. Select your subscription.

1. In Resource group, enter **rg-PostgreSQL_Replication**.

1. Select a region close to your location.

1. Select **Review + create**.

1. Select **Create**.

## Create a publisher server

In this section, you create the publisher server. The publisher server is the source of the data that is to be replicated to the subscriber server.

1. Under Azure services, select **+ Create a resource**. Under **Categories**, select **Databases**. Under **Azure Database for PostgreSQL**, select **Create**.

1. On the Flexible server **Basics** tab, enter each field as follows:
    - **Subscription** - your subscription.
    - **Resource group** - select **rg-PostgreSQL_Replication**.
    - **Server name** - *psql-postgresql-pub9999* (Name must be globally unique, so replace 9999 with four random numbers).
    - **Region** - select the same region as the resource group.
    - **PostgreSQL version** - select 16.
    - **Workload type** - *Development*.
    - **Compute + storage** - *Burstable*. Select **Configure server** and examine the configuration options. Don't make any changes and close the section.
    - **Availability zone** - 1. If availability zones aren't supported, leave as No preference.
    - **High availability** - Disabled.
    - **Authentication method** - PostgreSQL authentication only.
    - **admin username**, enter **`pgAdmin`**.
    - **password**, enter a suitable complex password.

1. Select **Next: Networking >**.

1. On the Flexible server **Networking** tab, enter each field as follows:
    - **Connectivity method**: (o) Public access (allowed IP addresses).
    - **Allow public access from any Azure service within Azure to this server**: Checked. This checkbox must be checked, so that the publisher and subscriber databases can communicate with each other.
    - **Firewall rules**: Select **+ Add current client IP address**. This option adds your current IP address as a firewall rule. You can optionally name this firewall rule to something meaningful.

1. Select **Review + create**. Then select **Create**.

1. Since creating an Azure Database for PostgreSQL can take a few minutes, start with the next step as soon this deployment is in progress. Remember to open a new browser window or tab to continue.

## Create a subscriber server

1. Under Azure services, select **+ Create a resource**. Under **Categories**, select **Databases**. Under **Azure Database for PostgreSQL**, select **Create**.

1. On the Flexible server **Basics** tab, enter each field as follows:
    - **Subscription** - your subscription.
    - **Resource group** - select **rg-PostgreSQL_Replication**.
    - **Server name** - *psql-postgresql-sub9999* (Name must be globally unique, so replace 9999 with four random numbers).
    - **Region** - select the same region as the resource group.
    - **PostgreSQL version** - select 16.
    - **Workload type** - *Development*.
    - **Compute + storage** - *Burstable*. Select **Configure server** and examine the configuration options. Don't make any changes and close the section.
    - **Availability zone** - 2. If availability zones aren't supported, leave as No preference.
    - **High availability** - Disabled.
    - **Authentication method** - PostgreSQL authentication only.
    - **admin username**, enter **`pgAdmin`**.
    - **password**, enter a suitable complex password.

1. Select **Next: Networking >**.

1. On the Flexible server **Networking** tab, enter each field as follows:
    - **Connectivity method**: (o) Public access (allowed IP addresses).
    - **Allow public access from any Azure service within Azure to this server**: Checked. This checkbox must be checked, so that the publisher and subscriber databases can communicate with each other.
    - **Firewall rules**: Select **+ Add current client IP address**. This option adds your current IP address as a firewall rule. You can optionally name this firewall rule to something meaningful.

1. Select **Review + create**. Then select **Create**.

1. Wait for both Azure Database for PostgreSQL servers to be deployed.

## Set up replication

For *both* the publisher and subscriber servers:

1. In the Azure portal, navigate to the server and under Settings select **Server parameters**.

1. Using the search bar, find each parameter and make the following changes:
    - `wal_level` = LOGICAL
    - `max_worker_processes` = 24

1. Select **Save**. Then select **Save and Restart**.

1. Wait for both servers to restart.

    > &#128221; After the servers are re-deployed, you might have to refresh your browser windows to notice that the servers have restarted.

## Set up the publisher

In this section, you set up the publisher server. The publisher server is the source of the data that is to be replicated to the subscriber server.

1. Open the first instance of Visual Studio Code to connect to the publisher server.

1. Open the folder where you cloned the GitHub repository.

1. Select the **PostgreSQL** icon in the left menu.

    > &#128221; If you do not see the PostgreSQL icon, select the **Extensions** icon and search for **PostgreSQL**. Select the **PostgreSQL** extension by Microsoft and select **Install**.

1. If you already created a connection to your PostgreSQL *publisher* server, skip to the next step. To create a new connection:

    1. In the **PostgreSQL** extension, select **+ Add Connection** to add a new connection.

    1. In the **NEW CONNECTION** dialog box, enter the following information:

        - **Server name**: `<your-publisher-server-name>`.postgres.database.azure.com
        - **Authentication type**: Password
        - **User name**: pgAdmin
        - **Password**: The random password you previously generated.
        - Check the **Save password** checkbox.
        - **Connection name**: `<your-publisher-server-name>`

    1. Test the connection by selecting **Test Connection**. If the connection is successful, select **Save & Connect** to save the connection, otherwise review the connection information, and try again.

1. If not already connected, select **Connect** for your PostgreSQL server. You're connected to the Azure Database for PostgreSQL server.

1. Expand the Server node and its databases. The existing databases are listed.

1. In Visual Studio Code, select **File**, **Open file** and navigate to the folder where you saved the scripts. Select **../Allfiles/Labs/06/Lab6_Replication.sql** and **Open**.

1. On the lower right of Visual Studio Code, make sure the connection is green. If it isn't, it should say **PGSQL Disconnected**. Select the **PGSQL Disconnected** text and then select your PostgreSQL server connection from the list in the command palette. If it asks for a password, enter the password you previously generated.

1. Time to set up the *publisher*.

    1. Highlight and run the section **Grant the admin user replication permission**.

    1. Highlight and run the section **Create zoodb database**.

    1. If you highlight just the **SELECT current_database()** statement and run it, you notice that the database is currently set to `postgres`. You need to change it to `zoodb`.

    1. Select the ellipsis in the menu bar with the *run* icon and select **Change PostgreSQL Database**. Select `zoodb` from the list of databases.

        > &#128221; You can also change the database on the query pane. You can note the server name and database name under the query tab itself. Selecting the database name will show a list of databases. Select the `zoodb` database from the list.

    1. Highlight and run the section **Create tables** and **foreign key constraints** in zoodb.

    1. Highlight and run the section **Populate the tables in zoodb**.

    1. Highlight and run the section **Create a publication**. When you run the SELECT statement it doesn't list anything, because the replication isn't yet active.

    1. DON'T run the **CREATE SUBSCRIPTION** section. This script is run on the subscriber server.

    1. DON'T close this Visual Studio Code instance, just minimize it. You'll come back to it after you set up the subscriber server.

You now created the publisher server and the zoodb database. The database contains the tables and data that are replicated to the subscriber server.

## Set up the subscriber

In this section, you set up the subscriber server. The subscriber server is the destination of the data that is replicated from the publisher server. You create a new database on the subscriber server, which is populated with the data from the publisher server.

1. Open a *second instance* of Visual Studio Code to connect to the subscriber server.

1. Open the folder where you cloned the GitHub repository.

1. Select the **PostgreSQL** icon in the left menu.

    > &#128221; If you do not see the PostgreSQL icon, select the **Extensions** icon and search for **PostgreSQL**. Select the **PostgreSQL** extension by Microsoft and select **Install**.

1. If you already created a connection to your PostgreSQL *subscriber* server, skip to the next step. To create a new connection:

    1. In the **PostgreSQL** extension, select **+ Add Connection** to add a new connection.

    1. In the **NEW CONNECTION** dialog box, enter the following information:

        - **Server name**: `<your-subscriber-server-name>`.postgres.database.azure.com
        - **Authentication type**: Password
        - **User name**: pgAdmin
        - **Password**: The random password you previously generated.
        - Check the **Save password** checkbox.
        - **Connection name**: `<your-subscriber-server-name>`

    1. Test the connection by selecting **Test Connection**. If the connection is successful, select **Save & Connect** to save the connection, otherwise review the connection information, and try again.

1. If not already connected, select **Connect** for your PostgreSQL server. You're connected to the Azure Database for PostgreSQL server.

1. Expand the Server node and its databases. The existing databases are listed.

1. In Visual Studio Code, select **File**, **Open file** and navigate to the folder where you saved the scripts. Select **../Allfiles/Labs/06/Lab6_Replication.sql** and **Open**.

1. On the lower right of Visual Studio Code, make sure the connection is green. If it isn't, it should say **PGSQL Disconnected**. Select the **PGSQL Disconnected** text and then select your PostgreSQL server connection from the list in the command palette. If it asks for a password, enter the password you previously generated.

1. Time to set up the *subscriber*.

    1. Highlight and run the section **Grant the admin user replication permission**.

    1. Highlight and run the section **Create zoodb database**.

    1. If you highlight just the **SELECT current_database()** statement and run it, you notice that the database is currently set to `postgres`. You need to change it to `zoodb`.

    1. Select the ellipsis in the menu bar with the *run* icon and select **Change PostgreSQL Database**. Select `zoodb` from the list of databases.

        > &#128221; You can also change the database on the query pane. You can note the server name and database name under the query tab itself. Selecting the database name will show a list of databases. Select the `zoodb` database from the list.

    1. Highlight and run the section **Create tables** and **foreign key constraints** in `zoodb`.

    1. DON'T run the **Create a publication** section, that statement ran on the publisher server already.

    1. Scroll down to the section **Create a subscription**.

        1. Edit the **CREATE SUBSCRIPTION** statement so that it has the correct publisher server name and the publisher's strong password. Highlight and run the statement.

        1. Highlight and run the **SELECT** statement. This shows the subscription "sub" previously created.

    1. Under the section **Display the tables**, highlight, and run each **SELECT** statement. The publisher server populated these tables through replication.

You created the subscriber server and the zoodb database. The database contains the tables and data that were replicated from the publisher server.

## Make changes to the publisher database

- In the first instance of Visual Studio Code (*your publisher instance*), under **Insert more animals** highlight and run the **INSERT** statement. *Make sure you **don't** run this INSERT statement at the subscriber*.

## View the changes in the subscriber database

- In the second instance of Visual Studio Code (subscriber), under **Display the animal tables** highlight and run the **SELECT** statement.

You now created two Azure Database for PostgreSQL flexible servers and configured one as a publisher, and the other as a subscriber. In the publisher database, you created and populated the zoo database. In the subscriber database, you created an empty database, which was then populated by streaming replication.

## Clean-Up

1. If you don't need these PostgreSQL servers anymore for other exercises, to avoid incurring unnecessary Azure costs, delete the resource group created in this exercise.

1. If you want to keep the PostgreSQL servers running, you can leave them running. If you don't want to leave them running, you can stop the server to avoid incurring unnecessary costs in the bash terminal. To stop the servers, run the following command for each server:

    ```bash

    ```azurecli
    az postgres flexible-server stop --name <your-server-name> --resource-group $RG_NAME
    ```

    Replace `<your-server-name>` with the name of your PostgreSQL servers.

    > &#128221; You can also stop the server from the Azure portal. In the Azure portal, navigate to **Resource groups** and select the resource group you previously created. Select the PostgreSQL server and then select **Stop** from the menu. Do this for both the publisher and subscriber servers.

1. If needed, delete the git repository you cloned earlier.

You successfully created a PostgreSQL server and configured it for logical replication. You created a publisher server and a subscriber server, and you set up the replication between them. You also made changes to the publisher database and viewed the changes in the subscriber database. You now have a good understanding of how to set up logical replication in PostgreSQL.
