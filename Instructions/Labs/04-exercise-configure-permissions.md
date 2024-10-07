---
lab:
    title: 'Configure permissions in Azure Database for PostgreSQL'
    module: 'Secure Azure Database for PostgreSQL'
---

# Configure permissions in Azure Database for PostgreSQL

In this lab exercises, you'll assign RBAC roles to control access to Azure Database for PostgreSQL resources and PostgreSQL GRANTS to control access to database operations.

## Before you start

You need your own Azure subscription to complete this exercise. If you do not have an Azure subscription, create an [Azure free trial](https://azure.microsoft.com/free).

To complete these exercises, you need to install a PostgreSQL server that is connected to Microsoft Entra ID - formerly Azure Active Directory

### Create a Resource Group

1. In a web browser, navigate to the [Azure portal](https://portal.azure.com). Sign in using an Owner or Contributor account.
2. Under Azure services, select **Resource Groups**, then select **+ Create**.
3. Check that the correct subscription is displayed, then enter the Resource group name as **rg-PostgreSQL_Entra**. Select a **Region**.
4. Select **Review + create**. Then select **Create**.

## Create an Azure Database for PostgreSQL flexible server

1. Under Azure services, select **+ Create a resource**.
    1. In **Search the Marketplace**, type **`azure database for postgresql flexible server`**, choose **Azure Database for PostgreSQL Flexible Server** and click **Create**.
1. On the Flexible server **Basics** tab, enter each field as follows:
    1. Subscription - your subscription.
    1. Resource group - **rg-PostgreSQL_Entra**.
    1. Server name - **psql-postgresql-fx7777** (Server name must be globally unique, so replace 7777 with four random numbers).
    1. Region - select the same region as the resource group.
    1. PostgreSQL version - select 16.
    1. Workload type - **Development**.
    1. Compute + storage - **Burstable, B1ms**.
    1. Availability zone - No preference.
    1. High availability - leave unchecked.
    1. Authentication Method - choose **PostgreSQL and Microsoft Entra authentication**
    1. Set Microsoft Entra admin - select **Set admin**
        1. Search for your account in **Select Microsoft Entra Admins** and (o) your account and click **Select**
    1. In **admin username**, enter **`demo`**.
    1. In **password**, enter a suitably complex password.
    1. Select **Next: Networking >**.
1. On the Flexible server **Networking** tab, enter each field as follows:
    1. Connectivity method: (o) Public access (allowed IP addresses) and Private endpoint
    1. Public access, select **Allow public access to this resource through the internet using a public IP address**
    1. Under Firewall rules, select **+ Add current client IP address**, to add your current IP address as a firewall rule. You can optionally name this firewall rule to something meaningful. Also add **Add 0.0.0.0 - 255.255.255.255** and click **Continue**
1. Select **Review + create**. Review your settings, then select **Create** to create your Azure Database for PostgreSQL Flexible server. When the deployment is complete, select **Go to resource** ready for the next step.

## Install Azure Data Studio

To install Azure Data Studio for use with Azure Database for PostgreSQL:

1. In a browser, navigate to [Download and install Azure Data Studio](/sql/azure-data-studio/download-azure-data-studio) and under the Windows platform, select **User installer (recommended)**. The executable file is downloaded to your Downloads folder.
1. Select **Open file**.
1. The License agreement is displayed. Read and **accept the agreement**, then select **Next**.
1. In **Select additional Tasks**, select **Add to PATH**, and any other additions you require. Select **Next**.
1. The **Ready to Install** dialog box is displayed. Review your settings. Select **Back** to make changes or select **Install**.
1. The **Completing the Azure Data Studio Setup Wizard** dialog box is displayed. Select **Finish**. Azure Data Studio starts.

### Install the PostgreSQL extension

1. Open Azure Data Studio if it is not already open.
1. From the left menu, select **Extensions** to display the Extensions panel.
1. In the search bar, enter **PostgreSQL**. The PostgreSQL extension for Azure Data Studio icon is displayed.
1. Select **Install**. The extension installs.

### Connect to Azure Database for PostgreSQL flexible server

1. Open Azure Data Studio if it is not already open.
1. From the left menu, select **Connections**.
1. Select **New Connection**.
1. Under **Connection Details**, in **Connection type** select **PostgreSQL** from the drop-down list.
1. In **Server name**, enter the full server name as it appears on the Azure portal.
1. In **Authentication type**, leave Password.
1. In User name and Password, enter the user name **demo** and the complex password you created above
1. Select [ x ] Remember password.
1. The remaining fields are optional.
1. Select **Connect**. You are connected to the Azure Database for PostgreSQL server.
1. A list of the server databases is displayed. This includes system databases, and user databases.

### Create the zoo database

1. Either navigate to the folder with your exercise script files, or download the **Lab2_ZooDb.sql** from [MSLearn PostgreSQL Labs](https://github.com/MicrosoftLearning/mslearn-postgresql/Allfiles/Labs/02).
1. Open Azure Data Studio if it is not already open.
1. Select **File**, **Open file** and navigate to the folder where you saved the script. Select **../Allfiles/Labs/02/Lab2_ZooDb.sql** and **Open**. If a trust warning is displayed select **Open**.
1. Run the script. The zoodb database is created.

## Create a new user account in Microsoft Entra ID

> [!NOTE]
> In most production or development environments, it is very possible you won't have the subscription account privileges to create accounts on your Microsoft Entra ID service.  In that case, if allowed by your organization, try asking your Microsoft Entra ID administrator to create a test account for you. If you are unable to get the test Entra account, skip this section and continue to the **GRANT access to Azure Database for PostgreSQL** section. 

1. In the [Azure portal](https://portal.azure.com), sign in using an Owner account and navigate to Microsoft Entra ID.
1. Under **Manage**, select **Users**.
1. At the top-left, select **New user** and then select **Create new user**.
1. In the **New user** page, enter these details and then select **Create**:
    - **User principal name:** Choose a Principle name
    - **Display Name:** Choose a Display Name
    - **Password:** Untick **Auto-generate password** and then enter a strong password. Take note of the principal name and password.
    - Click **Review + create**

    > [!TIP]
    > When the user is created, make a note of the full **User principal name** so that you can use it later to log in.

### Assign the Reader role

1. In the Azure portal, select **All resources** and then select your Azure Database for PostgreSQL resource.
1. Select **Access control (IAM)** and then select **Role assignments**. The new account doesn't appear in the list.
1. Select **+ Add** and then select **Add role assignment**.
1. Select the **Reader** role, and then select **Next**.
1. Choose **+ Select members**, add the new account you added in the previous step to the list of members and then select **Next**.
1. Select **Review + Assign**.

### Test the Reader role

1. In the top-right of the Azure portal, select your user account and then select **Sign out**.
1. Sign in as the new user, with the user principal name and the password that you noted. Replace the default password if you're prompted to and make a note of the new one.
1. Choose **Ask me later** if prompted for Multi Factor Authentication
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

1. Open Azure Data Studio and connect to your Azure Database for PostgreSQL server using the **demo** user that you set as the administrator above.
1. In the query pane, execute this code against postgres database. Twelve user roles should be returned, including the **demo** role that you're using to connect:

    ```SQL
    SELECT rolname FROM pg_catalog.pg_roles;
    ```

1. To create a new role, execute this code

    ```SQL
    CREATE ROLE dbuser WITH LOGIN NOSUPERUSER INHERIT CREATEDB NOCREATEROLE NOREPLICATION PASSWORD 'R3placeWithAComplexPW!';
    GRANT CONNECT ON DATABASE zoodb TO dbuser;
    ```
    > [!NOTE]
    > Make sure to replace the password in the script above for a complex password.

1. To list the new role, execute the above SELECT query in **pg_catalog.pg_roles** again. You should see the **dbuser** role listed.
1. To enable the new role to query and modify data in the **animal** table in the **zoodb** database, execute this code against the zoodb database:

    ```SQL
    GRANT SELECT, INSERT, UPDATE, DELETE ON animal TO dbuser;
    ```

## Test the new role

1. In Azure Data Studio, in the list of **CONNECTIONS** select the new connection button.
1. In the **Connection type** list, select **PostgreSQL**.
1. In the **Server name** textbox, type the fully qualified server name for your Azure Database for PostgreSQL resource. You can copy it from the Azure portal.
1. In the **Authentication type** list, select **Password**.
1. In the **Username** textbox, type **dbuser** and in the **Password** textbox type the complex password you created the account with.
1. Select the **Remember password** checkbox and then select **Connect**.
1. Select **New query** and then execute this code:

    ```SQL
    SELECT * FROM animal;
    ```

1. To test whether you have the UPDATE privilege, execute this code:

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

These tests demonstrate that the new user can execute Data Manipulation Language (DML) commands to query and modify data but can't use Data Definition Language (DDL) commands to change the schema. Also, the new user can't GRANT any new privileges to circumvent the permissions.

## Clean-Up

You will not use this PostgreSQL server again so please delete the resource group you created which will remove the server.
