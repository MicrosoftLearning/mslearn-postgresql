---
lab:
    title: 'Perform Extractive and Abstractive Summarization'
    module: 'Build AI apps with Azure Database for PostgreSQL'
---

# Perform Extractive and Abstractive Summarization

The rental property app maintained by Margie's Travel provides a way for property managers to provide a description of rental listings. Many of the descriptions in the system are long, providing many details about the rental property, its neighborhood, and local attractions, stores, and other amenities. A feature that has been requested as you implement new AI-powered capabilities for the app is using generative AI to create concise summaries of these descriptions, making it easier for your users to quickly review properties. In this exercise, you use the `azure_ai` extension in Azure Database For PostgreSQL flexible server to perform abstractive and extractive summarization on rental property descriptions and compare the resulting summaries.

## Before you start

You need an [Azure subscription](https://azure.microsoft.com/free) with administrative rights, and you must be approved for Azure OpenAI access in that subscription. If you need Azure OpenAI access, apply at the [Azure OpenAI limited access](https://learn.microsoft.com/legal/cognitive-services/openai/limited-access) page.

### Deploy resources into your Azure subscription

This step guides you through using Azure CLI commands from the Azure Cloud Shell to create a resource group and run a Bicep script to deploy the Azure services necessary for completing this exercise into your Azure subscription.

> Note
>
> If you are doing multiple modules in this learning path, you can share the Azure environment between them. In that case, you only need to complete this resource deployment step once.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/).

2. Select the **Cloud Shell** icon in the Azure portal toolbar to open a new [Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) pane at the bottom of your browser window.

    ![Screenshot of the Azure toolbar with the Cloud Shell icon highlighted by a red box.](media/14-portal-toolbar-cloud-shell.png)

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

5. Run the following Azure CLI command to create your resource group:

    ```azurecli
    az group create --name $RG_NAME --location $REGION
    ```

6. Finally, use the Azure CLI to execute a Bicep deployment script to provision Azure resources in your resource group:

    ```azurecli
    az deployment group create --resource-group $RG_NAME --template-file "mslearn-postgresql/Allfiles/Labs/Shared/deploy.bicep" --parameters restore=false adminLogin=pgAdmin adminLoginPassword=$ADMIN_PASSWORD
    ```

    The Bicep deployment script provisions the Azure services required to complete this exercise into your resource group. The resources deployed include an Azure Database for PostgreSQL flexible server, Azure OpenAI, and an Azure AI Language service. The Bicep script also performs some configuration steps, such as adding the `azure_ai` and `vector` extensions to the PostgreSQL server's _allowlist_ (via the azure.extensions server parameter), creating a database named `rentals` on the server, and adding a deployment named `embedding` using the `text-embedding-ada-002` model to your Azure OpenAI service. Note that the Bicep file is shared by all modules in this learning path, so you may only use some of the deployed resources in some exercises.

    The deployment typically takes several minutes to complete. You can monitor it from the Cloud Shell or navigate to the **Deployments** page for the resource group you created above and observe the deployment progress there.

    You may encounter a few errors when running the Bicep deployment script. The most common messages and the steps to resolve them are:

    - If you have not previously created an Azure AI Services resource, you may receive a message that the Responsible AI terms have not been read and accepted in your subscription:

        ```bash
        {"code": "ResourceKindRequireAcceptTerms", "message": "This subscription cannot create TextAnalytics until you agree to Responsible AI terms for this resource. You can agree to Responsible AI terms by creating a resource through the Azure Portal and trying again.}
        ```

        To resolve this error, run this command to create a Language service in your resource group and accept the Responsible AI terms for your subscription. Once the resource is created, you can rerun the command to execute the Bicep deployment script.

        ```bash
        az cognitiveservices account create --name lang-temp-$region-$ADMIN_PASSWORD --resource-group $RG_NAME --kind TextAnalytics --sku F0 --location $REGION --yes
        ```

    - If you previously ran the Bicep deployment script for this learning path and subsequently deleted the resources, you may receive an error message like the following if you are attempting to rerun the script within 48 hours of deleting the resources:

        ```bash
        {"code": "InvalidTemplateDeployment", "message": "The template deployment 'deploy' is not valid according to the validation procedure. The tracking id is '4e87a33d-a0ac-4aec-88d8-177b04c1d752'. See inner errors for details."}
    
        Inner Errors:
        {"code": "FlagMustBeSetForRestore", "message": "An existing resource with ID '/subscriptions/{subscriptionId}/resourceGroups/rg-learn-postgresql-ai-eastus/providers/Microsoft.CognitiveServices/accounts/oai-learn-eastus-gvg3papkkkimy' has been soft-deleted. To restore the resource, you must specify 'restore' to be 'true' in the property. If you don't want to restore existing resource, please purge it first."}
        ```

        If you receive this message, modify the `azure deployment group create` command above to set the `restore` parameter equal to `true` and rerun it.

    - If the selected region is restricted from provisioning specific resources, you must set the `REGION` variable to a different location and try rerunning the Bicep deployment script.

        ```bash
        {"status":"Failed","error":{"code":"DeploymentFailed","target":"/subscriptions/{subscriptionId}/resourceGroups/rg-learn-postgresql-ai-eastus2/providers/Microsoft.Resources/deployments/deploy","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.","details":[{"code":"ResourceDeploymentFailure","target":"/subscriptions/{subscriptionId}/resourceGroups/rg-learn-postgresql-ai-eastus/providers/Microsoft.DBforPostgreSQL/flexibleServers/psql-learn-eastus2-gvg3papkkkimy","message":"The resource write operation failed to complete successfully, because it reached terminal provisioning state 'Failed'.","details":[{"code":"RegionIsOfferRestricted","message":"Subscriptions are restricted from provisioning in this region. Please choose a different region. For exceptions to this rule please open a support request with Issue type of 'Service and subscription limits'. See https://review.learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-request-quota-increase for more details."}]}]}}
        ```

7. Close the Cloud Shell pane once your resource deployment is complete.

## Connect to your database using psql in the Azure Cloud Shell

In this task, you connect to the `rentals` database on your Azure Database for PostgreSQL server using the [psql command-line utility](https://www.postgresql.org/docs/current/app-psql.html) from the [Azure Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview).

1. In the [Azure portal](https://portal.azure.com/), navigate to your newly created Azure Database for PostgreSQL flexible server.

2. In the resource menu, under **Settings**, select **Databases** select **Connect** for the `rentals` database.

    ![Screenshot of the Azure Database for PostgreSQL Databases page. Databases and Connect for the rentals database are highlighted by red boxes.](media/14-postgresql-rentals-database-connect.png)

3. At the "Password for user pgAdmin" prompt in the Cloud Shell, enter the randomly generated password for the **pgAdmin** login.

    Once logged in, the `psql` prompt for the `rentals` database is displayed.

4. Throughout the remainder of this exercise, you continue working in the Cloud Shell, so it may be helpful to expand the pane within your browser window by selecting the **Maximize** button at the top right of the pane.

    ![Screenshot of the Azure Cloud Shell pane with the Maximize button highlighted by a red box.](media/14-azure-cloud-shell-pane-maximize.png)

## Populate the database with sample data

Before you can generate summaries of rental property descriptions using the `azure_ai` extension, you must add sample data to your database. Add a table to the `rentals` database and populate it with rental property listings so you have property descriptions from which to create summaries.

1. Run the following command to create a table named `listings` for storing listing data for rental properties:

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

2. Next, use the `COPY` command to populate the table with data from a CSV file. Execute the command below to load customer reviews into the `listings` table:

    ```sql
    \COPY listings FROM 'mslearn-postgresql/Allfiles/Labs/Shared/listings.csv' CSV HEADER
    ```

    The output of the command should be `COPY 50`, indicating that 50 rows were written into the table from the CSV file.

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

    Before an extension can be installed and used in Azure Database for PostgreSQL flexible server, it must be added to the server's _allowlist_, as described in [how to use PostgreSQL extensions](https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-extensions#how-to-use-postgresql-extensions).

2. Now, you are ready to install the `azure_ai` extension using the [CREATE EXTENSION](https://www.postgresql.org/docs/current/sql-createextension.html) command.

    ```sql
    CREATE EXTENSION IF NOT EXISTS azure_ai;
    ```

    `CREATE EXTENSION` loads a new extension into the database by running its script file. This typically creates new SQL objects such as functions, data types, and schemas. An error is thrown if an extension of the same name already exists. Adding `IF NOT EXISTS` allows the command to execute without throwing an error if it is already installed.

## Connect Your Azure AI Services Account

The Azure AI services integrations included in the `azure_cognitive` schema of the `azure_ai` extension provide a rich set of AI Language features accessible directly from the database. The text summarization capabilities are enabled through the [Azure AI Language service](https://learn.microsoft.com/azure/ai-services/language-service/overview).

1. To successfully make calls against your Azure AI Language services using the `azure_ai` extension, you must provide its endpoint and key to the extension. Using the same browser tab where the Cloud Shell is open, navigate to your Language service resource in the [Azure portal](https://portal.azure.com/) and select the **Keys and Endpoint** item under **Resource Management** from the left-hand navigation menu.

    ![Screenshot of the Azure Language service's Keys and Endpoints page is displayed, with the KEY 1 and Endpoint copy buttons highlighted by red boxes.](media/14-azure-language-service-keys-endpoints.png)

    > Note
    >
    > If you received the message `NOTICE:  extension "azure_ai" already exists, skipping CREATE EXTENSION` when installing the `azure_ai` extension above and have previously configured the extension with your Language service endpoint and key, you can use the `azure_ai.get_setting()` function to confirm those settings are correct, and then skip step 2 if they are.

2. Copy your endpoint and access key values, then in the commands below, replace the `{endpoint}` and `{api-key}` tokens with values you copied from the Azure portal. Run the commands from the `psql` command prompt in the Cloud Shell to add your values to the `azure_ai.settings` table.

    ```sql
    SELECT azure_ai.set_setting('azure_cognitive.endpoint', '{endpoint}');
    ```

    ```sql
    SELECT azure_ai.set_setting('azure_cognitive.subscription_key', '{api-key}');
    ```

## Review the Summarization Capabilities of the Extension

In this task, you review the two summarization functions available in the `azure_cognitive` schema.

1. For the remainder of this exercise, you work exclusively in the Cloud Shell, so it may be helpful to expand the pane within your browser window by selecting the **Maximize** button at the top right of the Cloud Shell pane.

    ![Screenshot of the Azure Cloud Shell pane with the Maximize button highlighted by a red box.](media/14-azure-cloud-shell-pane-maximize.png)

2. When working with `psql` in the Cloud Shell, enabling the extended display for query results may be helpful, as it improves the readability of output for subsequent commands. Execute the following command to allow the extended display to be automatically applied.

    ```sql
    \x auto
    ```

3. The text summarization of the `azure_ai` extension are found within the `azure_cognitive` schema. For extractive summarization, use the `summarize_extractive()` function. Use the [`\df` meta-command](https://www.postgresql.org/docs/current/app-psql.html#APP-PSQL-META-COMMAND-DF-LC) to examine the function by running:

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
    | sort_by | `text` | 'offset' | The sort order for the generated summary sentences. |
    | batch_size | `integer` | 25 | Only for the two overload expecting an input of `text[]`. Specifies the number of records to process at a time. |
    | disable_service_logs | `boolean` | false | Flag indicating whether to turn off service logs. |
    | timeout_ms | `integer` | NULL | Timeout in milliseconds after which the operation is stopped. |
    | throw_on_error | `boolean` | true | Flag indicating whether the function should, on error, throw an exception resulting in a rollback of the wrapping transaction. |
    | max_attempts | `integer` | 1 | Number of times to retry the call to Azure AI Services in the event of a failure. |
    | retry_delay_ms | `integer` | 1000 | Amount of time, in milliseconds, to wait before attempting to retry calling the Azure AI Services endpoint. |

4. Repeat the above step, but this time run the [`\df` meta-command](https://www.postgresql.org/docs/current/app-psql.html#APP-PSQL-META-COMMAND-DF-LC) for the `azure_cognitive.summarize_abstractive()` function and review the output.

    The two functions have similar signatures, although `summarize_abstractive()` does not have the `sort_by` parameter, and it returns an array of `text` versus the array of `azure_cognitive.sentence` composite types returned by the `summarize_extractive()` function. This has to do with the way the two different methods generate summaries. Extractive summarization identifies the most important sentences within the text it is summarizing, ranks them, and then returns those as the summary. Abstractive summarization, on the other hand, uses generative AI to create new, original sentences that summarize the key points of the text.

5. It is also imperative to understand the structure of the data type that a function returns so you can correctly handle the output in your queries. To inspect the `azure_cognitive.sentence` type returned by the `summarize_extractive()` function, run:

    ```sql
    \dT+ azure_cognitive.sentence
    ```

6. The output of the above command reveals the `sentence` type is a `tuple`. To examine the structure of that `tuple` and review at the columns contained within the `sentence` composite type, execute:

    ```sql
    \d+ azure_cognitive.sentence
    ```

    The output of that command should look similar to the following:

    ```sql
                            Composite type "azure_cognitive.sentence"
       Column   |       Type       | Collation | Nullable | Default | Storage  | Description 
    ------------+------------------+-----------+----------+---------+----------+-------------
     text       | text             |           |          |         | extended | 
     rank_score | double precision |           |          |         | plain    |
    ```

    The `azure_cognitive.sentence` is a composite type containing the text of an extractive sentence and a rank score for each sentence, indicating how relevant the sentence is to the text's main topic. Document summarization ranks extracted sentences, and you can determine whether they're returned in the order they appear, or according to their rank.

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

    Compare the two sentences in the `extractive_summary` field in the output to the original `description`, noting that the sentences are not original, but simply extracted from the `description`. The numeric values listed after each sentence are the rank score assigned by the Language service.

2. Next, perform abstractive summarization on the same records:

    ```sql
    SELECT
        id,
        name,
        description,
        azure_cognitive.summarize_abstractive(description, 'en', 2) AS abstractive_summary
    FROM listings
    WHERE id IN (1, 2);
    ```

    The abstractive summarization capabilities of the extension provide a unique, natural language summary that encapsulates the overall intent of the original text.

3. Run a final query to do a side-by-side comparison of the two summarization techniques:

    ```sql
    SELECT
        id,
        azure_cognitive.summarize_extractive(description, 'en', 2) AS extractive_summary,
        azure_cognitive.summarize_abstractive(description, 'en', 2) AS abstractive_summary
    FROM listings
    WHERE id IN (1, 2);
    ```

    By placing the generated summaries side-by-side, it is easy to compare the quality of the summaries generated by each of the methods. For the Margie's Travel application, abstractive summarization appears to be the better option, providing concise summaries that deliver high-quality information in a natural and readable manner. The extractive summaries, while providing some details, are more disjointed, and do not deliver the same value as the original content created by abstractive summarization.

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
        FROM cte
    )
    UPDATE listings AS l
    SET summary = s.summary
    FROM summary_cte AS s
    WHERE l.id = s.id;
    ```

    The update statement uses two common table expressions (CTEs) to perform work on the data prior to update the `listings` table with summaries. The first CTE (`batch_cte`) sends all of the `description` values from the `listings` table to the Language service for abstractive summaries to be generated. It does this in batches of 25 records at a time. The second CTE (`summary_cte`) using the ordinal position of the summaries returned by the `summarize_abstractive()` function to assign each summary an `id` that corresponds to the record the `description` came from in the `listings` table. It also uses the `ARRAY_TO_STRING` function to pull the generated summaries out of the text array (`text[]`) return value and convert it into a simple string. Finally, the `UPDATE` statement writes the summary into the `listings` table for the associated listing.

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

## Clean up

Once you have completed this exercise, delete the Azure resources you created. You are charged for the configured capacity, not how much the database is used. Follow these instructions to delete your resource group and all resources you created for this lab.

> Note
>
> If you plan on completing additional modules in this learning path, you can skip this task until you have finished all the modules you intend to complete.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/), and on the home page, select **Resource groups** under Azure services.

    ![Screenshot of Resource groups highlighted by a red box under Azure services in the Azure portal.](media/14-azure-portal-home-azure-services-resource-groups.png)

2. In the filter for any field search box, enter the name of the resource group you created for this lab, and then select your resource group from the list.

3. On the **Overview** page of your resource group, select **Delete resource group**.

    ![Screenshot of the Overview blade of the resource group with the Delete resource group button highlighted by a red box.](media/14-resource-group-delete.png)

4. In the confirmation dialog, enter the name of the resource group you are deleting to confirm and then select **Delete**.
