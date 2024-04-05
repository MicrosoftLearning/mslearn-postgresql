---
lab:
    title: 'Perform Extractive and Abstractive Summarization'
    module: 'Build AI apps with Azure Database for PostgreSQL'
---

# Perform Extractive and Abstractive Summarization

In this exercise, you use the `azure_ai` extension in Azure Database For PostgreSQL - Flexible Server to perform abstractive and extractive summarization on rental property descriptions and compare the resulting summaries.

## Before you start

You will need an [Azure subscription](https://azure.microsoft.com/free) where you have administrative rights.

### Deploy resources into your Azure subscription

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/).

2. Select the **Cloud Shell** icon in the Azure portal toolbar to open a new [Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) pane at the bottom of your browser window.

    ![Screenshot of the Azure toolbar with the Cloud Shell icon highlighted with a red box.](media/11-portal-toolbar-cloud-shell.png)

3. At the cloud shell prompt, enter the following to clone the GitHub repo containing exercise resources:

    ```bash
    git clone https://github.com/MicrosoftLearning/mslearn-postgresql.git
    ```

4. Next, you will run a couple of commands to define variables to reduce redundant typing when using commands to create Azure resources. The variables represent the name to assign to your resource group and the Azure region into which resources should be deployed.

    The resource group name defaults to `rg-postgresql-ai-ms-learn`, but you can provide any name you wish to use to host the resources associated with this exercise.

    ```bash
    RG_NAME=rg-postgresql-ai-ms-learn-kb
    ```

    In the command below, accept the default region of `eastus` or replace it with one of the other [Azure regions that supports abstractive summarization](https://learn.microsoft.com/azure/ai-services/language-service/summarization/region-support).

    ```bash
    REGION=eastus
    ```

5. Run the following Azure CLI command to create your resource group:

    ```azurecli
    az group create --name $RG_NAME --location $REGION
    ```

6. Finally, use the Azure CLI to execute a Bicep deployment script to provision Azure resources in your resource group:

    ```azurecli
    az deployment group create --resource-group $RG_NAME --template-file "mslearn-postgresql/Allfiles/Labs/Shared/deploy.bicep" --parameters adminLogin=pgAdmin adminLoginPassword=Password123!
    ```

    The bicep file will deploy an Azure Database for PostgreSQL - Flexible Server and an Azure AI Language service into your resource group. On the PostgreSQL server, it also adds the `azure_ai` extension to the server's _allowlist_ and creates a database named `rentals` for use in this exercise.

    The deployment will take several minutes to complete.

7. Close the cloud shell pane once your resource deployment has completed.

## Connect to your database using psql in the Azure Cloud Shell

In this task, you use the [psql command-line utility](https://www.postgresql.org/docs/current/app-psql.html) from the [Azure Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) to connect to your database.

1. In the [Azure portal](https://portal.azure.com/), navigate to your newly created Azure Database for PostgreSQL Flexible Server instance.

2. Once there, select **Databases** under **Settings** the left-hand navigation menu, and then select **Connect** for the `rentals` database.

    ![Screenshot of the Azure Database for PostgreSQL Databases page. Databases and Connect for the rentals database are highlighted with red boxes.](media/11-postgresql-rentals-database-connect.png)

3. At the "Password for user pgAdmin" prompt in the cloud shell, enter the password you created for the **pgAdmin** login. The default for this is `Password123!`.

    Once logged in, you will be at the `psql` prompt for the rentals database.

## Populate the database with sample data

Before you get started exploring the `azure_ai` extension, you will add a couple of tables to the `rentals` database and populate them with sample data.

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

    TODO: Remove the reviews table from this one. It isn't used.

    ```sql
    CREATE TABLE reviews (
        id int,
        listing_id int, 
        date date,
        comments text
    );
    ```

2. Next, you will use the `COPY` command to load data from CSV files into each of the tables you created above. Start by running the following command to populate the `listings` table:

    ```sql
    \COPY listings FROM 'mslearn-postgresql/Allfiles/Labs/Shared/listings.csv' CSV HEADER
    ```

    The output of the command should be `COPY 50`, indicating that 50 rows were written into the table from the CSV file.

3. Finally, run the command below to load customer reviews into the `reviews` table:

    TODO: Remove the reviews table from this one. It isn't used.

    ```sql
    \COPY reviews FROM 'mslearn-postgresql/Allfiles/Labs/Shared/reviews.csv' CSV HEADER
    ```

    The output of the command should be `COPY 354`, indicating that 354 rows were written into the table from the CSV file.

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



## TODO: Lab steps

1. Create Language Service
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