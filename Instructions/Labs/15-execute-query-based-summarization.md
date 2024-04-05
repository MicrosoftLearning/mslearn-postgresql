---
lab:
    title: 'Execute Query-based Summarization'
    module: 'Build AI apps with Azure Database for PostgreSQL'
---

# Lab Title

In this exercise, you will install the `azure_ai` extension in an Azure Database for PostgreSQL - Flexible Server database and explore the extension's capabilities for integrating [Azure OpenAI](https://learn.microsoft.com/azure/ai-services/openai/overview) and the [Azure AI Language service](https://learn.microsoft.com/azure/ai-services/language-service/) to incorporate rich generative AI capabilities into your database.

## Before you start

You will need an [Azure subscription](https://azure.microsoft.com/free) where you have administrative rights and you must be approved for Azure OpenAI access in that subscription. If you need Azure OpenAI access, apply at the [Azure OpenAI limited access](https://learn.microsoft.com/legal/cognitive-services/openai/limited-access) page.

### Deploy resources into your Azure subscription

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/).

2. Select the **Cloud Shell** icon in the Azure portal toolbar to open a new [Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) pane at the bottom of your browser window.

    ![Screenshot of the Azure toolbar with the Cloud Shell icon highlighted by a red box.](media/11-portal-toolbar-cloud-shell.png)

3. At the cloud shell prompt, enter the following to clone the GitHub repo containing exercise resources:

    ```bash
    git clone https://github.com/MicrosoftLearning/mslearn-postgresql.git
    ```

4. Next, you will run a couple of commands to define variables to reduce redundant typing when using commands to create Azure resources. The variables represent the name to assign to your resource group and the Azure region into which resources should be deployed.

    The resource group name defaults to `rg-postgresql-ai-ms-learn`, but you can provide any name you wish to use to host the resources associated with this exercise.

    ```bash
    RG_NAME=rg-postgresql-ai-ms-learn-kb
    ```

    In the command below, accept the default region of `eastus2` or replace it with the location you are using for your Azure resources.

    TODO: Need to provide a list of acceptable regions that support the appropriate gpt-4 model + abstractive summarization in the language service. (maybe just hardcode that one in the bicep template?)

    ```bash
    REGION=eastus2
    ```

5. Run the following Azure CLI command to create your resource group:

    ```azurecli
    az group create --name $RG_NAME --location $REGION
    ```

6. Finally, use the Azure CLI to execute a Bicep deployment script to provision Azure resources in your resource group:

    ```azurecli
    az deployment group create --resource-group $RG_NAME --template-file "mslearn-postgresql/Allfiles/Labs/Shared/deploy.bicep" --parameters adminLogin=pgAdmin adminLoginPassword=Password123!
    ```

    The bicep file will deploy an Azure Database for PostgreSQL - Flexible Server, Azure OpenAI, and an Azure AI Language service into your resource group. On the PostgreSQL server, it also adds the `azure_ai` and `pg_vector` extensions to the server's _allowlist_ and creates a database named `rentals` for use in this exercise. In Azure OpenAI, it creates a deployment named `embedding` using the `text-embedding-ada-002` model.

    The deployment will take several minutes to complete.

7. Close the cloud shell pane once your resource deployment has completed.

## Connect to your database using psql in the Azure Cloud Shell

In this task, you use the [psql command-line utility](https://www.postgresql.org/docs/current/app-psql.html) from the [Azure Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) to connect to your database.

1. In the [Azure portal](https://portal.azure.com/), navigate to your newly created Azure Database for PostgreSQL Flexible Server instance.

2. Once there, select **Databases** under **Settings** the left-hand navigation menu, and then select **Connect** for the `rentals` database.

    ![Screenshot of the Azure Database for PostgreSQL Databases page. Databases and Connect for the rentals database are highlighted by red boxes.](media/11-postgresql-rentals-database-connect.png)

3. At the "Password for user pgAdmin" prompt in the cloud shell, enter the password you created for the **pgAdmin** login. The default for this is `Password123!`.

    Once logged in, you will be at the `psql` prompt for the rentals database.

4. You will be working in the cloud shell throughout the remainder of this exercise, so it can be helpful to expand the pane within your browser window by selecting the **Maximize** button at the top right of the pane.

    ![Screenshot of the Azure Cloud Shell pane with the Maximize button highlighted by a red box.](media/11-azure-cloud-shell-pane-maximize.png)

## Populate the database with sample data

Before you get started exploring the `azure_ai` extension, you will add a couple of tables to the `rentals` database and populate them with sample data so you have information to work with as you review the extension's capabilities.

1. Run the following command to create the tables for storing data in the shape used by this lab:

    ```sql
    CREATE TABLE listings (
        id int,
        name varchar(100),
        description text,
        property_type varchar(25),
        room_type varchar(30),
        price numeric,
        weekly_price numeric
    );
    ```

2. Next, you will use the `COPY` command to load data from CSV files into each of the tables you created above. Start by running the following command to populate the `listings` table:

    ```sql
    \COPY listings FROM 'mslearn-postgresql/Allfiles/Labs/Shared/listings.csv' CSV HEADER
    ```

    The output of the command should be `COPY 50`, indicating that 50 rows were written into the table from the CSV file.

## Install and configure the `azure_ai` extension

Before using the `azure_ai` extension, you must install it into your database and configure it to connect to your Azure AI Services resources. The `azure_ai` extension allows you to integrate the Azure OpenAI and Azure AI Language services into your database. To enable the extension in your database, follow the steps below:

1. You should first verify that the `azure_ai` extension was successfully added to your server's _allowlist_ by the bicep script you ran when setting up the exercise environment by executing the following command at the `psql` command prompt:

    ```sql
    SHOW azure.extensions;
    ```

    In the output, you will see the list of extensions on the server's _allowlist_. The output should include `azure_ai` and will look like the following:

    ```sql
     azure.extensions 
    ------------------
     azure_ai,vector
    ```

    Before an extension can be installed and used in Azure Database for PostgreSQL - Flexible Server, it must be added to the server's _allowlist_, as described in [how to use PostgreSQL extensions](https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-extensions#how-to-use-postgresql-extensions).

2. Now, you are ready to install the `azure_ai` extension using the [CREATE EXTENSION](https://www.postgresql.org/docs/current/sql-createextension.html) command.

    ```sql
    CREATE EXTENSION IF NOT EXISTS azure_ai;
    ```

    `CREATE EXTENSION` loads a new extension into the database by running the extension's script file, which typically creates new SQL objects such as functions, data types and schemas. If an extension of the same name already exists, an error will be thrown. Adding `IF NOT EXISTS` allows the command to execute without throwing an error if it is already installed.





## Procedure 1

Procedure overview

1. Step 1
2. Step 2
3. etc.

## Procedure n

Procedure overview

1. Step 1
2. Step 2
3. etc.

## Clean up

After you've cmpleted this exercise, you should delete the Azure resources you have created.

1. Step 1
2. Step 2.
3. etc.



Throughout this exercise, you will dive into real-world examples, experiment with various prompts, and evaluate their impact on summarization quality.

This exercise will need to be a bit different because there is no way to do query-based summarization directly from PostgreSQL. The `azure_ai` extension only allows `create_embeddings` functionality against Azure OpenAI. So, for this exercise, the focus needs to be on how this can be done from an application.

TODO: Determine how we can run this from the lab environment. Does a simple app (like Streamlit) need to be used, where users can write/execute the code from a web-based UI, or how should this happen?

TODO: Lab steps

1. Connect to existing Azure OpenAI Service (created in Module 1)
2. Get Language service key and endpoint
3. Set up connection to database
4. Configure azure_ai extension with endpoint and key for azure_cognitive schema
5. Connect to reviews table
6. Use `azure_cognitive.summarize_extractive()` method to generate extractive summaries for a few records (limit this to just showcase the capability and not to do it for all records in the table, as it is a large table.)
7. Use `azure_cognitive.summarize_abstractive()` method to generate abstractive summaries for a few records (limit this to just showcase the capability and not to do it for all records in the table, as it is a large table.)
8. Compare the outputs from the two methods
9. Talk about performance and implications for using each method?

- The steps to create an Azure AI Services Language service in the Azure portal are as follows:
  - Navigate to the [Azure portal](https://portal.azure.com/).
  - Select **Create a resource** under **Azure services** on the Azure home page, then enter "Language service" into the **Search the Marketplace** box on the Marketplace page and select the **Language service** tile in the search results.
  - Select **Create** on the **Language service** page to create a new language service resource.
  - Select **Continue to create your resource** on the **Select additional features** page.
  - On the Create Language **Basics** tab:
    - Ensure you select the same resource group that you chose for your Azure OpenAI service.
    - Set the region to one of the [regions that supports abstractive summarization](https://learn.microsoft.com/azure/ai-services/language-service/summarization/region-support) (**North Europe**, **East US**, **UK South**, or **Southeast Asia**). This does not have to be the same region associated with your other resources.
    - Provide a _globally unique_ service name.
    - You can choose either the **Free F0** or **S** pricing tier for this service.
    - Ensure the box certifying you have reviewed and acknowledge the terms in the Responsible AI Notice is checked.
  - Select the **Review + create** button to review your choices and then select **Create** to provision the service.

    ![The settings to create a Language service are displayed on the Create Language Basics tab.](../../media/Solution/0601_Language_Service.png)

- The steps to retrieve the endpoint and key values for your Language service and add them to `config.json` are as follows:
  - Navigate to your Language service resource in the [Azure portal](https://portal.azure.com/).
  - Select the **Keys and Endpoint** menu item under **Resource Management** in the left-hand menu.
  - Copy the **Endpoint** value and paste it into the `config.json` file as the **LanguageEndpoint** value.
  - Copy the **KEY 1** value and paste it into the `config.json` file as the **LanguageKey** value.

    ![The Language service's Keys and Endpoint page is displayed, with the Endpoint and KEY 1 copy to clipboard buttons highlighted.](../../media/Solution/0601-Language-Keys-and-Endpoint.png)