---
lab:
    title: 'Perform Sentiment Analysis'
    module: 'Build AI apps with Azure Database for PostgreSQL'
---

# Perform Sentiment Analysis

As part of the AI-powered app you are building for Margie's Travel, you would like to provide users with information on the sentiment of individual reviews and the overall sentiment of all reviews for a given rental listing. To accomplish this, you will use the `azure_ai` extension in Azure Database for PostgreSQL - Flexible Server to integrate sentiment analysis capabilities into your database.

## Before you start

You will need an [Azure subscription](https://azure.microsoft.com/free), where you have administrative rights.

### Deploy resources into your Azure subscription

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/).

2. Select the **Cloud Shell** icon in the Azure portal toolbar to open a new [Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) pane at the bottom of your browser window.

    ![Screenshot of the Azure toolbar with the Cloud Shell icon highlighted by a red box.](media/16-portal-toolbar-cloud-shell.png)

3. At the cloud shell prompt, enter the following to clone the GitHub repo containing exercise resources:

    ```bash
    git clone https://github.com/MicrosoftLearning/mslearn-postgresql.git
    ```

4. Next, you will run a couple of commands to define variables to reduce redundant typing when using Azure CLI commands to create Azure resources. The variables represent the name to assign to your resource group and the Azure region into which resources should be deployed.

    In the first command below, accept the default region of `eastus` or replace it with the location you prefer to use for your Azure resources.

    ```bash
    REGION=eastus
    ```

    The resource group name defaults to `rg-postgresql-ai-ms-learn`, but you can provide any name you wish to use to host the resources associated with this exercise.

    ```bash
    RG_NAME=rg-learn-postgresql-ai-$REGION
    ```

5. Run the following Azure CLI command to create your resource group:

    ```azurecli
    az group create --name $RG_NAME --location $REGION
    ```

6. Finally, use the Azure CLI to execute a Bicep deployment script to provision Azure resources in your resource group. The command below includes parameters for the server admin login name, `pgAdmin`, and its password, `Password123!`. If you wish to change either of these, you can modify the command parameters before running it.

    ```azurecli
    az deployment group create --resource-group $RG_NAME --template-file "mslearn-postgresql/Allfiles/Labs/Shared/deploy.bicep" --parameters adminLogin=pgAdmin adminLoginPassword=Password123!
    ```

    The bicep file will deploy an Azure Database for PostgreSQL - Flexible Server and an Azure AI Language service into your resource group. On the PostgreSQL server, it also adds the `azure_ai` extension to the server's _allowlist_ and creates a database named `rentals` for you to use throughout this exercise.

    The deployment typically takes several minutes to complete. You can monitor it from the cloud shell, or navigate to the **Deployments** page for the resource group you created above and observe the deployment progress there.

7. Close the cloud shell pane once your resource deployment is complete.

## Connect to your database using psql in the Azure Cloud Shell

In this task, you connect to your `rentals` database using the [psql command-line utility](https://www.postgresql.org/docs/current/app-psql.html) from the [Azure Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview).

1. In the [Azure portal](https://portal.azure.com/), navigate to your newly created Azure Database for PostgreSQL Flexible Server instance.

2. Once there, select **Databases** under **Settings** the left-hand navigation menu, and then select the **Connect** link for the `rentals` database.

    ![Screenshot of the Azure Database for PostgreSQL Databases page. Databases and Connect for the rentals database are highlighted by red boxes.](media/16-postgresql-rentals-database-connect.png)

3. At the "Password for user pgAdmin" prompt in the cloud shell, enter the password you created for the server admin login. The default for this is `Password123!`.

    Once logged in, the `psql` prompt for the `rentals` database will be displayed.

## Populate the database with sample data

Before you can analyze the sentiment of rental property reviews using the `azure_ai` extension, you must add sample data to your database. You will add a table to the `rentals` database and populate it with customer reviews so you have data on which to perform sentiment analysis.

1. Run the following command to create a table named `reviews` for storing property reviews submitted by customers:

    ```sql
    CREATE TABLE reviews (
        id int,
        listing_id int, 
        date date,
        comments text
    );
    ```

2. Next, you will use the `COPY` command to populate the table with data from a CSV file. Execute the command below to load customer reviews into the `reviews` table:

    ```sql
    \COPY reviews FROM 'mslearn-postgresql/Allfiles/Labs/Shared/reviews.csv' CSV HEADER
    ```

    The command output should be `COPY 354`, indicating that 354 rows were written into the table from the CSV file.

## Install and configure the `azure_ai` extension

Before using the `azure_ai` extension, you must install it into your database and configure it to connect to your Azure AI Services resource. The `azure_ai` extension allows you to integrate the Azure AI Language services directly into your database. To enable the extension in your database, follow the steps below:

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

## Integrate Azure AI Services

The Azure AI services integrations included in the `azure_cognitive` schema of the `azure_ai` extension provide a rich set of AI Language features accessible directly from the database. Sentiment analysis capabilities are enabled through the [Azure AI Language service](https://learn.microsoft.com/azure/ai-services/language-service/overview).

1. To successfully make calls against Azure AI services using the `azure_ai` extension, you must provide the endpoint and a key for your Azure AI Language service. Using the same browser tab where the Cloud Shell is open, navigate to your Language service resource in the [Azure portal](https://portal.azure.com/) and select the **Keys and Endpoint** item under **Resource Management** from the left-hand navigation menu.

    ![Screenshot of the Azure Language service's Keys and Endpoints page is displayed, with the KEY 1 and Endpoint copy buttons highlighted by red boxes.](media/16-azure-language-service-keys-and-endpoints.png)

2. Copy your endpoint and access key values, then in the commands below, replace the `{endpoint}` and `{api-key}` tokens with values you retrieved from the Azure portal. Run the commands from the `psql` command prompt in the cloud shell to add your values to the `azure_ai.settings` table.

    ```sql
    SELECT azure_ai.set_setting('azure_cognitive.endpoint','{endpoint}');
    ```

    ```sql
    SELECT azure_ai.set_setting('azure_cognitive.subscription_key', '{api-key}');
    ```

### Analyze the sentiment of reviews

In this task, you will use the `azure_cognitive.analyze_sentiment` function to evaluate reviews of rental property listings.

1. You will be working exclusively in the cloud shell for the remainder of this exercise, so it can be helpful to expand the pane within your browser window by selecting the **Maximize** button at the top right of the cloud shell pane.

    ![Screenshot of the Azure Cloud Shell pane with the Maximize button highlighted by a red box.](media/16-azure-cloud-shell-pane-maximize.png)

2. When working with `psql` in the cloud shell, it can be useful to enable the extended display for query results. Execute the following command to enable the extended display to be automatically applied when it will improve output display.

    ```sql
    \x auto
    ```

3. The sentiment analysis capabilities of the `azure_ai` extension are found within the `azure_cognitive` schema. You use the `analyze_sentiment` function. Run the command below to review that function:

    ```sql
    \df azure_cognitive.analyze_sentiment
    ```

    The output shows the function's schema, name, result data type, and argument data types. This information can help you understand how to interact with the function from your queries.

    TODO: Add a bit more here about the three overloads of the function and the differences between them. Also briefly talk about the retry delay and max attempts params. Also talk about the requirements arguments (text and language). Perhaps provide a link to the supported languages?

4. An essential aspect of working with the `analyze_sentiment()` function is understanding the structure of the result data type so you can correctly handle its return value. Run the following command to inspect the `sentiment_analysis_result` type:

    ```sql
    \dT+ azure_cognitive.sentiment_analysis_result
    ```

5. The output of the above command reveals the `sentiment_analysis_result` type is a `tuple`. To understand the structure of that `tuple`,  run the following command to look at the columns contained within the `sentiment_analysis_result` composite type:

    ```sql
    \d+ azure_cognitive.sentiment_analysis_result
    ```

    The output of that command should look similar to the following:

    ```sql
                     Composite type "azure_cognitive.sentiment_analysis_result"
         Column     |       Type       | Collation | Nullable | Default | Storage  | Description 
    ----------------+------------------+-----------+----------+---------+----------+-------------
     sentiment      | text             |           |          |         | extended | 
     positive_score | double precision |           |          |         | plain    | 
     neutral_score  | double precision |           |          |         | plain    | 
     negative_score | double precision |           |          |         | plain    |
    ```

    The `azure_cognitive.sentiment_analysis_result` is a composite type containing the sentiment predictions of the input text. It includes the sentiment, which can be positive, negative, neutral, or mixed, and the scores for positive, neutral, and negative aspects found in the text. The scores are represented as real numbers between 0 and 1. For example, in (neutral,0.26,0.64,0.09), the sentiment is neutral with a positive score of 0.26, neutral of 0.64, and negative at 0.09.

6. Now that you have an understanding of the `analyze_sentiment` function and its return type, it is time to put it into action. To start, execute the following simple query, which performs sentiment analysis inline on a couple of reviews:

    ```sql
    SELECT
        id,
        comments,
        azure_cognitive.analyze_sentiment(comments, 'en') AS sentiment
    FROM reviews
    WHERE id IN (1, 3);
    ```

    Using the `analyze_sentiment()` function inline allows you to quickly analyze sentiment of text directly within your queries.

    TODO: talk about the overload of the function used above, sending in only a single string of text at a time, and how that might not be the most efficient approach when dealing with a larger number of records.

    TODO: Talk about the output, focusing on the return type (one mixed and on positive).

    TODO: Set up an example that passes in an array of comments to be analyzed, so we can also look at that return type.

7. With the above approach, the sentiment of the entire review is analyzed, but there may be times when you want to analyze each sentence within a block of text. To do this, you can use the overload of the `analyze_sentiment()` function that accepts an array of text.

    ```sql
    SELECT
        azure_cognitive.analyze_sentiment(ARRAY_REMOVE(STRING_TO_ARRAY(comments, '.'), ''), 'en') AS sentence_sentiments
    FROM reviews
    WHERE id = 1;
    ```

    In the above query, you used the `STRING_TO_ARRAY` function from PostgreSQL, and to ensure there are no empty array elements, which will cause errors with the `analyze_sentiment()` function, the `ARRAY_REMOVE` function was also used to remove any elements that are an empty string.

8. The previous query returned the `sentiment_analysis_result` directly from the query. However, you will most likely want to get at the underlying values within that `tuple`. Execute the following query that looks for overwhelmingly positive reviews and extracts the sentiment components into individual fields:

    ```sql
    WITH cte AS (
        SELECT id, comments, azure_cognitive.analyze_sentiment(comments, 'en') AS sentiment FROM reviews LIMIT 100
    )
    SELECT
        id,
        (sentiment).sentiment,
        (sentiment).positive_score,
        (sentiment).neutral_score,
        (sentiment).negative_score,
        comments
    FROM cte
    WHERE (sentiment).positive_score > 0.98
    LIMIT 5;
    ```

    The above query uses a common table expression or CTE to get the sentiment scores for the first 100 records in the `reviews` table. It then selects the `sentiment` composite type columns from the CTE to extract the individual values from the `sentiment_analysis_result`.

9. You can likewise run a similar query to look for negative reviews:

    ```sql
    WITH cte AS (
        SELECT id, comments, azure_cognitive.analyze_sentiment(comments, 'en') AS sentiment FROM reviews LIMIT 100
    )
    SELECT
        id,
        (sentiment).sentiment,
        (sentiment).positive_score,
        (sentiment).neutral_score,
        (sentiment).negative_score,
        comments
    FROM cte
    WHERE (sentiment).negative_score > 0.70
    LIMIT 5;
    ```

10. TODO: Run another query to insert the values into new columns in the database.

    ```sql
    ALTER TABLE reviews
    ADD COLUMN sentiment varchar(10),
    ADD COLUMN positive_score numeric,
    ADD COLUMN neutral_score numeric,
    ADD COLUMN negative_score numeric;
    ```

11. TODO: Write insert query

    TODO: Performing sentiment analysis on the fly can be great for small numbers of records or analyzing data in near-real time, but for your stored reviews, it makes sense to add the sentiment data into the database for use in your application.

    First, you want to update the existing records in the database...

    This is where we can talk about retries and max attempts...

    ```sql
    WITH cte AS (
        SELECT
            id,
            azure_cognitive.analyze_sentiment(comments, 'en', throw_on_error=false, ) AS sentiment
        FROM reviews
    )
    UPDATE reviews AS r
    SET
        (sentiment).sentiment,
        (sentiment).positive_score,
        (sentiment).neutral_score,
        (sentiment).negative_score
    FROM cte
    WHERE r.id = cte.id;
    ```

12. TODO: Write a query or stored procedure that can be used to analyze sentiment as new reviews are submitted and talk about how that could be used by the app.

    ```sql
    TODO: write query to insert the data into the new columns in the database.
    ```

## Clean up

After you have completed this exercise, you should delete the Azure resources you have created. You are charged for the configured capacity, not how much the database is used. To delete your resource group and all resources you created for this lab, follow the instructions below:

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/), and on the home page, select **Resource groups** under Azure services.

    ![Resource groups is highlighted under Azure services in the Azure portal.](media/azure-portal-home-azure-services-resource-groups.png)

2. In the filter for any field search box, enter the name of the resource group you created for these labs in Lab 1, and then select the resource group from the list.

3. In the **Overview** pane, select **Delete resource group**.

    ![On the Overview blade of the resource group. The Delete resource group button is highlighted.](media/resource-group-delete.png)

4. In the confirmation dialog, enter the name of the resource group you created to confirm and then select **Delete**.
