In this scenario, you’re building a small internal assistant for the company’s policy questions at Contoso. You set up a table in Azure Database for PostgreSQL, load the CSV of policies, and store an embedding for each policy so the database can match questions by meaning, not just keywords. You add a vector index to keep lookups fast. Then you write a short Python script that asks for a question, fetches the most relevant policies, and prints an answer based only on those policies, including the policy title.

By the end of this exercise, you will:

- Enable database extensions that power embeddings and vector search.
- Generate in-database embeddings for your data.
- Add a vector index to keep search fast.
- Write a small RAG Python program that retrieves top chunks and produces a grounded answer.

## Before you start

You need an [Azure subscription](https://azure.microsoft.com/free) with administrative rights, and you must be approved for Azure OpenAI access in that subscription. If you need Azure OpenAI access, apply at the [Azure OpenAI limited access](https://learn.microsoft.com/legal/cognitive-services/openai/limited-access) page.

### Deploy resources into your Azure subscription

*If you already have a nonproduction Azure Database for PostgreSQL server and a nonproduction Azure OpenAI resource setup, you can skip this section.*

This step guides you through using Azure CLI commands from the Azure Cloud Shell to create a resource group and run a Bicep script to deploy the Azure services necessary for completing this exercise into your Azure subscription.

1. Open a web browser and navigate to the [Azure portal](https://portal.azure.com/).

1. Select the **Cloud Shell** icon in the Azure portal toolbar to open a new [Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview) pane at the bottom of your browser window.

    ![Screenshot of the Azure toolbar with the Cloud Shell icon highlighted by a red box.](media/14-portal-toolbar-cloud-shell.png)

    If prompted, select the required options to open a *Bash* shell. If you previously used a *PowerShell* console, switch it to a *Bash* shell.

1. At the Cloud Shell prompt, enter the following to clone the GitHub repo containing exercise resources:

    ```bash
    git clone --branch "postgresql-ai-update" --single-branch --depth 1 https://github.com/MicrosoftLearning/mslearn-postgresql.git
    ```

1. Next, you run three commands to define variables to reduce redundant typing when using Azure CLI commands to create Azure resources. The variables represent the name to assign to your resource group (`RG_NAME`), the Azure region (`REGION`) into which resources are deployed, and a randomly generated password for the PostgreSQL administrator sign in (`ADMIN_PASSWORD`).

    In the first command, the region assigned to the corresponding variable is `westus3`, but you can also replace it with a location of your preference. However, if replacing the default, you must select another [Azure region that supports abstractive summarization](https://learn.microsoft.com/azure/ai-services/language-service/summarization/region-support) to ensure you can complete all of the tasks in the modules in this learning path.

    ```bash
    REGION=westus3
    ```

    The following command assigns the name to be used for the resource group that houses all the resources used in this exercise. The resource group name assigned to the corresponding variable is `rg-learn-postgresql-ai-$REGION`, where `$REGION` is the location you previously specified. However, you can change it to any other resource group name that suits your preference.

    ```bash
    RG_NAME=rg-learn-postgresql-ai-$REGION
    ```

    The final command randomly generates a password for the PostgreSQL admin sign in. **Make sure you copy it** to a safe place to use later to connect to your PostgreSQL.

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

1. *Only run this command if you want to change your current subscription*. If you have access to more than one Azure subscription, and your default subscription isn't the one in which you want to create the resource group and other resources for this exercise, run this command to set the appropriate subscription, replacing the `<subscriptionName|subscriptionId>` token with either the name or ID of the subscription you want to use:

    ```azurecli
    az account set --subscription <subscriptionName|subscriptionId>
    ```

1. Run the following Azure CLI command to create your resource group:

    ```azurecli
    az group create --name $RG_NAME --location $REGION
    ```

1. Finally, use the Azure CLI to execute Bicep deployment scripts to provision Azure resources in your resource group:

    ```azurecli
    #1 Core infra: PostgreSQL + DB + firewall + server param, AOAI account, Language account
    az deployment group create \
      --resource-group "$RG_NAME" \
      --template-file "mslearn-postgresql/Allfiles/Labs/Shared/deploy.core.bicep" \
      --parameters restore=false adminLogin=pgAdmin adminLoginPassword="$ADMIN_PASSWORD" databaseName=ContosoHelpDesk
    
    AOAI=$(az cognitiveservices account list -g "$RG_NAME" --query "[?kind=='OpenAI'].name | [0]" -o tsv)
    
    #2 Wait for the parent AOAI account to finish provisioning
    echo "Waiting for AOAI account to be ready..."
    while true; do
      STATE=$(az cognitiveservices account show -g "$RG_NAME" -n "$AOAI" --query "properties.provisioningState" -o tsv)
      echo "provisioningState=$STATE"
      [ "$STATE" = "Succeeded" ] && break
      sleep 10
    done

    #3 OpenAI deployments: embedding + chat
    az deployment group create \
      --resource-group "$RG_NAME" \
      --template-file "mslearn-postgresql/Allfiles/Labs/Shared/deploy.aoai-deployments.bicep" \
      --parameters azureOpenAIServiceName="$AOAI"
    ```

    The Bicep deployment scripts provisions the Azure services required to complete this exercise into your resource group. The resources deployed include an Azure Database for PostgreSQL server, Azure OpenAI, an Azure AI Language service. The Bicep script also performs some configuration steps, such as adding the `azure_ai` and `vector` extensions to the PostgreSQL server's _allowlist_ (via the `azure.extensions` server parameter), creating a database named `ContosoHelpDesk` on the server, and adding a deployment named `embedding` using the `text-embedding-ada-002` model to your Azure OpenAI service. Finally it adds a deployment named `chat` using the `gpt-4o-mini` model to your Azure OpenAI service. The Bicep file shares all modules in this learning path, so you might only use some of the deployed resources in some exercises.

    The deployment typically takes several minutes to complete. You can monitor it from the Cloud Shell or navigate to the **Deployments** page for the resource group you previously created and observe the deployment progress there.

1. Take note of the resource names and their corresponding ID, and the PostgreSQL server's fully qualified domain name (FQDN), username, and password, as you need them later.

### Troubleshooting deployment errors

You could encounter a few errors when running the Bicep deployment script. *If no errors are encountered, skip this section.*

- If you previously ran the Bicep deployment script for this learning path and later deleted the resources, you could receive an error message like the following if you're attempting to rerun the script within 48 hours of deleting the resources:

    ```bash
    {"code": "InvalidTemplateDeployment", "message": "The template deployment 'deploy' is not valid according to the validation procedure. The tracking id is '4e87a33d-a0ac-4aec-88d8-177b04c1d752'. See inner errors for details."}
    
    Inner Errors:
    {"code": "FlagMustBeSetForRestore", "message": "An existing resource with ID '/subscriptions/{subscriptionId}/resourceGroups/rg-learn-postgresql-ai-eastus/providers/Microsoft.CognitiveServices/accounts/{accountName}' has been soft-deleted. To restore the resource, you must specify 'restore' to be 'true' in the property. If you don't want to restore existing resource, please purge it first."}
    ```

    If you receive this message, modify the `azure deployment group create` command previously to set the `restore` parameter equal to `true` and rerun it.

- If the selected region is restricted from provisioning specific resources, you must set the `REGION` variable to a different location and rerun the commands to create the resource group and run the Bicep deployment script.

    ```bash
    {"status":"Failed","error":{"code":"DeploymentFailed","target":"/subscriptions/{subscriptionId}/resourceGroups/{resourceGrouName}/providers/Microsoft.Resources/deployments/{deploymentName}","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.","details":[{"code":"ResourceDeploymentFailure","target":"/subscriptions/{subscriptionId}/resourceGroups/{resourceGrouName}/providers/Microsoft.DBforPostgreSQL/flexibleServers/{serverName}","message":"The resource write operation failed to complete successfully, because it reached terminal provisioning state 'Failed'.","details":[{"code":"RegionIsOfferRestricted","message":"Subscriptions are restricted from provisioning in this region. Please choose a different region. For exceptions to this rule please open a support request with Issue type of 'Service and subscription limits'. See https://review.learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-request-quota-increase for more details."}]}]}}
    ```

- If the script is unable to create an AI resource due to the requirement to accept the responsible AI agreement, you get the following error. If you get that error, use the Azure portal user interface to create an Azure AI Services resource, and then rerun the deployment script.

    ```bash
    {"code": "InvalidTemplateDeployment", "message": "The template deployment 'deploy' is not valid according to the validation procedure. The tracking id is 'f8412edb-6386-4192-a22f-43557a51ea5f'. See inner errors for details."}
     
    Inner Errors:
    {"code": "ResourceKindRequireAcceptTerms", "message": "This subscription cannot create TextAnalytics until you agree to Responsible AI terms for this resource. You can agree to Responsible AI terms by creating a resource through the Azure Portal then trying again. For more detail go to https://go.microsoft.com/fwlink/?linkid=2164190"}
    ```

## Connect to your database using psql in the Azure Cloud Shell

You connect to the `ContosoHelpDesk` database on your Azure Database for PostgreSQL server using the [psql command-line utility](https://www.postgresql.org/docs/current/app-psql.html) from the [Azure Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview).

1. In the [Azure portal](https://portal.azure.com/), navigate to your newly created Azure Database for PostgreSQL server.

1. In the resource menu, under **Settings**, select **Databases** select **Connect** for the `ContosoHelpDesk` database. Selecting **Connect** doesn't actually connect you to the database; it simply provides instructions for connecting to the database using various methods. Review the instructions to **Connect from browser or locally** and use those instructions to connect using the Azure Cloud Shell.

    ![Screenshot of the Azure Database for PostgreSQL Databases page. Databases and Connect for the ContosoHelpDesk database are highlighted by red boxes.](media/14-postgresql-database-connect.png)

1. At the "Password for user pgAdmin" prompt in the Cloud Shell, enter the randomly generated password for the **pgAdmin** sign in.

    Once you sign in, the `psql` prompt for the `ContosoHelpDesk` database is displayed.

1. Throughout the remainder of this exercise, you continue working in the Cloud Shell, so it helps to expand the pane within your browser window by selecting the **Maximize** button at the top right of the pane.

    ![Screenshot of the Azure Cloud Shell pane with the Maximize button highlighted by a red box.](media/14-azure-cloud-shell-pane-maximize.png)

## Setup: Configure extensions

To store and query vectors, and to generate embeddings, you need to allowlist and enable two extensions for Azure Database for PostgreSQL: `vector` and `azure_ai`.

1. To allowlist both extensions, add `vector` and `azure_ai` to the server parameter `azure.extensions`, as per the instructions provided in [How to use PostgreSQL extensions](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-extensions#how-to-use-postgresql-extensions).

1. Run the following SQL command to enable the `vector` and `azure_ai` extensions. For detailed instructions, read [How to enable and use `pgvector` on Azure Database for PostgreSQL](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-use-pgvector#enable-extension).

    On *ContosoHelpDesk* prompt, run the following SQL commands:

    ```sql
    -- Enable required extensions
    CREATE EXTENSION vector;
    CREATE EXTENSION azure_ai;
    ```

1. To enable the `azure_ai` extension, run the following SQL command. You need the endpoint and API key for the Azure OpenAI resource. For detailed instructions, read [Enable the `azure_ai` extension](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/generative-ai-azure-overview#enable-the-azure_ai-extension).

    On the *ContosoHelpDesk* prompt, run the following commands:

    ```sql
    -- Configure Azure OpenAI (requires azure_ai_settings_manager role)
    SELECT azure_ai.set_setting('azure_openai.endpoint', 'https://<endpoint>.openai.azure.com');      -- e.g., https://YOUR-RESOURCE.openai.azure.com
    SELECT azure_ai.set_setting('azure_openai.subscription_key', '<API Key>');
    ```

## Populate the database with sample data

Before you use the `azure_ai` extension, add a table to the `ContosoHelpDesk` database and populate them with sample data so you have information to work with as you create your application.

1. On the **ContosoHelpDesk** prompt, run the following commands to create the `company_policies` table for storing company policy data:

    ```sql
    -- Create table for policies and embeddings (matches CSV columns)
    DROP TABLE IF EXISTS company_policies CASCADE;

    CREATE TABLE company_policies (
      policy_id          BIGSERIAL PRIMARY KEY,
      title       TEXT NOT NULL,
      department  TEXT NOT NULL,
      policy_text TEXT NOT NULL,
      category    TEXT NOT NULL,
      embedding   vector(1536)  -- The `text-embedding-ada-002` model is configured to return 1,536 dimensions, so use that number for the vector column size.
    );
    ```

1. In your Azure Cloud Shell, use the `COPY` command to load data from CSV files into each table you previously created. Run the following command to populate the `company_policies` table:

    ```sql
    \COPY company_policies (title, department, policy_text, category) FROM 'mslearn-postgresql/Allfiles/Labs/Shared/company-policies.csv' WITH (FORMAT csv, HEADER)
    ```

    The command output should be `COPY 108`, indicating that 108 rows were written into the table from the CSV file.

1. Backfill embeddings for existing rows.

    Run the following command in your **psql** session (Cloud Shell) to compute embeddings for any rows that don’t have them yet. Replace `<EMBEDDING_DEPLOYMENT_NAME>` with the name of your embedding deployment.

    ```sql
    -- Create embeddings for existing rows that currently have no embeddings
    UPDATE company_policies
    SET embedding = azure_openai.create_embeddings('<EMBEDDING_DEPLOYMENT_NAME>', policy_text)::vector
    WHERE embedding IS NULL;
    ```

    This calls your Azure OpenAI embedding deployment from SQL (via `azure_ai`) and stores the result in the column `embedding`.

If you successfully backfilled the 108 rows with embeddings, exit *psql* by typing `\q` and skip the following troubleshooting section. Otherwise, continue with the following troubleshooting steps.

### Troubleshoot 429 errors if encountered

*Skip this section if your UPDATE statement successfully backfilled 108 embeddings*. 

1. Depending on your Azure OpenAI rate limits, you might experience **429 Too Many Requests** errors if you exceed the allowed number of requests. If that is the case for the previous UPDATE statement, you can run the following command to batch the requests and retry (if needed manually reduce the *batch_size* too):

    ```sql
    DO $$
    DECLARE
      batch_size       int := 50;   -- rows per batch
      optimistic_pause int := 10;   -- seconds to wait after a successful batch
      pause_secs       int := 10;   -- current wait (resets to optimistic on success)
      max_pause        int := 60;   -- cap the backoff
      updated          int;
    BEGIN
      LOOP
        BEGIN
          WITH todo AS (
            SELECT policy_id, policy_text
            FROM company_policies
            WHERE embedding IS NULL
            ORDER BY policy_id
            LIMIT batch_size
          )
          UPDATE company_policies p
          SET embedding = azure_openai.create_embeddings('embedding', t.policy_text)::vector
          FROM todo t
          WHERE p.policy_id = t.policy_id;

          GET DIAGNOSTICS updated = ROW_COUNT;
    
          IF updated = 0 THEN
            RAISE NOTICE 'No rows left to embed.';
            EXIT;
          END IF;
    
          -- Success: reset to optimistic pause and sleep briefly
          pause_secs := optimistic_pause;
          RAISE NOTICE 'Updated % rows; sleeping % seconds before next batch.', updated, pause_secs;
          PERFORM pg_sleep(pause_secs);
    
        EXCEPTION WHEN OTHERS THEN
          -- Likely throttled (429) or transient error: back off and retry
          RAISE NOTICE 'Throttled/transient error; backing off % seconds.', pause_secs;
          PERFORM pg_sleep(pause_secs);
          pause_secs := LEAST(pause_secs * 2, max_pause);
        END;
      END LOOP;
    END $$;
    
    ```

1. If you successfully backfilled the 108 rows with embeddings, exit *psql* by typing `\q`, otherwise, try reducing the *batch_size* by 10 and run the previous script again.

### Test the vector table with a similarity query

Let's make sure everything is working by verifying with a similarity search and simple filtering directly from SQL.

1. On the Azure Cloud Shell, connect to the *ContosoHelpDesk* database using *psql* as before.

1. Run the following SQL statement:

    ```sql
    -- Best match for a question (cosine)
    SELECT policy_id, title, department, policy_text
    FROM company_policies
    ORDER BY embedding <=> azure_openai.create_embeddings('embedding',
             'How many vacation days do employees get?')::vector
    LIMIT 1;
    ```

1. Add a filter plus a vector search by running the following SQL statement:

    ```sql
    -- Filter + vector (hybrid)
    SELECT policy_id, title, department, policy_text
    FROM company_policies
    WHERE department = 'HR'
    ORDER BY embedding <=> azure_openai.create_embeddings('embedding',
             'Does the company help me with college expenses')::vector
    LIMIT 3;
    ```

1. Type *\q* and press Enter to exit *psql*.

While these answers are a good start, they might not be comprehensive enough for more complex queries. To address this problem, you can create a Python RAG (Retrieval-Augmented Generation) application that retrieves relevant passages from our database and uses them as context for generating answers.

## Create a Python RAG application to retrieve natural language answers

Now that your embeddings are in place, you can write a short Python script that asks a question, fetches the most relevant policies from PostgreSQL, and prints an answer based only on those passages.

### Update your environment variables

Before you look at our Python application, you need to set the correct environment variables for PostgreSQL and Azure OpenAI.

1. Open your `.env` file:

    ```bash
    code "mslearn-postgresql/Allfiles/Labs/14/.env"
    ```

1. Update your `.env` file with your PostgreSQL and Azure OpenAI credentials:

    ```text
    # PostgreSQL connection
    PGHOST=<server FQDN from output serverFqdn>
    PGUSER=pgAdmin
    PGPASSWORD=<your admin password>
    PGDATABASE=ContosoHelpDesk
    
    # Azure OpenAI
    AZURE_OPENAI_API_KEY=<your Azure OpenAI key>
    AZURE_OPENAI_ENDPOINT=<value from output azureOpenAIEndpoint>  # e.g., https://oai-learn-<region>-<id>.openai.azure.com
    OPENAI_API_VERSION=2024-02-15-preview

    # Deployment names (match the Bicep resources)
    OPENAI_EMBED_DEPLOYMENT=embedding
    OPENAI_CHAT_DEPLOYMENT=chat
    ```

1. Save the file and close the *code* editor.

> [!NOTE]
> If you can't find the save/exit options, on the *code* editor window, move your mouse to the upper right of the editor. Your icon should change, press your mouse button and you should see the options to save and close.

### Update your Python RAG application

On the GitHub repo you cloned, you can find the `app.py` file, which contains the shell for your RAG application. Time to implement the logic to retrieve and answer questions based on the context from PostgreSQL.

1. Open the `CompanyPolicies.py` to add the RAG logic.

    ```bash
    code "mslearn-postgresql/Allfiles/Labs/14/CompanyPolicies.py"
    ```

1. Review the libraries the application depends on. The main library you use for interacting with Azure OpenAI is `langchain_openai`.

1. our first function, `get_conn`, just creates a connection to the PostgreSQL database. This one is predefined for you. For the following three functions, replace the comments with actual code provided.

1. Replace the comment **# Retrieve top-k rows by cosine similarity (embedding must be present)** with the following script:

    ```python
    # Retrieve top-k rows by cosine similarity (embedding must be present)
    def retrieve_chunks(question, top_k=5):
        sql = """
        WITH q AS (
          SELECT azure_openai.create_embeddings(%s, %s)::vector AS qvec
        )
        SELECT policy_id, title, policy_text
        FROM company_policies, q
        WHERE embedding IS NOT NULL
        ORDER BY embedding <=> q.qvec
        LIMIT %s;
        """
        params = (os.getenv("OPENAI_EMBED_DEPLOYMENT"), question, top_k)
        with get_conn() as conn, conn.cursor() as cur:
            cur.execute(sql, params)
            rows = cur.fetchall()
        return [{"policy_id": r[0], "title": r[1], "text": r[2]} for r in rows]
    ```

    This function retrieves the top-k relevant chunks from the PostgreSQL database based on the user's question.

1. Replace the comment **# Format retrieved chunks for the model prompt** with the following script:

    ```python
    # Format retrieved chunks for the model prompt
    def format_context(chunks):
        return "\n\n".join([f"[{c['title']}] {c['text']}" for c in chunks])
    ```

    This function formats the retrieved chunks into a context string suitable for the model prompt.

1. Replace the comment **# Call Azure OpenAI to answer using the provided context** with the following script:

    ```python
    # Call Azure OpenAI to answer using the provided context
    def generate_answer(question, chunks):
        llm = AzureChatOpenAI(
            azure_deployment=os.getenv("OPENAI_CHAT_DEPLOYMENT"),
            api_key=os.getenv("AZURE_OPENAI_API_KEY"),
            azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
            api_version=os.getenv("OPENAI_API_VERSION"),
            temperature=0,
        )
        messages = [
            {"role": "system", "content": "Answer ONLY from the provided context. If it isn't in the context, say you don’t have enough information. Cite policy titles in square brackets, e.g., [Vacation policy]."},
            {"role": "user", "content": f"Question: {question}\nContext:\n{format_context(chunks)}"},
        ]
        return llm.invoke(messages).content
    ```

    This function generates an answer to the user's question using the provided context chunks.

1. The final section of the application is the main application logic. This part of the code prompts the user for a question, retrieves relevant chunks, generates an answer, and loops until the user decides to quit.

1. Save the file and close the *code* editor.

## Run the application

The last thing you need to do before running the application is to set up the Python environment and install the required packages. Finally, you run the application.

```bash
# Navigate to the exercise folder
cd ~/mslearn-postgresql/Allfiles/Labs/14

# Set up the Python environment
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# When prompted, enter a question (for example, How many vacation days do employees get?)
python CompanyPolicies.py
```

Try different questions to see how the model responds.

- What is the company's policy on remote work?
- I need to visit some local customers, can I use the company car for that visit?
- We're expecting a new child, can I take some time off, and is it paid time off?
- What are the guidelines for employee conduct?

Or come up with your own questions, maybe they're covered by the existing policies you added to the database. This small Python script is the basis of a RAG application. You search for relevant documents in the database and use them to answer user questions. But for an effective RAG application, you need to ensure that your document retrieval is fast and scalable. To achieve this fast retrieval, you can implement a vector index.

## Add a vector index (speed at scale)

Since your company_policies table was small, most likely your queries ran relatively fast. However, as the table grows, you should optimize for performance. The first step to improve query performance is to add a vector index.

But adding an index to such a small table might not show significant improvements. So let's go ahead and emulate a larger table by adding 50,000 rows to the table. For this lab, to increase the size of the table, just copy the existing rows multiple times.

1. On the Azure Cloud Shell, connect to the *ContosoHelpDesk* database using *psql* as before.

1. Run the following SQL statement to insert more rows into the company_policies table:

    ```sql
    -- Inflate to ~50k rows (keeps embeddings the same; OK for a demo)
    INSERT INTO company_policies (title, department, policy_text, category, embedding)
    SELECT title || ' (copy ' || gs || ')', department, policy_text, category, embedding
    FROM company_policies
    CROSS JOIN generate_series(1, 500) AS gs;
    ```

Let's review the execution plan for our query with and without the index.

### Run query without a vector index

First, let's run the query without the index.

1. On the Azure Cloud Shell, connect to the *ContosoHelpDesk* database using *psql* as before.

1. Evaluate the execution plan for your query without the index by running the following SQL statement:
  
    ```sql
    -- Disable pagination for better output readability
    \pset pager off
    ```

    ```sql
    EXPLAIN (ANALYZE, BUFFERS)
    SELECT policy_id, title, department, policy_text
    FROM company_policies
    ORDER BY embedding <=> azure_openai.create_embeddings('embedding',
             'How many vacation days do employees get?')::vector
    LIMIT 1;
    ```

This query should return a detailed execution plan. Notice that because it doesn't use an index, the *Execution Time*, and *Buffers* metrics could indicate higher resource usage. If you run the query a second time, the query planner should use cached results, potentially improving performance. Take note of these metrics so you can compare them later.

### Run query with a vector index

Creating an IVFFlat index keeps top-k similarity fast as the table grows. Start simple and tune later.

Let's go ahead and create the index.

1. On the Azure Cloud Shell, connect to the *ContosoHelpDesk* database using *psql* as before.

1. Create the IVFFlat index:

    ```sql
    -- Drop the IVFFlat index
    DROP INDEX IF EXISTS company_policies_embedding_ivfflat_idx;
    
    -- Use cosine distance (vector_cosine_ops) for text embeddings
    CREATE INDEX company_policies_embedding_ivfflat_idx
      ON company_policies
      USING ivfflat (embedding vector_cosine_ops)
      WITH (lists = 100);
    
    ANALYZE company_policies;
    ```

1. Evaluate the execution plan for your query with the index by running the following SQL statement:

    ```sql
    -- Disable pagination for better output readability
    \pset pager off
    ```

    ```sql
    EXPLAIN (ANALYZE, BUFFERS)
    SELECT policy_id, title, department, policy_text
    FROM company_policies
    ORDER BY embedding <=> azure_openai.create_embeddings('embedding',
             'How many vacation days do employees get?')::vector
    LIMIT 1;
    ```

You notice several improvements in the execution plan, including reduced *Execution Time* and *Buffers* metrics. Additionally, you also notice that the query is now using the IVFFlat index. Even if you run the query multiple times, the performance should remain consistent.

### Key takeaways

By completing this exercise, you now know how to build a retrieval augmented application in Python. Your application retrieved the relevant documents and answered user queries intelligently. You scratched the surface of what's possible with RAG applications. With further enhancements, you can improve the accuracy and efficiency of your document retrieval and response generation.

Additionally, you explored how to optimize query performance using vector indexes, which is crucial for scaling your application as the dataset grows. By using these indexes, you can ensure that your RAG application remains responsive and efficient, even as the volume of data increases.

Finally, you learned about the importance of monitoring and fine-tuning your application over time. As user queries evolve and the dataset expands, you need to revisit your indexing strategy, prompt design, and overall architecture to maintain optimal performance and accuracy.

