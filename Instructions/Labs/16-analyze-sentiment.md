---
lab:
    title: 'Analyze Sentiment'
    module: 'Perform Sentiment Analysis and Opinion Mining using Azure Database for PostgreSQL'
---

# Analyze Sentiment

As part of the AI-powered app you are building for Margie's Travel, you want to provide users with information on the sentiment of individual reviews and the overall sentiment of all reviews for a given rental property. To accomplish this, use the `azure_ai` extension in an Azure Database for PostgreSQL flexible server to integrate sentiment analysis functionality into your database.

## Before you start

You need an [Azure subscription](https://azure.microsoft.com/free) with administrative rights.

### Deploy resources into your Azure subscription

This step guides you through using Azure CLI commands from the Azure Cloud Shell to create a resource group and run a Bicep script to deploy the Azure services necessary for completing this exercise into your Azure subscription.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/).

2. Select the **Cloud Shell** icon in the Azure portal toolbar to open a new [Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) pane at the bottom of your browser window.

    ![Screenshot of the Azure toolbar with the Cloud Shell icon highlighted by a red box.](media/11-portal-toolbar-cloud-shell.png)

    If prompted, select the required options to open a *Bash* shell. If you have previously used a *PowerShell* console, switch it to a *Bash* shell.

3. At the Cloud Shell prompt, enter the following to clone the GitHub repo containing exercise resources:

    ```bash
    git clone https://github.com/MicrosoftLearning/mslearn-postgresql.git
    ```

4. Next, you run three commands to define variables to reduce redundant typing when using Azure CLI commands to create Azure resources. The variables represent the name to assign to your resource group (`RG_NAME`), the Azure region (`REGION`) into which resources will be deployed, and a randomly generated password for the PostgreSQL administrator login (`ADMIN_PASSWORD`).

    In the first command, the region assigned to the corresponding variable is `eastus`, but you can also replace it with a location of your preference. However, if replacing the default, you must select another [Azure region that supports abstractive summarization](https://learn.microsoft.com/azure/ai-services/language-service/summarization/region-support) to ensure you can complete all of the tasks in the modules in this learning path.

    ```bash
    REGION=eastus
    ```

    The following command assigns the name to be used for the resource group that will house all the resources used in this exercise. The resource group name assigned to the corresponding variable is `rg-learn-postgresql-ai-$REGION`, where `$REGION` is the location you specified above. However, you can change it to any other resource group name that suits your preference.

    ```bash
    RG_NAME=rg-learn-postgresql-ai-$REGION
    ```

    The final command randomly generates a password for the PostgreSQL admin login. **Make sure you copy it** to a safe place to use later to connect to your PostgreSQL flexible server.

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
    az deployment group create --resource-group $RG_NAME --template-file "mslearn-postgresql/Allfiles/Labs/Shared/deploy.bicep" --parameters restore=false adminLogin=pgAdmin adminLoginPassword=$ADMIN_PASSWORD
    ```

    The Bicep deployment script provisions the Azure services required to complete this exercise into your resource group. The resources deployed include an Azure Database for PostgreSQL flexible server, Azure OpenAI, and an Azure AI Language service. The Bicep script also performs some configuration steps, such as adding the `azure_ai` and `vector` extensions to the PostgreSQL server's _allowlist_ (via the azure.extensions server parameter), creating a database named `rentals` on the server, and adding a deployment named `embedding` using the `text-embedding-ada-002` model to your Azure OpenAI service. Note that the Bicep file is shared by all modules in this learning path, so you may only use some of the deployed resources in some exercises.

    The deployment typically takes several minutes to complete. You can monitor it from the Cloud Shell or navigate to the **Deployments** page for the resource group you created above and observe the deployment progress there.

8. Close the Cloud Shell pane once your resource deployment is complete.

### Troubleshooting deployment errors

You may encounter a few errors when running the Bicep deployment script. The most common messages and the steps to resolve them are:

- If you previously ran the Bicep deployment script for this learning path and subsequently deleted the resources, you may receive an error message like the following if you are attempting to rerun the script within 48 hours of deleting the resources:

    ```bash
    {"code": "InvalidTemplateDeployment", "message": "The template deployment 'deploy' is not valid according to the validation procedure. The tracking id is '4e87a33d-a0ac-4aec-88d8-177b04c1d752'. See inner errors for details."}
    
    Inner Errors:
    {"code": "FlagMustBeSetForRestore", "message": "An existing resource with ID '/subscriptions/{subscriptionId}/resourceGroups/rg-learn-postgresql-ai-eastus/providers/Microsoft.CognitiveServices/accounts/{accountName}' has been soft-deleted. To restore the resource, you must specify 'restore' to be 'true' in the property. If you don't want to restore existing resource, please purge it first."}
    ```

    If you receive this message, modify the `azure deployment group create` command above to set the `restore` parameter equal to `true` and rerun it.

- If the selected region is restricted from provisioning specific resources, you must set the `REGION` variable to a different location and rerun the commands to create the resource group and run the Bicep deployment script.

    ```bash
    {"status":"Failed","error":{"code":"DeploymentFailed","target":"/subscriptions/{subscriptionId}/resourceGroups/{resourceGrouName}/providers/Microsoft.Resources/deployments/{deploymentName}","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.","details":[{"code":"ResourceDeploymentFailure","target":"/subscriptions/{subscriptionId}/resourceGroups/{resourceGrouName}/providers/Microsoft.DBforPostgreSQL/flexibleServers/{serverName}","message":"The resource write operation failed to complete successfully, because it reached terminal provisioning state 'Failed'.","details":[{"code":"RegionIsOfferRestricted","message":"Subscriptions are restricted from provisioning in this region. Please choose a different region. For exceptions to this rule please open a support request with Issue type of 'Service and subscription limits'. See https://review.learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-request-quota-increase for more details."}]}]}}
    ```

- If the script is unable to create an AI resource due to the requirement to accept the responsible AI agreement, you may experience the following error; in which case use the Azure Portal user interface to create an Azure AI Services resource, and then re-run the deployment script.

    ```bash
    {"code": "InvalidTemplateDeployment", "message": "The template deployment 'deploy' is not valid according to the validation procedure. The tracking id is 'f8412edb-6386-4192-a22f-43557a51ea5f'. See inner errors for details."}
     
    Inner Errors:
    {"code": "ResourceKindRequireAcceptTerms", "message": "This subscription cannot create TextAnalytics until you agree to Responsible AI terms for this resource. You can agree to Responsible AI terms by creating a resource through the Azure Portal then trying again. For more detail go to https://go.microsoft.com/fwlink/?linkid=2164190"}
    ```

## Connect to your database using psql in the Azure Cloud Shell

In this task, you connect to the `rentals` database on your Azure Database for PostgreSQL server using the [psql command-line utility](https://www.postgresql.org/docs/current/app-psql.html) from the [Azure Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview).

1. In the [Azure portal](https://portal.azure.com/), navigate to your newly created Azure Database for PostgreSQL flexible server instance.

2. In the resource menu, under **Settings**, select **Databases** select **Connect** for the `rentals` database.

    ![Screenshot of the Azure Database for PostgreSQL Databases page. Databases and Connect for the rentals database are highlighted by red boxes.](media/17-postgresql-rentals-database-connect.png)

3. At the "Password for user pgAdmin" prompt in the Cloud Shell, enter the randomly generated password for the **pgAdmin** login.

    Once logged in, the `psql` prompt for the `rentals` database is displayed.

## Populate the database with sample data

Before you can analyze the sentiment of rental property reviews using the `azure_ai` extension, you must add sample data to your database. Add a table to the `rentals` database and populate it with customer reviews so you have data on which to perform sentiment analysis.

1. Run the following command to create a table named `reviews` for storing property reviews submitted by customers:

    ```sql
    DROP TABLE IF EXISTS reviews;

    CREATE TABLE reviews (
        id int,
        listing_id int, 
        date date,
        comments text
    );
    ```

2. Next, use the `COPY` command to populate the table with data from a CSV file. Execute the command below to load customer reviews into the `reviews` table:

    ```sql
    \COPY reviews FROM 'mslearn-postgresql/Allfiles/Labs/Shared/reviews.csv' CSV HEADER
    ```

    The command output should be `COPY 354`, indicating that 354 rows were written into the table from the CSV file.

## Install and configure the `azure_ai` extension

Before using the `azure_ai` extension, you must install it into your database and configure it to connect to your Azure AI Services resources. The `azure_ai` extension allows you to integrate the Azure OpenAI and Azure AI Language services into your database. To enable the extension in your database, follow these steps:

1. Execute the following command at the `psql` prompt to verify that the `azure_ai` and the `vector` extensions were successfully added to your server's _allowlist_ by the Bicep deployment script you ran when setting up your environment:

    ```sql
    SHOW azure.extensions;
    ```

    The command displays the list of extensions on the server's _allowlist_. If everything was correctly installed, your output must include `azure_ai` and `vector`, like this:

    ```sql
     azure.extensions 
    ------------------
     azure_ai,vector
    ```

    Before an extension can be installed and used in an Azure Database for PostgreSQL flexible server database, it must be added to the server's _allowlist_, as described in [how to use PostgreSQL extensions](https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-extensions#how-to-use-postgresql-extensions).

2. Now, you are ready to install the `azure_ai` extension using the [CREATE EXTENSION](https://www.postgresql.org/docs/current/sql-createextension.html) command.

    ```sql
    CREATE EXTENSION IF NOT EXISTS azure_ai;
    ```

    `CREATE EXTENSION` loads a new extension into the database by running its script file. This script typically creates new SQL objects such as functions, data types, and schemas. An error is thrown if an extension of the same name already exists. Adding `IF NOT EXISTS` allows the command to execute without throwing an error if it is already installed.

## Connect Your Azure AI Services Account

The Azure AI services integrations included in the `azure_cognitive` schema of the `azure_ai` extension provide a rich set of AI Language features accessible directly from the database. Sentiment analysis capabilities are enabled through the [Azure AI Language service](https://learn.microsoft.com/azure/ai-services/language-service/overview).

1. To successfully make calls against your Azure AI Language services using the `azure_ai` extension, you must provide its endpoint and key to the extension. Using the same browser tab where the Cloud Shell is open, navigate to your Language service resource in the [Azure portal](https://portal.azure.com/) and select the **Keys and Endpoint** item under **Resource Management** from the left-hand navigation menu.

    ![Screenshot of the Azure Language service's Keys and Endpoints page is displayed, with the KEY 1 and Endpoint copy buttons highlighted by red boxes.](media/16-azure-language-service-keys-endpoints.png)

> [!Note]
>
> If you received the message `NOTICE: extension "azure_ai" already exists, skipping CREATE EXTENSION` when installing the `azure_ai` extension above and have previously configured the extension with your Language service endpoint and key, you can use the `azure_ai.get_setting()` function to confirm those settings are correct, and then skip step 2 if they are.

2. Copy your endpoint and access key values, then in the commands below, replace the `{endpoint}` and `{api-key}` tokens with values you copied from the Azure portal. Run the commands from the `psql` command prompt in the Cloud Shell to add your values to the `azure_ai.settings` table.

    ```sql
    SELECT azure_ai.set_setting('azure_cognitive.endpoint', '{endpoint}');
    ```

    ```sql
    SELECT azure_ai.set_setting('azure_cognitive.subscription_key', '{api-key}');
    ```

## Review the Analyze Sentiment Capabilities of the Extension

In this task, you use the `azure_cognitive.analyze_sentiment()` function to evaluate reviews of rental property listings.

1. For the remainder of this exercise, you work exclusively in the Cloud Shell, so it may be helpful to expand the pane within your browser window by selecting the **Maximize** button at the top right of the Cloud Shell pane.

    ![Screenshot of the Azure Cloud Shell pane with the Maximize button highlighted by a red box.](media/16-azure-cloud-shell-pane-maximize.png)

2. When working with `psql` in the Cloud Shell, enabling the extended display for query results may be helpful, as it improves the readability of output for subsequent commands. Execute the following command to allow the extended display to be automatically applied.

    ```sql
    \x auto
    ```

3. The sentiment analysis capabilities of the `azure_ai` extension are found within the `azure_cognitive` schema. You use the `analyze_sentiment()` function. Use the [`\df` meta-command](https://www.postgresql.org/docs/current/app-psql.html#APP-PSQL-META-COMMAND-DF-LC) to examine the function by running:

    ```sql
    \df azure_cognitive.analyze_sentiment
    ```

    The meta-command output shows the function's schema, name, result data type, and arguments. This information helps you understand how to interact with the function from your queries.

    The output shows three overloads of the `analyze_sentiment()` function, allowing you to review their differences. The `Argument data types` property in the output reveals the list of arguments the three function overloads expect:

    | Argument | Type | Default | Description |
    | -------- | ---- | ------- | ----------- |
    | text | `text` or `text[]` || The text(s) for which sentiment should be analyzed. |
    | language_text | `text` or `text[]` || Language code (or array of language codes) representing the language of the text to analyze for sentiment. Review the [list of supported languages](https://learn.microsoft.com/azure/ai-services/language-service/sentiment-opinion-mining/language-support) to retrieve the necessary language codes. |
    | batch_size | `integer` | 10 | Only for the two overload expecting an input of `text[]`. Specifies the number of records to process at a time. |
    | disable_service_logs | `boolean` | false | Flag indicating whether to turn off service logs. |
    | timeout_ms | `integer` | NULL | Timeout in milliseconds after which the operation is stopped. |
    | throw_on_error | `boolean` | true | Flag indicating whether the function should, on error, throw an exception resulting in a rollback of the wrapping transaction. |
    | max_attempts | `integer` | 1 | Number of times to retry the call to Azure AI Services in the event of a failure. |
    | retry_delay_ms | `integer` | 1000 | Amount of time, in milliseconds, to wait before attempting to retry calling the Azure AI Services endpoint. |

4. It is also imperative to understand the structure of the data type that a function returns so you can correctly handle the output in your queries. Run the following command to inspect the `sentiment_analysis_result` type:

    ```sql
    \dT+ azure_cognitive.sentiment_analysis_result
    ```

5. The output of the above command reveals the `sentiment_analysis_result` type is a `tuple`. You can dig further into the structure of that `tuple` by running the following command to look at the columns contained within the `sentiment_analysis_result` type:

    ```sql
    \d+ azure_cognitive.sentiment_analysis_result
    ```

    The output of that command should look similar to the following:

    ```sql
                     Composite type "azure_cognitive.sentiment_analysis_result"
         Column     |     Type         | Collation | Nullable | Default | Storage  | Description 
    ----------------+------------------+-----------+----------+---------+----------+-------------
     sentiment      | text             |           |          |         | extended | 
     positive_score | double precision |           |          |         | plain    | 
     neutral_score  | double precision |           |          |         | plain    | 
     negative_score | double precision |           |          |         | plain    |
    ```

    The `azure_cognitive.sentiment_analysis_result` is a composite type containing the sentiment predictions of the input text. It includes the sentiment, which can be positive, negative, neutral, or mixed, and the scores for positive, neutral, and negative aspects found in the text. The scores are represented as real numbers between 0 and 1. For example, in (neutral, 0.26, 0.64, 0.09), the sentiment is neutral, with a positive score of 0.26, neutral of 0.64, and negative at 0.09.

## Analyze the sentiment of reviews

1. Now that you have reviewed the `analyze_sentiment()` function and the `sentiment_analysis_result` it returns, let's put the function to use. Execute the following simple query, which performs sentiment analysis on a handful of comments in the `reviews` table:

    ```sql
    SELECT
        id,
        azure_cognitive.analyze_sentiment(comments, 'en') AS sentiment
    FROM reviews
    WHERE id <= 10
    ORDER BY id;
    ```

    From the two records analyzed, note the `sentiment` values in the output, `(mixed,0.71,0.09,0.2)` and `(positive,0.99,0.01,0)`. These represent the `sentiment_analysis_result` returned by the `analyze_sentiment()` function in the above query. The analysis was performed over the `comments` field in the `reviews` table.

    > [!Note]
    >
    > Using the `analyze_sentiment()` function inline lets you quickly analyze the text's sentiment within your queries. While this works well for a small number of records, it may not be ideal for analyzing the sentiment of a large number of records or updating all the records in a table that may contain tens of thousands of reviews or more.

2. Another approach that can be useful for longer reviews is to analyze the sentiment of each sentence within it. To do this, use the overload of the `analyze_sentiment()` function, which accepts an array of text.

    ```sql
    SELECT
        azure_cognitive.analyze_sentiment(ARRAY_REMOVE(STRING_TO_ARRAY(comments, '.'), ''), 'en') AS sentence_sentiments
    FROM reviews
    WHERE id = 1;
    ```

    In the above query, you used PostgreSQL's `STRING_TO_ARRAY` function. Additionally, the `ARRAY_REMOVE` function was used to remove any array elements that are empty strings, as these will cause errors with the `analyze_sentiment()` function.

    The output from the query allows you to get a better understanding of the `mixed` sentiment assigned to the overall review. The sentences are a mixture of positive, neutral, and negative sentiments.

3. The previous two queries returned the `sentiment_analysis_result` directly from the query. However, you will likely want to retrieve the underlying values within the `sentiment_analysis_result` `tuple`. Execute the following query that looks for overwhelmingly positive reviews and extracts the sentiment components into individual fields:

    ```sql
    WITH cte AS (
        SELECT id, comments, azure_cognitive.analyze_sentiment(comments, 'en') AS sentiment FROM reviews
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

    The above query uses a common table expression or CTE to get the sentiment scores for all records in the `reviews` table. It then selects the `sentiment` composite type columns from the `sentiment_analysis_result` returned by the CTE to extract the individual values from `tuple.`

## Store Sentiment in the Reviews Table

For the rental property recommendation system you are building for Margie's Travel, you want to store sentiment ratings in the database so you do not have to make calls and incur costs every time sentiment assessments are requested. Performing sentiment analysis on the fly can be great for small numbers of records or analyzing data in near-real time. Still, adding the sentiment data into the database for use in your application makes sense for your stored reviews. To do this, you want to alter the `reviews` table to add columns for storing the sentiment assessment and the positive, neutral, and negative scores.

1. Run the following query to update the `reviews` table so it can store sentiment details:

    ```sql
    ALTER TABLE reviews
    ADD COLUMN sentiment varchar(10),
    ADD COLUMN positive_score numeric,
    ADD COLUMN neutral_score numeric,
    ADD COLUMN negative_score numeric;
    ```

2. Next, you want to update the existing records in the `reviews` table with their sentiment value and associated scores.

    ```sql
    WITH cte AS (
        SELECT id, azure_cognitive.analyze_sentiment(comments, 'en') AS sentiment FROM reviews
    )
    UPDATE reviews AS r
    SET
        sentiment = (cte.sentiment).sentiment,
        positive_score = (cte.sentiment).positive_score,
        neutral_score = (cte.sentiment).neutral_score,
        negative_score = (cte.sentiment).negative_score
    FROM cte
    WHERE r.id = cte.id;
    ```

    Executing this query takes a long time because the comments for every review in the table are sent individually to the Language service's endpoint for analysis. Sending records in batches is more efficient when dealing with many records.

3. Let's run the query below to perform the same update action, but this time send comments from the `reviews` table in batches of 10 (this is the maximum batch size allowed) and evaluate the difference in performance.

    ```sql
    WITH cte AS (
        SELECT azure_cognitive.analyze_sentiment(ARRAY(SELECT comments FROM reviews ORDER BY id), 'en', batch_size => 10) as sentiments
    ),
    sentiment_cte AS (
        SELECT
            ROW_NUMBER() OVER () AS id,
            sentiments AS sentiment
        FROM cte
    )
    UPDATE reviews AS r
    SET
        sentiment = (sentiment_cte.sentiment).sentiment,
        positive_score = (sentiment_cte.sentiment).positive_score,
        neutral_score = (sentiment_cte.sentiment).neutral_score,
        negative_score = (sentiment_cte.sentiment).negative_score
    FROM sentiment_cte
    WHERE r.id = sentiment_cte.id;
    ```

    While this query is a bit more complex, using two CTEs, it is much more performant. In this query, the first CTE analyzes the sentiment of batches of review comments, and the second extracts the resulting table of `sentiment_analysis_results` into a new table containing an `id` based on the ordinal position and ``sentiment_analysis_result` for each row. The second CTE can then be used in the update statement to write the values into the database.

4. Next, run a query to observe the update results, searching for reviews with a **negative** sentiment, starting with the most negative first.

    ```sql
    SELECT
        id,
        negative_score,
        comments
    FROM reviews
    WHERE sentiment = 'negative'
    ORDER BY negative_score DESC;
    ```

## Clean up

Once you have completed this exercise, delete the Azure resources you created. You are charged for the configured capacity, not how much the database is used. Follow these instructions to delete your resource group and all resources you created for this lab.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/), and on the home page, select **Resource groups** under Azure services.

    ![Screenshot of Resource groups highlighted by a red box under Azure services in the Azure portal.](media/16-azure-portal-home-azure-services-resource-groups.png)

2. In the filter for any field search box, enter the name of the resource group you created for this lab, and then select your resource group from the list.

3. On the **Overview** page of your resource group, select **Delete resource group**.

    ![Screenshot of the Overview blade of the resource group with the Delete resource group button highlighted by a red box.](media/16-resource-group-delete.png)

4. In the confirmation dialog, enter the resource group name you are deleting to confirm and then select **Delete**.
