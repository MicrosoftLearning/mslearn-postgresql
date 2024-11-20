---
lab:
    title: 'Extract insights using the Azure AI Language'
    module: 'Extract insights using the Azure AI Language service with Azure Database for PostgreSQL'
---

# Extract insights using the Azure AI Language service with Azure Database for PostgreSQL

Recall that the listings company wants to analyze market trends, like the most popular phrases or places. The team also intends to enhance protections for personally identifiable information (PII). The current data is stored in an Azure Database for PostgreSQL flexible server. The project budget is small, so minimizing upfront costs and ongoing costs in maintaining keywords and tags is essential. The developers are wary of how many forms PII can take and prefer a cost-effective, vetted solution over an in-house regular expression matcher.

You'll integrate the database with Azure AI Language services using the `azure_ai` extension. The extension provides user-defined SQL function APIs to several Azure Cognitive Service APIs, including:

- key phrase extraction
- entity recognition
- PII recognition

This approach will allow the data science team to quickly join against listing popularity data to determine market trends. It will also give application developers a PII-safe text to present in situations that don't require access. Storing identified entities enables human review in case of inquiry or false positive PII recognition (thinking something is PII that isn't).

By the end, you'll have four new columns in the `listings` table with extracted insights:

- `key_phrases`
- `recognized_entities`
- `pii_safe_description`
- `pii_entities`

## Before you start

You need an [Azure subscription](https://azure.microsoft.com/free) with administrative rights.

### Deploy resources into your Azure subscription

This step guides you through using Azure CLI commands from the Azure Cloud Shell to create a resource group and run a Bicep script to deploy the Azure services necessary for completing this exercise into your Azure subscription.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/).

2. Select the **Cloud Shell** icon in the Azure portal toolbar to open a new [Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) pane at the bottom of your browser window.

    ![Screenshot of the Azure toolbar with the Cloud Shell icon highlighted by a red box.](media/17-portal-toolbar-cloud-shell.png)

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

    The Bicep deployment script provisions the Azure services required to complete this exercise into your resource group. The resources deployed include an Azure Database for PostgreSQL - Flexible Server, Azure OpenAI, and an Azure AI Language service. The Bicep script also performs some configuration steps, such as adding the `azure_ai` and `vector` extensions to the PostgreSQL server's _allowlist_ (via the `azure.extensions` server parameter), creating a database named `rentals` on the server, and adding a deployment named `embedding` using the `text-embedding-ada-002` model to your Azure OpenAI service. Note that the Bicep file is shared by all modules in this learning path, so you may only use some of the deployed resources in some exercises.

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

In this task, you connect to the `rentals` database on your Azure Database for PostgreSQL server using the [psql command-line utility](https://www.postgresql.org/docs/current/app-psql.html) from the [Azure Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview).

1. In the [Azure portal](https://portal.azure.com/), navigate to your newly created Azure Database for PostgreSQL - Flexible Server.

2. In the resource menu, under **Settings**, select **Databases** select **Connect** for the `rentals` database.

    ![Screenshot of the Azure Database for PostgreSQL Databases page. Databases and Connect for the rentals database are highlighted by red boxes.](media/17-postgresql-rentals-database-connect.png)

3. At the "Password for user pgAdmin" prompt in the Cloud Shell, enter the randomly generated password for the **pgAdmin** login.

    Once logged in, the `psql` prompt for the `rentals` database is displayed.

4. Throughout the remainder of this exercise, you continue working in the Cloud Shell, so it may be helpful to expand the pane within your browser window by selecting the **Maximize** button at the top right of the pane.

    ![Screenshot of the Azure Cloud Shell pane with the Maximize button highlighted by a red box.](media/17-azure-cloud-shell-pane-maximize.png)

## Setup: Configure extensions

To store and query vectors, and to generate embeddings, you need to allow-list and enable two extensions for Azure Database for PostgreSQL Flexible Server: `vector` and `azure_ai`.

1. To allow-list both extensions, add `vector` and `azure_ai` to the server parameter `azure.extensions`, as per the instructions provided in [How to use PostgreSQL extensions](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-extensions#how-to-use-postgresql-extensions).

2. Run the following SQL command to enable the `vector` extension. For detailed instructions, read [How to enable and use `pgvector` on Azure Database for PostgreSQL - Flexible Server](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-use-pgvector#enable-extension).

    ```sql
    CREATE EXTENSION vector;
    ```

3. To enable the `azure_ai` extension, run the following SQL command. You'll need the endpoint and API key for the ***Azure OpenAI*** resource. For detailed instructions, read [Enable the `azure_ai` extension](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/generative-ai-azure-overview#enable-the-azure_ai-extension).

    ```sql
    CREATE EXTENSION azure_ai;
    ```

    ```sql
    SELECT azure_ai.set_setting('azure_openai.endpoint', 'https://<endpoint>.openai.azure.com');
    ```

    ```sql
    SELECT azure_ai.set_setting('azure_openai.subscription_key', '<API Key>');
    ```

4. To successfully make calls against your ***Azure AI Language*** services using the `azure_ai` extension, you must provide its endpoint and key to the extension. Using the same browser tab where the Cloud Shell is open, navigate to your Language service resource in the [Azure portal](https://portal.azure.com/) and select the **Keys and Endpoint** item under **Resource Management** from the left-hand navigation menu.

5. Copy your endpoint and access key values, then in the commands below, replace the `{endpoint}` and `{api-key}` tokens with values you copied from the Azure portal. Run the commands from the `psql` command prompt in the Cloud Shell to add your values to the `azure_ai.settings` table.

    ```sql
    SELECT azure_ai.set_setting('azure_cognitive.endpoint', '{endpoint}');
    ```

    ```sql
    SELECT azure_ai.set_setting('azure_cognitive.subscription_key', '{api-key}');
    ```

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

To reset your sample data, you can execute `DROP TABLE listings`, and repeat these steps.

## Extract key phrases

1. The key phrases are extracted as `text[]` as revealed by the `pg_typeof` function:

    ```sql
    SELECT pg_typeof(azure_cognitive.extract_key_phrases('The food was delicious and the staff were wonderful.', 'en-us'));
    ```

    Create a column to contain the key results.

    ```sql
    ALTER TABLE listings ADD COLUMN key_phrases text[];
    ```

1. Populate the column in batches. Depending on the quota, you may wish to adjust the `LIMIT` value. *Feel free to run the command as many times as you like*; you don't need all rows populated for this exercise.

    ```sql
    UPDATE listings
    SET key_phrases = azure_cognitive.extract_key_phrases(description)
    FROM (SELECT id FROM listings WHERE key_phrases IS NULL ORDER BY id LIMIT 100) subset
    WHERE listings.id = subset.id;
    ```

1. Query listings by key phrases:

    ```sql
    SELECT id, name FROM listings WHERE 'closet' = ANY(key_phrases);
    ```

    You will get results like this, depending on which listings have key phrases populated:

    ```sql
       id    |                name                
    ---------+-------------------------------------
      931154 | Met Tower in Belltown! MT2
      931758 | Hottest Downtown Address, Pool! MT2
     1084046 | Near Pike Place & Space Needle! MT2
     1084084 | The Best of the Best, Seattle! MT2
    ```

## Named entity recognition

1. The entities are extracted as `azure_cognitive.entity[]` as revealed by the `pg_typeof` function:

    ```sql
    SELECT pg_typeof(azure_cognitive.recognize_entities('For more information, see Cognitive Services Compliance and Privacy notes.', 'en-us'));
    ```

    Create a column to contain the key results.

    ```sql
    ALTER TABLE listings ADD COLUMN entities azure_cognitive.entity[];
    ```

2. Populate the column in batches. This process may take several minutes. You may wish to adjust the `LIMIT` value depending on the quota or to return more quickly with partial results. *Feel free to run the command as many times as you like*; you don't need all rows populated for this exercise.

    ```sql
    UPDATE listings
    SET entities = azure_cognitive.recognize_entities(description, 'en-us')
    FROM (SELECT id FROM listings WHERE entities IS NULL ORDER BY id LIMIT 500) subset
    WHERE listings.id = subset.id;
    ```

3. You may now query all listings' entities to find properties with basements:

    ```sql
    SELECT id, name
    FROM listings, unnest(listings.entities) AS e
    WHERE e.text LIKE '%roof%deck%'
    LIMIT 10;
    ```

    Which returns something like this:

    ```sql
       id    |                name                
    ---------+-------------------------------------
      430610 | 3br/3ba. modern, roof deck, garage
      430610 | 3br/3ba. modern, roof deck, garage
     1214306 | Private Bed/bath in Home: green (A)
       74328 | Spacious Designer Condo
      938785 | Best Ocean Views By Pike Place! PA1
       23430 | 1 Bedroom Modern Water View Condo
      828298 | 2 Bedroom Sparkling City Oasis
      338043 | large modern unit & fab location
      872152 | Luxurious Local Lifestyle 2Bd/2+Bth
      116221 | Modern, Light-Filled Fremont Flat
    ```

## PII Recognition

1. The entities are extracted as `azure_cognitive.pii_entity_recognition_result` as revealed by the `pg_typeof` function:

    ```sql
    SELECT pg_typeof(azure_cognitive.recognize_pii_entities('For more information, see Cognitive Services Compliance and Privacy notes.', 'en-us'));
    ```

    This value is a composite type containing redacted text and an array of PII entities, as verified by:

    ```sql
    \d azure_cognitive.pii_entity_recognition_result
    ```

    Which prints:

    ```sql
         Composite type "azure_cognitive.pii_entity_recognition_result"
         Column    |           Type           | Collation | Nullable | Default 
    ---------------+--------------------------+-----------+----------+---------
     redacted_text | text                     |           |          | 
     entities      | azure_cognitive.entity[] |           |          | 
    ```

    Create a column to contain the redacted text and another for the recognized entities:

    ```sql
    ALTER TABLE listings ADD COLUMN description_pii_safe text;
    ALTER TABLE listings ADD COLUMN pii_entities azure_cognitive.entity[];
    ```

2. Populate the column in batches. This process may take several minutes. You may wish to adjust the `LIMIT` value depending on the quota or to return more quickly with partial results. *Feel free to run the command as many times as you like*; you don't need all rows populated for this exercise.

    ```sql
    UPDATE listings
    SET
        description_pii_safe = pii.redacted_text,
        pii_entities = pii.entities
    FROM (SELECT id, description FROM listings WHERE description_pii_safe IS NULL OR pii_entities IS NULL ORDER BY id LIMIT 100) subset,
    LATERAL azure_cognitive.recognize_pii_entities(subset.description, 'en-us') as pii
    WHERE listings.id = subset.id;
    ```

3. You may now display listing descriptions with any potential PII redacted:

    ```sql
    SELECT description_pii_safe
    FROM listings
    WHERE description_pii_safe IS NOT NULL
    LIMIT 1;
    ```

    Which displays:

    ```sql
    A lovely stone-tiled room with kitchenette. New full mattress futon bed. Fridge, microwave, kettle for coffee and tea. Separate entrance into book-lined mudroom. Large bathroom with Jacuzzi (shared occasionally with ***** to do laundry). Stone-tiled, radiant heated floor, 300 sq ft room with 3 large windows. The bed is queen-sized futon and has a full-sized mattress with topper. Bedside tables and reading lights on both sides. Also large leather couch with cushions. Kitchenette is off the side wing of the main room and has a microwave, and fridge, and an electric kettle for making coffee or tea. Kitchen table with two chairs to use for meals or as desk. Extra high-speed WiFi is also provided. Access to English Garden. The Ballard Neighborhood is a great place to visit: *10 minute walk to downtown Ballard with fabulous bars and restaurants, great ****** farmers market, nice three-screen cinema, and much more. *5 minute walk to the Ballard Locks, where ships enter and exit Puget Sound
    ```

4. You may also identify the entities recognized in PII; for example, using the identical listing as above:

    ```sql
    SELECT entities
    FROM listings
    WHERE entities IS NOT NULL
    LIMIT 1;
    ```

    Which displays:

    ```sql
                            pii_entities                        
    -------------------------------------------------------------
    {"(hosts,PersonType,\"\",0.93)","(Sunday,DateTime,Date,1)"}
    ```

## Check your work

Let's ensure the extracted key phrases, recognized entities, and PII were populated:

1. Check key phrases:

    ```sql
    SELECT COUNT(*) FROM listings WHERE key_phrases IS NOT NULL;
    ```

    You should see something like this, depending on how many batches you ran:

    ```sql
    count 
    -------
     100
    ```

2. Check recognized entities:

    ```sql
    SELECT COUNT(*) FROM listings WHERE entities IS NOT NULL;
    ```

    You should see something like:

    ```sql
    count 
    -------
     500
    ```

3. Check redacted PII:

    ```sql
    SELECT COUNT(*) FROM listings WHERE description_pii_safe IS NOT NULL;
    ```

    If you loaded a single batch of 100, you should see:

    ```sql
    count 
    -------
     100
    ```

    You can check how many listings had PII detected:

    ```sql
    SELECT COUNT(*) FROM listings WHERE description != description_pii_safe;
    ```

    You should see something like:

    ```sql
    count 
    -------
        87
    ```

4. Check detected PII entities: per the above, we should have 13 without an empty PII array.

    ```sql
    SELECT COUNT(*) FROM listings WHERE pii_entities IS NULL AND description_pii_safe IS NOT NULL;
    ```

    Result:

    ```sql
    count 
    -------
        13
    ```

## Clean up

Once you have completed this exercise, delete the Azure resources you created. You are charged for the configured capacity, not how much the database is used. Follow these instructions to delete your resource group and all resources you created for this lab.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/), and on the home page, select **Resource groups** under Azure services.

    ![Screenshot of Resource groups highlighted by a red box under Azure services in the Azure portal.](media/17-azure-portal-home-azure-services-resource-groups.png)

2. In the filter for any field search box, enter the name of the resource group you created for this lab, and then select your resource group from the list.

3. On the **Overview** page of your resource group, select **Delete resource group**.

    ![Screenshot of the Overview blade of the resource group with the Delete resource group button highlighted by a red box.](media/17-resource-group-delete.png)

4. In the confirmation dialog, enter the resource group name you are deleting to confirm and then select **Delete**.
