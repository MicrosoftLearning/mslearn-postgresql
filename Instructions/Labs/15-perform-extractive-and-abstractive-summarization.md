---
lab:
    title: 'Perform Extractive and Abstractive Summarization'
    module: 'Summarize data using Azure AI Services and Azure Database for PostgreSQL'
---

# Perform Extractive and Abstractive Summarization

The rental property app maintained by Margie's Travel provides a way for property managers to describe rental listings. Many of the descriptions in the system are long, giving many details about the rental property, its neighborhood, and local attractions, stores, and other amenities. A feature that has been requested as you implement new AI-powered capabilities for the app is using generative AI to create concise summaries of these descriptions, making it easier for your users to review properties quickly. In this exercise, you use the `azure_ai` extension in an Azure Database For PostgreSQL flexible server to perform abstractive and extractive summarization on rental property descriptions and compare the resulting summaries.

## Before you start

You need an [Azure subscription](https://azure.microsoft.com/free) with administrative rights.

### Deploy resources into your Azure subscription

This step guides you through using Azure CLI commands from the Azure Cloud Shell to create a resource group and run a Bicep script to deploy the Azure services necessary for completing this exercise into your Azure subscription.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/).

2. Select the **Cloud Shell** icon in the Azure portal toolbar to open a new [Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) pane at the bottom of your browser window.

    ![Screenshot of the Azure toolbar with the Cloud Shell icon highlighted by a red box.](media/15-portal-toolbar-cloud-shell.png)

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

You may encounter a few errors when running the Bicep deployment script.

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

In this task, you connect to the `rentals` database on your Azure Database for PostgreSQL flexible server using the [psql command-line utility](https://www.postgresql.org/docs/current/app-psql.html) from the [Azure Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview).

1. In the [Azure portal](https://portal.azure.com/), navigate to your newly created Azure Database for PostgreSQL flexible server instance.

2. In the resource menu, under **Settings**, select **Databases** select **Connect** for the `rentals` database.

    ![Screenshot of the Azure Database for PostgreSQL Databases page. Databases and Connect for the rentals database are highlighted by red boxes.](media/15-postgresql-rentals-database-connect.png)

3. At the "Password for user pgAdmin" prompt in the Cloud Shell, enter the randomly generated password for the **pgAdmin** login.

    Once logged in, the `psql` prompt for the `rentals` database is displayed.

4. Throughout the remainder of this exercise, you continue working in the Cloud Shell, so it may be helpful to expand the pane within your browser window by selecting the **Maximize** button at the top right of the pane.

    ![Screenshot of the Azure Cloud Shell pane with the Maximize button highlighted by a red box.](media/15-azure-cloud-shell-pane-maximize.png)

## Populate the database with sample data

Before you explore the `azure_ai` extension, add a couple of tables to the `rentals` database and populate them with sample data so you have information to work with as you review the extension's functionality.

1. Run the following commands to create the `listings` and `reviews` tables for storing rental property listing and customer review data:

    ```sql
    DROP TABLE IF EXISTS listings;

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

    ```sql
    DROP TABLE IF EXISTS reviews;

    CREATE TABLE reviews (
        id int,
        listing_id int, 
        date date,
        comments text
    );
    ```

2. Next, use the `COPY` command to load data from CSV files into each table you created above. Start by running the following command to populate the `listings` table:

    ```sql
    \COPY listings FROM 'mslearn-postgresql/Allfiles/Labs/Shared/listings.csv' CSV HEADER
    ```

    The command output should be `COPY 50`, indicating that 50 rows were written into the table from the CSV file.

3. Finally, run the command below to load customer reviews into the `reviews` table:

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

The Azure AI services integrations included in the `azure_cognitive` schema of the `azure_ai` extension provide a rich set of AI Language features accessible directly from the database. The text summarization capabilities are enabled through the [Azure AI Language service](https://learn.microsoft.com/azure/ai-services/language-service/overview).

1. To successfully make calls against your Azure AI Language services using the `azure_ai` extension, you must provide its endpoint and key to the extension. Using the same browser tab where the Cloud Shell is open, navigate to your Language service resource in the [Azure portal](https://portal.azure.com/) and select the **Keys and Endpoint** item under **Resource Management** from the left-hand navigation menu.

    ![Screenshot of the Azure Language service's Keys and Endpoints page is displayed, with the KEY 1 and Endpoint copy buttons highlighted by red boxes.](media/15-azure-language-service-keys-endpoints.png)

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

## Review the Summarization Capabilities of the Extension

In this task, you review the two summarization functions in the `azure_cognitive` schema.

1. For the remainder of this exercise, you work exclusively in the Cloud Shell, so it may be helpful to expand the pane within your browser window by selecting the **Maximize** button at the top right of the Cloud Shell pane.

    ![Screenshot of the Azure Cloud Shell pane with the Maximize button highlighted by a red box.](media/15-azure-cloud-shell-pane-maximize.png)

2. When working with `psql` in the Cloud Shell, enabling the extended display for query results may be helpful, as it improves the readability of output for subsequent commands. Execute the following command to allow the extended display to be automatically applied.

    ```sql
    \x auto
    ```

3. The text summarization functions of the `azure_ai` extension are found within the `azure_cognitive` schema. For extractive summarization, use the `summarize_extractive()` function. Use the [`\df` meta-command](https://www.postgresql.org/docs/current/app-psql.html#APP-PSQL-META-COMMAND-DF-LC) to examine the function by running:

    ```sql
    \df azure_cognitive.summarize_extractive
    ```

    The meta-command output shows the function's schema, name, result data type, and arguments. This information helps you understand how to interact with the function from your queries.

    The output shows three overloads of the `summarize_extractive()` function, allowing you to review their differences. The `Argument data types` property in the output reveals the list of arguments the three function overloads expect:

    | Argument | Type | Default | Description |
    | -------- | ---- | ------- | ----------- |
    | text | `text` or `text[]` || The text(s) for which summaries should be generated. |
    | language_text | `text` or `text[]` || Language code (or array of language codes) representing the language of the text to summarize. Review the [list of supported languages](https://learn.microsoft.com/azure/ai-services/language-service/summarization/language-support) to retrieve the necessary language codes. |
    | sentence_count | `integer` | 3 | The number of summary sentences to generate. |
    | sort_by | `text` | 'offset' | The sort order for the generated summary sentences. Acceptable values are "offset" and "rank," with offset representing the start position of each extracted sentence within the original content and rank being an AI-generated indicator of how relevant a sentence is to the main idea of the content. |
    | batch_size | `integer` | 25 | Only for the two overload expecting an input of `text[]`. Specifies the number of records to process at a time. |
    | disable_service_logs | `boolean` | false | Flag indicating whether to turn off service logs. |
    | timeout_ms | `integer` | NULL | Timeout in milliseconds after which the operation is stopped. |
    | throw_on_error | `boolean` | true | Flag indicating whether the function should, on error, throw an exception resulting in a rollback of the wrapping transaction. |
    | max_attempts | `integer` | 1 | Number of times to retry the call to Azure AI Services in the event of a failure. |
    | retry_delay_ms | `integer` | 1000 | Amount of time, in milliseconds, to wait before attempting to retry calling the Azure AI Services endpoint. |

4. Repeat the above step, but this time run the [`\df` meta-command](https://www.postgresql.org/docs/current/app-psql.html#APP-PSQL-META-COMMAND-DF-LC) for the `azure_cognitive.summarize_abstractive()` function and review the output.

    The two functions have similar signatures, although `summarize_abstractive()` does not have the `sort_by` parameter, and it returns an array of `text` versus the array of `azure_cognitive.sentence` composite types returned by the `summarize_extractive()` function. This disparity has to do with the way the two different methods generate summaries. Extractive summarization identifies the most critical sentences within the text it is summarizing, ranks them, and then returns those as the summary. On the other hand, Abstractive summarization uses generative AI to create new, original sentences that summarize the text's key points.

5. It is also imperative to understand the structure of the data type that a function returns so you can correctly handle the output in your queries. To inspect the `azure_cognitive.sentence` type returned by the `summarize_extractive()` function, run:

    ```sql
    \dT+ azure_cognitive.sentence
    ```

6. The output of the above command reveals the `sentence` type is a `tuple`. To examine the structure of that `tuple` and review the columns contained within the `sentence` composite type, execute:

    ```sql
    \d+ azure_cognitive.sentence
    ```

    The output of that command should look similar to the following:

    ```sql
                            Composite type "azure_cognitive.sentence"
        Column  |     Type         | Collation | Nullable | Default | Storage  | Description 
    ------------+------------------+-----------+----------+---------+----------+-------------
     text       | text             |           |           |        | extended | 
     rank_score | double precision |           |           |        | plain    |
    ```

    The `azure_cognitive.sentence` is a composite type containing the text of an extractive sentence and a rank score for each sentence, indicating how relevant the sentence is to the text's main topic. Document summarization ranks extracted sentences, and you can determine whether they're returned in the order they appear or according to their rank.

## Create Summaries for Property Descriptions

In this task, you use the `summarize_extractive()` and `summarize_abstractive()` functions to create concise two-sentence summaries for property descriptions.

1. Now that you have reviewed the `summarize_extractive()` function and the `sentiment_analysis_result` it returns, let's put the function to use. Execute the following simple query, which performs sentiment analysis on a handful of comments in the `reviews` table:

    ```sql
    SELECT
        id,
        name,
        description,
        azure_cognitive.summarize_extractive(description, 'en', 2) AS extractive_summary
    FROM listings
    WHERE id IN (1, 2);
    ```

    Compare the two sentences in the `extractive_summary` field in the output to the original `description`, noting that the sentences are not original, but extracted from the `description`. The numeric values listed after each sentence are the rank score assigned by the Language service.

2. Next, perform abstractive summarization on the identical records:

    ```sql
    SELECT
        id,
        name,
        description,
        azure_cognitive.summarize_abstractive(description, 'en', 2) AS abstractive_summary
    FROM listings
    WHERE id IN (1, 2);
    ```

    The extension's abstractive summarization capabilities provide a unique, natural-language summary that encapsulates the overall intent of the original text.

    If you receive an error similar to the following, you chose a region that does not support abstractive summarization when creating your Azure environment:

    ```bash
    ERROR: azure_cognitive.summarize_abstractive: InvalidRequest: Invalid Request.

    InvalidParameterValue: Job task: 'AbstractiveSummarization-task' failed with validation errors: ['Invalid Request.']

    InvalidRequest: Job task: 'AbstractiveSummarization-task' failed with validation error: Document abstractive summarization is not supported in the region Central US. The supported regions are North Europe, East US, West US, UK South, Southeast Asia.
    ```

    To be able to perform this step and complete the remaining tasks using abstractive summarization, you must create a new Azure AI Language service in one of the supported regions specified in the error message. This service can be provisioned in the same resource group you used for other lab resources. Alternatively, you may substitute extractive summarization for the remaining tasks but will not get the benefit of being able to compare the output of the two different summarization techniques.

3. Run a final query to do a side-by-side comparison of the two summarization techniques:

    ```sql
    SELECT
        id,
        azure_cognitive.summarize_extractive(description, 'en', 2) AS extractive_summary,
        azure_cognitive.summarize_abstractive(description, 'en', 2) AS abstractive_summary
    FROM listings
    WHERE id IN (1, 2);
    ```

    By placing the generated summaries side-by-side, it is easy to compare the quality of the summaries generated by each method. For the Margie's Travel application, abstractive summarization is the better option, providing concise summaries that deliver high-quality information in a natural and readable manner. While giving some details, the extractive summaries are more disjointed and offer less value than the original content created by abstractive summarization.

## Store Description Summary in the Database

1. Run the following query to alter the `listings` table, adding a new `summary` column:

    ```sql
    ALTER TABLE listings
    ADD COLUMN summary text;
    ```

2. To use generative AI to create summaries for all the existing properties in the database, it is most efficient to send in the descriptions in batches, allowing the language service to process multiple records simultaneously.

    ```sql
    WITH batch_cte AS (
        SELECT azure_cognitive.summarize_abstractive(ARRAY(SELECT description FROM listings ORDER BY id), 'en', batch_size => 25) AS summary
    ),
    summary_cte AS (
        SELECT
            ROW_NUMBER() OVER () AS id,
            ARRAY_TO_STRING(summary, ',') AS summary
        FROM batch_cte
    )
    UPDATE listings AS l
    SET summary = s.summary
    FROM summary_cte AS s
    WHERE l.id = s.id;
    ```

    The update statement uses two common table expressions (CTEs) to work on the data before updating the `listings` table with summaries. The first CTE (`batch_cte`) sends all the `description` values from the `listings` table to the Language service to generate abstractive summaries. It does this in batches of 25 records at a time. The second CTE (`summary_cte`) uses the ordinal position of the summaries returned by the `summarize_abstractive()` function to assign each summary an `id` corresponding to the record the `description` came from in the `listings` table. It also uses the `ARRAY_TO_STRING` function to pull the generated summaries out of the text array (`text[]`) return value and convert it into a simple string. Finally, the `UPDATE` statement writes the summary into the `listings` table for the associated listing.

3. As a last step, run a query to view the summaries written into the `listings` table:

    ```sql
    SELECT
        id,
        name,
        description,
        summary
    FROM listings
    LIMIT 5;
    ```

## Generate an AI summary of reviews for a listing

For the Margie's Travel app, displaying a summary of all reviews for a property helps users quickly assess the overall gist of reviews.

1. Run the following query, which combines all reviews for a listing into a single string and then generates abstractive summarization over that string:

    ```sql
    SELECT unnest(azure_cognitive.summarize_abstractive(reviews_combined, 'en')) AS review_summary
    FROM (
        -- Combine all reviews for a listing
        SELECT string_agg(comments, ' ') AS reviews_combined
        FROM reviews
        WHERE listing_id = 1
    );
    ```

## Clean up

Once you have completed this exercise, delete the Azure resources you created. You are charged for the configured capacity, not how much the database is used. Follow these instructions to delete your resource group and all resources you created for this lab.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/), and on the home page, select **Resource groups** under Azure services.

    ![Screenshot of Resource groups highlighted by a red box under Azure services in the Azure portal.](media/15-azure-portal-home-azure-services-resource-groups.png)

2. In the filter for any field search box, enter the name of the resource group you created for this lab, and then select your resource group from the list.

3. On the **Overview** page of your resource group, select **Delete resource group**.

    ![Screenshot of the Overview blade of the resource group with the Delete resource group button highlighted by a red box.](media/15-resource-group-delete.png)

4. In the confirmation dialog, enter the resource group name you are deleting to confirm and then select **Delete**.
