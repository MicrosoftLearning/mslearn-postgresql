---
lab:
    title: 'Perform Inference using Azure Machine Learning'
    module: 'Build AI apps with Azure Database for PostgreSQL'
---

# Translate Text with Azure AI Translator

As the lead developer for Margie's Travel (MT), you have been asked to help develop a feature estimating nightly rental prices for short-term rentals. You have collected some historical data as a text file and would like to use this to train a simple regression model in Azure Machine Learning. Then, you would like to use that model against data you have hosted in Azure Database for PostgreSQL - Flexible Server.

In this exercise, you will create and deploy a model using Azure Machine Learning's Automated ML (AutoML) functionality. Then, you will use that deployed model to estimate nightly sale prices for short-term rental properties.

## Before you start

You need an [Azure subscription](https://azure.microsoft.com/free) with administrative rights.

### Deploy resources into your Azure subscription

This step will guide you through using Azure CLI commands from the Azure Cloud Shell to create a resource group and run a Bicep script to deploy the Azure services necessary for completing this exercise into your Azure subscription.

> Note
>
> If you are doing multiple modules in this learning path, you can share the Azure environment between them. In that case, you only need to complete this resource deployment step once.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/).

2. Select the **Cloud Shell** icon in the Azure portal toolbar to open a new [Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) pane at the bottom of your browser window.

    ![Screenshot of the Azure toolbar with the Cloud Shell icon highlighted by a red box.](media/11-portal-toolbar-cloud-shell.png)

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

    The final command randomly generates a password for the PostgreSQL admin login. Make sure you copy it to a safe place so that you can use it later to connect to your PostgreSQL flexible server.

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
    az deployment group create --resource-group $RG_NAME --template-file "mslearn-postgresql/Allfiles/Labs/Shared/deploy-aml.bicep" --parameters adminLogin=pgAdmin adminLoginPassword=$ADMIN_PASSWORD
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

    ![Screenshot of the Azure Database for PostgreSQL Databases page. Databases and Connect for the rentals database are highlighted by red boxes.](media/11-postgresql-rentals-database-connect.png)

3. At the "Password for user pgAdmin" prompt in the Cloud Shell, enter the randomly generated password for the **pgAdmin** login.

    Once logged in, the `psql` prompt for the `rentals` database is displayed.

4. Throughout the remainder of this exercise, you continue working in the Cloud Shell, so it may be helpful to expand the pane within your browser window by selecting the **Maximize** button at the top right of the pane.

    ![Screenshot of the Azure Cloud Shell pane with the Maximize button highlighted by a red box.](media/11-azure-cloud-shell-pane-maximize.png)

## Train a machine learning model

You will train a new Azure Machine Learning Automated Machine Learning (AutoML) model [using the studio UI](https://learn.microsoft.com/azure/machine-learning/how-to-use-automated-ml-for-ml-models?view=azureml-api-2).

TODO: flesh out instructions: opening Azure ML, preparing the AutoML job, etc. Include screenshots.

1. Download the `listings-regression.csv` file from [the mslearn-postgresql repository](../../Allfiles/Labs/Shared/listings-regression.csv).
2. Create a new Automated ML job. based on a new experiment called `Rental-Listings`.

Choose **Regression** as the task type and upload the `listings-regression.csv` file as a new data asset. Call the data asset `RentalListings` and choose the **Tabular** dataset type from the Azure ML v1 APIs. For your data source, choose to upload **From local files** and upload the `listings-regression.csv` file.

On the **Task settings** page, select **price** as the target column. On the **View additional configuration settings** fly-out pane, ensure that **Enable ensemble stacking** is selected. In the **Limits** section, set the experiment timeout to **60** minutes to ensure it does not run longer than one hour. Also, select the **Enable early termination** box.

On the **Compute** page, ensure that the compute type is **Serverless** and you are using a **CPU**-based virtual machine at the **Dedicated** tier.

Once you have everything configured, submit the training job.
3. Wait for the training job to complete. This may take the full hour. Once the process completes, the Status will display a green check mark and a text label of **Completed**.

## Deploy the best-fitting Azure ML model

Now that you have trained a series of models using Azure Machine Learning, the next step is to deploy the best-fit model.

TODO: flesh out instructions. Include screenshots.

1. Navigate to the **Jobs** menu in Azure Machine Learning and select the Rental-Listings experiment. Then, select the latest job. In this job, select the **+ Register model** option to register a model. Choose the best-fit model option and name the model **RentalListings**.
2. Navigate to the **Models** menu in Azure Machine Learning and select your registered model if you do not have it open already.
3. Use the **Deploy** option to create a new **Real-time endpoint**. This endpoint should run on 1 instance of **Standard_DS2_v2**. Choose an appropriate **Endpoint name** and an appropriate **Deployment name** and then select **Deploy**.
4. After the endpoint deploys, navigate to the **Endpoints** menu on the left-hand side and select your new managed endpoint. Navigate to the **Consume** tab and copy the REST endpoint and primary key so you can use them in the next section. Keep track of the REST endpoint URL and endpoint key, as you will need them in the next section.

In order to test that your endpoint is running correctly, you can use the **Test** tab on your endpoint. Then, paste in the following block, replacing any input that currently exists. Select the **Test** button and you should see a JSON output containing an array with a single decimal value, indicating the number of US dollars you should expect this particular property to earn for a single night of rental.

```json
{
  "input_data": {
    "columns": [
      "host_is_superhost",
      "host_has_profile_pic",
      "host_identity_verified",
      "neighbourhood_group_cleansed",
      "zipcode",
      "property_type",
      "room_type",
      "accommodates",
      "bathrooms",
      "bedrooms",
      "beds"
    ],
    "index": [0],
    "data": [["False", "False", "False", "Central Area", "98122", "House", "Entire home/apt", 4, 1.5, 3, 3]]
  }
}
```

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

3. You will then need to use the `azure_ai.set_setting()` function to configure the connection to your Azure Machine Learning deployed endpoint. Configure the `azure_ml` settings to point to your deployed endpoint and its key. The value for `azure_ml.scoring_endpoint` will be your endpoint's REST URL. The value for `azure_ml.endpoint_key` will be the value of Key 1 or Key 2.

    ```sql
    SELECT azure_ai.set_setting('azure_ml.scoring_endpoint','https://<YOUR_ENDPOINT>.<YOUR_REGION>.inference.ml.azure.com/score');
    SELECT azure_ai.set_setting('azure_ml.endpoint_key', '<YOUR_KEY>');

## Create a table containing listings to price

You will need one table in order to store short-term rental listings that you would like to price.

1. Run the following command in the `rentals` database to create a new `listings_to_price` table.

    ```sql
    CREATE TABLE listings_to_price (
        id INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
        host_is_superhost BOOLEAN NOT NULL,
        host_has_profile_pic BOOLEAN NOT NULL,
        host_identity_verified BOOLEAN NOT NULL,
        neighbourhood_group_cleansed VARCHAR(75) NOT NULL,
        zipcode VARCHAR(5) NOT NULL,
        property_type VARCHAR(30) NOT NULL,
        room_type VARCHAR(30) NOT NULL,
        accommodates INT NOT NULL,
        bathrooms DECIMAL(3,1) NOT NULL,
        bedrooms INT NOT NULL,
        beds INT NOT NULL
    );
    ```

2. Next, run the following command in the `rentals` database to insert some new rental listing data.

    ```sql
    INSERT INTO listings_to_price(host_is_superhost, host_has_profile_pic, host_identity_verified,
        neighoburhood_group_cleansed, zipcode, property_type, room_type,
        accommodates, bathrooms, bedrooms, beds)
    VALUES
        (True, True, True, 'Queen Anne', '98119', 'House', 'Private room', 2, 1.0, 1, 1),
        (False, True, True, 'University District', '98105', 'Apartment', 'Entire home/apt', 4, 1.5, 2, 2),
        (False, False, False, 'Central Area', '98122', 'House', 'Entire home/apt', 4, 1.5, 3, 3),
        (False, False, False, 'Downtown', '98101', 'House', 'Entire home/apt', 4, 1.5, 3, 3),
        (False, False, False, 'Capitol Hill', '98122', 'House', 'Entire home/apt', 4, 1.5, 3, 3);
    ```

    This will insert 5 rows of new listing data.

## Create a function to translate listings data

In order to populate the language translation table, you will create a stored procedure to load data in batches.

1. Run the following command at the `psql` prompt to create a new function named `price_listing`.

    ```sql
    CREATE OR REPLACE FUNCTION price_listing (
        IN host_is_superhost BOOLEAN, IN host_has_profile_pic BOOLEAN, IN host_identity_verified BOOLEAN,
        IN neighbourhood_group_cleansed VARCHAR(75), IN zipcode VARCHAR(5), IN property_type VARCHAR(30),
        IN room_type VARCHAR(30), IN accommodates INT, IN bathrooms DECIMAL(3,1), IN bedrooms INT, IN beds INT)
    RETURNS DECIMAL(6,2)
    AS $$
        SELECT CAST(jsonb_array_elements(inference.inference) AS DECIMAL(6,2)) AS expected_price
        FROM azure_ml.inference(('
        {
            "input_data": {
                "columns": [
                "host_is_superhost",
                "host_has_profile_pic",
                "host_identity_verified",
                "neighbourhood_group_cleansed",
                "zipcode",
                "property_type",
                "room_type",
                "accommodates",
                "bathrooms",
                "bedrooms",
                "beds"
                ],
                "index": [0],
                "data": [["' || host_is_superhost || '", "' || host_has_profile_pic || '", "' || host_identity_verified || '", "' ||
                neighbourhood_group_cleansed || '", "' || zipcode || '", "' || property_type || '", "' || room_type || '", ' ||
                accommodates || ', ' || bathrooms || ', ' || bedrooms || ', ' || beds || ']]
            }
        }')::jsonb, deployment_name=>'{YOUR_DEPLOYMENT_NAME}');
    $$ LANGUAGE sql;
    ```

    Be sure to replace `{YOUR_DEPLOYMENT_NAME}` with the actual name of your deployment.

2. Execute the function using the following SQL command:

    ```sql
    SELECT * FROM price_listing(False, False, False, 'Central Area', '98122', 'House', 'Entire home/apt', 4, 1.5, 3, 3);
    ```

    This will return a nightly rental price estimate in decimal format.

3. Call the function for each row in the `listings_to_price` table using the following SQL command:

    ```sql
    SELECT l2p.*, expected_price
    FROM listings_to_price l2p
        CROSS JOIN LATERAL price_listing(l2p.host_is_superhost, l2p.host_has_profile_pic, l2p.host_identity_verified,
            l2p.neighbourhood_group_cleansed, l2p.zipcode, l2p.property_type, l2p.room_type,
            l2p.accommodates, l2p.bathrooms, l2p.bedrooms, l2p.beds) expected_price;
    ```

    This will return five rows, one for each row in `listings_to_price`. It will include all of the columns in the `listings_to_price` table and the result of the `price_listing()` function as `expected_price`.

## Clean up

Once you have completed this exercise, delete the Azure resources you created. You are charged for the configured capacity, not how much the database is used. Follow these instructions to delete your resource group and all resources you created for this lab.

> Note
>
> If you plan on completing additional modules in this learning path, you should run this task and then run the deployment script in the next module you intend to complete.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/), and on the home page, select **Resource groups** under Azure services.

    ![Screenshot of Resource groups highlighted by a red box under Azure services in the Azure portal.](media/11-azure-portal-home-azure-services-resource-groups.png)

2. In the filter for any field search box, enter the name of the resource group you created for this lab, and then select the resource group from the list.

3. On the **Overview** page of your resource group, select **Delete resource group**.

    ![Screenshot of the Overview blade of the resource group with the Delete resource group button highlighted by a red box.](media/11-resource-group-delete.png)

4. In the confirmation dialog, enter the name of the resource group you are deleting to confirm and then select **Delete**.
