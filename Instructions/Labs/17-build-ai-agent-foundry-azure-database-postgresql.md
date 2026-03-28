---
lab:
  title: Build and test an AI agent with Foundry Agent Service and PostgreSQL
  module: Implement generative AI agents with Azure Database for PostgreSQL
  description: In this exercise, you help Margie's Travel create an intelligent agent that retrieves property listings from Azure Database for PostgreSQL using semantic search. The agent runs in Foundry Agent Service and uses a lightweight Python Azure Function to call PostgreSQL, which performs its own AI work through the azureai and pgvector extensions.
  duration: 132 minutes
  level: 400
  islab: true
  primarytopics:
    - Azure
    - Azure Database for PostgreSQL
---

# Build and test an AI agent with Foundry Agent Service and PostgreSQL

In this exercise, you help **Margie's Travel** create an intelligent agent that retrieves property listings from **Azure Database for PostgreSQL** using semantic search.  
The agent runs in **Foundry Agent Service** and uses a lightweight **Python Azure Function** to call PostgreSQL, which performs its own AI work through the `azure_ai` and `pgvector` extensions.

By the end of this exercise, you have an AI agent that:
- Retrieves and ranks vacation listings using semantic similarity.
- Applies **PostgreSQL's built-in AI capabilities** for embeddings and vector search.
- Responds naturally through **Microsoft Foundry**.

## Before you start

You need an [Azure subscription](https://azure.microsoft.com/free) with administrative rights and access to **Foundry Agent Service (Preview)**.

### Deploy resources into your Azure subscription

> If you already have a non-production **Azure Database for PostgreSQL Flexible Server** and an **Microsoft Foundry** project set up, you can skip this section.

You use **Azure Cloud Shell** with the **Bash** environment to deploy and configure resources for this exercise.

1. Open the [Azure portal](https://portal.azure.com/).  
1. Select the **Cloud Shell** icon in the top toolbar and choose **Bash**.  
1. Clone the lab resources:
   ```bash
   git clone https://github.com/MicrosoftLearning/mslearn-postgresql.git
   ```
1. Define variables for your region, resource group, and PostgreSQL admin password:
   ```bash
   REGION=westus3
   RG_NAME=rg-learn-postgresql-ai-$REGION

   a=()
   for i in {a..z} {A..Z} {0..9}; do a[$RANDOM]=$i; done
   ADMIN_PASSWORD=$(IFS=; echo "${a[*]::18}")
   echo "Your generated PostgreSQL admin password is:"
   echo $ADMIN_PASSWORD
   ```
1. (Optional) Set the subscription if you have multiple subscriptions:
   ```azurecli
   az account set --subscription <subscriptionName|subscriptionId>
   ```
1. Create the resource group:
   ```azurecli
   az group create --name $RG_NAME --location $REGION
   ```
1. Deploy the required Azure resources:
   ```azurecli
   az deployment group create      --resource-group "$RG_NAME"      --template-file "~/mslearn-postgresql/Allfiles/Labs/Shared/deploy-all-plus-foundry.bicep"      --parameters adminLogin=pgAdmin adminLoginPassword="$ADMIN_PASSWORD" databaseName=rentals
   ```
   The deployment provisions:
   - An **Azure Database for PostgreSQL Flexible Server** with a `rentals` database
   - An **Azure OpenAI Service** with text-embedding-ada-002 model deployed
   - A **Microsoft Foundry** resource and project with a **gpt-5.1** model deployment for the agent

> Note the PostgreSQL server **FQDN**, username (`pgAdmin`), and password, you'll use these in the next steps.

1. Throughout this exercise, you authenticate to Azure OpenAI using **one** of two methods. Choose the one that applies to your environment and follow only those instructions at each step:

    - **API keys** — use a key copied from the Azure portal (works in most environments).
    - **Managed identity** — use Microsoft Entra ID token-based authentication (required when API keys are disabled at the organization level).

    If you're using **managed identity**, run the following commands now to set it up. Otherwise skip to the next step.

    ```bash
    # Re-derive all variables (in case your Cloud Shell session was reset)
    PGSERVER=$(az postgres flexible-server list -g "$RG_NAME" --query "[0].name" -o tsv)
    AOAI=$(az cognitiveservices account list -g "$RG_NAME" --query "[?kind=='OpenAI'].name | [0]" -o tsv)
    AOAI_ID=$(az cognitiveservices account show -g "$RG_NAME" -n "$AOAI" --query "id" -o tsv)
    SUB_ID=$(az account show --query "id" -o tsv)

    # Enable system-assigned managed identity on the PostgreSQL server
    # (The az CLI has no direct flag for this, so we use az rest per Microsoft docs)
    az rest --method patch \
      --url "https://management.azure.com/subscriptions/$SUB_ID/resourceGroups/$RG_NAME/providers/Microsoft.DBforPostgreSQL/flexibleServers/$PGSERVER?api-version=2024-08-01" \
      --body '{"identity":{"type":"SystemAssigned"}}'

    # Wait for the identity to be assigned, then get the principal ID
    echo "Waiting for system-assigned managed identity..."
    SYS_MI=""
    while [ -z "$SYS_MI" ] || [ "$SYS_MI" = "null" ]; do
      sleep 15
      SYS_MI=$(az rest --method get \
        --url "https://management.azure.com/subscriptions/$SUB_ID/resourceGroups/$RG_NAME/providers/Microsoft.DBforPostgreSQL/flexibleServers/$PGSERVER?api-version=2024-08-01" \
        --query "identity.principalId" -o tsv)
      echo "principalId=$SYS_MI"
    done

    # Grant 'Cognitive Services OpenAI User' to the system MI (for in-database embeddings)
    az role assignment create \
      --assignee "$SYS_MI" \
      --role "Cognitive Services OpenAI User" \
      --scope "$AOAI_ID"

    # Restart the server so it picks up the new identity
    az postgres flexible-server restart -g "$RG_NAME" -n "$PGSERVER"
    ```

    > **Note:** Wait 2-3 minutes after the restart for the server to come back up and for role assignments to propagate. If you receive authorization errors in later steps, wait a couple of minutes and retry.

## Connect to your database using psql in the Azure Cloud Shell

You connect to the `rentals` database on your Azure Database for PostgreSQL server using the [psql command-line utility](https://www.postgresql.org/docs/current/app-psql.html) from the [Azure Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview).

1. In the [Azure portal](https://portal.azure.com/), open the Cloud Shell by selecting the **Cloud Shell** icon in the toolbar.

1. Run the following command to connect to your `rentals` database, replacing `<server-name>` with the name of your PostgreSQL flexible server (found on the **Overview** page of your PostgreSQL resource in the Azure portal):

   ```bash
   psql -h <server-name>.postgres.database.azure.com -p 5432 -U pgAdmin rentals
   ```

1. At the "Password for user pgAdmin" prompt in the Cloud Shell, enter the randomly generated password for the **pgAdmin** sign in.

   Once you sign in, the `psql` prompt for the `rentals` database is displayed.

1. Throughout the remainder of this exercise, you continue working in the Cloud Shell, so it helps to expand the pane within your browser window by selecting the **Maximize** button at the top right of the pane.

## Task 1 – Enable extensions and configure Azure AI settings

```sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS azure_ai;
```

Now configure the `azure_ai` extension connection to Azure OpenAI. You need the endpoint for your Azure OpenAI resource (found on the **Keys and Endpoint** page under **Resource Management** in the Azure portal).

Run the commands for your chosen authentication method:

> **Using API keys:** Copy one of the available keys from the same page. You can use either `KEY 1` or `KEY 2`.

```sql
SELECT azure_ai.set_setting('azure_openai.endpoint', '{endpoint}');
SELECT azure_ai.set_setting('azure_openai.subscription_key', '{api-key}');
```

> **Using managed identity:** Only set the endpoint. When no `subscription_key` is configured, the extension automatically uses the server's system-assigned managed identity.

```sql
SELECT azure_ai.set_setting('azure_openai.endpoint', '{endpoint}');
SELECT azure_ai.set_setting('azure_openai.auth_type', 'managed-identity');
```

These settings allow PostgreSQL to call Azure AI for embedding generation.

## Task 2 – Create tables, load data, and generate embeddings

```sql
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS listings CASCADE;

CREATE TABLE listings (
  id BIGINT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  property_type TEXT NOT NULL,
  room_type TEXT NOT NULL,
  price NUMERIC(10,2),
  weekly_price NUMERIC(10,2),
  listing_vector vector(1536)
);

CREATE TABLE reviews (
  id BIGINT PRIMARY KEY,
  listing_id BIGINT NOT NULL REFERENCES listings(id),
  date DATE,
  comments TEXT NOT NULL
);
```

Load CSV data:

```sql
\COPY listings (id, name, description, property_type, room_type, price, weekly_price)
  FROM 'mslearn-postgresql/Allfiles/Labs/Shared/listings.csv' WITH (FORMAT csv, HEADER);
```
```sql
\COPY reviews (id, listing_id, date, comments)
  FROM 'mslearn-postgresql/Allfiles/Labs/Shared/reviews.csv' WITH (FORMAT csv, HEADER);
```

Generate embeddings inside PostgreSQL:

```sql
UPDATE listings
SET listing_vector = azure_openai.create_embeddings('embedding', description, max_attempts => 5, retry_delay_ms => 500)
WHERE listing_vector IS NULL;
```

## Task 3 – Create an API so Foundry agents can query PostgreSQL

### 3.1 Create a Function App (portal)

Before we can create our agent service, we need to create the **Azure Function App** that hosts our API code for that agent to call.

1. Open the Azure portal, search for and select **Function App**.

1. Select **Create**.

1. On the **Hosting plans** dialog, choose **App Service** and the **Select** button.

   > 💡 *In production, consider **Flex Consumption** or other plans for pay-per-execution scalability.*

1. Complete the **Basics** tab as follows:

   - **Subscription:** your active Azure subscription
   - **Resource Group:** your existing group (`$RG_NAME`)
   - **Function App name:** `func-rental-search-<uniqueID>`
   - **Deploy code or container image:** **Code**
   - **Operating System:** **Linux**
   - **Runtime stack:** **Python 3.11**
   - **Region:** same as your PostgreSQL server
   - **Linux Plan:** accept default or create new
   - **Pricing plan:** lowest available tier (for example Basic B1 or Standard S1)
   - **Zone redundancy:** Disabled

1. On the **Storage** tab, select **Create new** for the storage account and and if necessary, generate a name.

1. Accept the defaults on the **Networking**, **Monitoring**, **Durable Functions**, and **Deployment** tabs.

1. On the **Authentication** tab, change the **Host storage (AzureWebJobsStorage)** authentication typeto **Managed identity**. A **Managed identity** section appears below with a new user-assigned identity (for example `func-rental-search-<uniqueID>-uami`). Accept the defaults — the required **Storage Blob Data Owner** role is assigned automatically. Leave Application Insights as is.

1. Accept the defaults on the **Tags** tab.

1. Select **Review + Create → Create**, wait for deployment, then open your new Function App.

1. Select **Go to resource** to open the Function App overview page.

### 3.2 Set Function App variables (Cloud Shell)

1. Switch to **Cloud Shell (Bash)** in the Azure portal.

1. Set your Function App and resource group variables:
   ```bash
   FUNCAPP_NAME=<your-function-app-name>   # e.g., func-rental-search-abc123
   RG_NAME=<your-resource-group-name>      # e.g., rg-learn-postgresql-ai-westus3
   echo "Function App: $FUNCAPP_NAME"
   echo "Resource Group: $RG_NAME"
   ```

    > **Note:** The Function App uses the storage account that Azure created automatically during the Function App setup. No additional storage configuration is needed.

### 3.3 Add PostgreSQL environment variables (Cloud Shell)

Configure your PostgreSQL connection values in the Function App.

1. Get your PostgreSQL server details:
   ```bash
   PGHOST=$(az postgres flexible-server list \
     --resource-group $RG_NAME \
     --query "[0].fullyQualifiedDomainName" \
     --output tsv)
   
   echo "PostgreSQL server: $PGHOST"
   echo "Admin password: $ADMIN_PASSWORD"
   ```

1. Add all environment variables to the Function App:
   ```bash
   az functionapp config appsettings set \
     --name $FUNCAPP_NAME \
     --resource-group $RG_NAME \
     --settings \
       "PGHOST=$PGHOST" \
       "PGDB=rentals" \
       "PGUSER=pgAdmin" \
       "PGPASSWORD=$ADMIN_PASSWORD" \
       "PGSSLMODE=require" 

   echo "Environment variables configured successfully."
   ```

1. **Enable remote build** so Azure installs the Python dependencies from `requirements.txt`:

   ```bash
   az functionapp config appsettings set \
     --name $FUNCAPP_NAME --resource-group $RG_NAME \
     --settings "SCM_DO_BUILD_DURING_DEPLOYMENT=true" "ENABLE_ORYX_BUILD=true"
   ```

1. Restart the Function App to apply the settings:
   ```bash
   az functionapp restart \
     --name $FUNCAPP_NAME \
     --resource-group $RG_NAME
   
   echo "Function App restarted."
   ```

These entries become the Function's runtime environment variables. Azure Functions automatically maps them to `os.getenv("<NAME>")` in your Python code, allowing `function_app.py` to connect to PostgreSQL securely at runtime.

### 3.4 Review the Function code

The lab repository includes three pre-built files that make up the Azure Function, along with a pre-built zip file for deployment. You should review them so you understand what they do and can modify them if needed.

The files are in `mslearn-postgresql/Allfiles/Labs/18/`:

| File | Purpose |
|------|---------|
| `requirements.txt` | Python dependencies — the Azure Functions SDK and `psycopg` (PostgreSQL driver) |
| `host.json` | Azure Functions runtime configuration — logging settings and extension bundle |
| `function_app.py` | The search API implementation (described below) |
| `rental-search-func.zip` | Pre-built zip of the three files above, ready to deploy |

#### `function_app.py` — The search API

This is the main file. It implements a single HTTP-triggered function using the v2 programming model. Here's what it does:

- **Reads PostgreSQL connection details** from environment variables (`PGHOST`, `PGDB`, `PGUSER`, `PGPASSWORD`, `PGSSLMODE`) — these are the variables you set in step 3.3.
- **Exposes a `POST /api/search` endpoint** that accepts JSON with a `query` (text) and `k` (number of results).
- **Executes a vector search** by calling PostgreSQL's `azure_openai.create_embeddings()` function to generate an embedding from the query text, then uses pgvector's `<->` operator to find the most similar listings.
- **Returns JSON results** with property id, name, description, type, and price — formatted for the Foundry agent to consume.
- **Requires function-level authentication** (`AuthLevel.FUNCTION`) so only callers with a valid function key can access it.

> **Tip:** If you want to customize the search behavior (for example, filter by price range or property type), modify `function_app.py` before deploying and recreate the zip file.

### 3.5 Deploy and test

1. **Deploy the Function code** from Cloud Shell:

   ```bash
   # Get the correct SCM hostname (new Function Apps use a different URL format)
   HOST=$(az functionapp show --name $FUNCAPP_NAME --resource-group $RG_NAME --query defaultHostName -o tsv)
   SCM_HOST=$(echo $HOST | sed 's/\./.scm./')
   echo "SCM host: $SCM_HOST"

   # Deploy using a bearer token (required when Basic auth is disabled)
   cd ~/mslearn-postgresql/Allfiles/Labs/18
   zip deploy.zip function_app.py host.json requirements.txt
   TOKEN=$(az account get-access-token --query accessToken -o tsv)
   curl -s -X POST --data-binary "@deploy.zip" \
     -H "Authorization: Bearer $TOKEN" \
     "https://$SCM_HOST/api/zipdeploy"
   ```

   You should see an empty response — that means it succeeded.

   > **Note:** If you receive a `401 Unauthorized` error, your token may have expired. Run the `TOKEN=...` and `curl` commands again.

   Wait 1-2 minutes for the remote build to install Python dependencies.

1. **Restart the Function App**:
   ```bash
   az functionapp restart \
     --name $FUNCAPP_NAME \
     --resource-group $RG_NAME
   
   echo "Function App restarted. Waiting for startup..."
   sleep 30
   ```

1. **Get the Function App URL and function key**:
   ```bash
   HOST=$(az functionapp show \
     --name $FUNCAPP_NAME \
     --resource-group $RG_NAME \
     --query defaultHostName \
     --output tsv)
   
   # Get the default host key for authentication
   FUNC_KEY=$(az functionapp keys list \
     --name $FUNCAPP_NAME \
     --resource-group $RG_NAME \
     --query "functionKeys.default" \
     --output tsv)
   
   # If default is null, get the master host key
   if [ -z "$FUNC_KEY" ] || [ "$FUNC_KEY" = "null" ]; then
     FUNC_KEY=$(az functionapp keys list \
       --name $FUNCAPP_NAME \
       --resource-group $RG_NAME \
       --query "masterKey" \
       --output tsv)
   fi
   
   echo ""
   echo "Deployment complete!"
   echo ""
   echo "Your Function Key (save this for the next task):"
   echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
   echo "$FUNC_KEY"
   echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
   echo ""
   echo "Search endpoint:"
   echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
   echo "https://$HOST/api/search"
   echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
   echo ""
   echo "For the next task, you'll need:"
   echo "  • Function App Host: $HOST"
   echo "  • Function Key: $FUNC_KEY"
   ```

1. **Test the search endpoint**:
   ```bash
   echo ""
   echo "Testing search endpoint..."
   curl -s -X POST "https://$HOST/api/search?code=$FUNC_KEY" \
     -H "Content-Type: application/json" \
     -d '{"query": "beachfront property with ocean view", "k": 3}' \
     | python3 -m json.tool
   ```

**Expected results**:

> Search should return a JSON response with rental listings similar to:
> ```json
> {
>   "results": [
>     {
>       "id": 41,
>       "name": "Magazine Profiled with Gorgeous View",
>       "description": "...",
>       "property_type": "House",
>       "room_type": "Entire home/apt",
>       "price": 395.0,
>       "weekly_price": null
>     }
>   ]
> }
> ```

**Troubleshooting**:
> - If you get a 404, wait 30 more seconds for the Function to fully start, then try again
> - If search fails, verify PostgreSQL environment variables in the portal under Function App → Configuration
> - Check Function App logs: Portal → Function App → Monitor → Log stream

---

## Task 4 – Create an agent and register the API in Microsoft Foundry

Now create an agent in Microsoft Foundry and register your Function API as a tool so the agent can call it.

1. Go to [Microsoft Foundry](https://ai.azure.com/).

    > **Note:** If you see a **New Foundry** toggle in the upper-right corner, make sure it's turned **on** to use the latest version of the Foundry portal.

1. Your project should appear in the upper-left corner of the page (it starts with `foundry-`). If a different project is shown, select the project name in the upper-left to switch to the correct one.

1. On the project home page, select **Create agents**.

1. Select **+ New agent** and configure:
   - **Agent name**: `RentalAdvisor`
   - Select **Create**

1. Under Model selection, choose the **gpt-5.1** deployment that was created in your Foundry resource. If you don't see it, choose **Browse more models** and filter by your resource name to find and select it.

    > **Important:** Not all model versions support the OpenAPI tool, and not all models are available in every region. For this exercise, **gpt-5.1** is used because it supports the OpenAPI tool and is available in the West US 3 region. If you use a different region, consult the [tool support by region and model](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/tool-best-practice#tool-support-by-region-and-model) documentation to choose a compatible model.

1. In the **Instructions** field, paste the following:

   ```
   You are an assistant for Margie's Travel helping customers find vacation rental properties.

   When users ask for property recommendations, use the postgresqlRentalSearch tool with their
   natural language query and a reasonable k value (3-5 results).

   Use the JSON results from the tool to craft a friendly, natural-language response that
   highlights the property names, descriptions, and prices. Be conversational and helpful.
   ```

1. Scroll down to the **Tools** section. Select **Add**, then select **Browse all tools**.

1. In the **Select a tool** dialog, select the **Custom** tab.

1. Select **OpenAPI tool** and select **Create**.

1. Configure the tool:

   - **Name**: `postgresqlRentalSearch`
   - **Description**: `Searches vacation rental properties using semantic search on PostgreSQL. Returns property listings matching natural language queries.`
   - **Authentication**: Select **Anonymous**
   - In the **OpenAPI Specification** text area, paste the following JSON. Replace `<your-func-host>` with your Function App hostname and `<your-function-key>` with your function key from the previous task:

   ```json
   {
     "openapi": "3.0.0",
     "info": {
       "title": "PostgreSQL Rental Search API",
       "version": "1.0.0",
       "description": "Semantic search API for vacation rental properties using PostgreSQL vector search"
     },
     "servers": [
       {
         "url": "https://<your-func-host>"
       }
     ],
     "paths": {
       "/api/search": {
         "post": {
           "summary": "Search rental properties",
           "description": "Performs semantic search on rental property listings using natural language queries",
           "operationId": "searchRentals",
           "parameters": [
             {
               "name": "code",
               "in": "query",
               "required": true,
               "schema": {
                 "type": "string",
                 "default": "<your-function-key>"
               }
             }
           ],
           "requestBody": {
             "required": true,
             "content": {
               "application/json": {
                 "schema": {
                   "type": "object",
                   "required": ["query"],
                   "properties": {
                     "query": {
                       "type": "string",
                       "description": "Natural language search query (e.g., 'beachfront property with ocean view')"
                     },
                     "k": {
                       "type": "integer",
                       "description": "Number of results to return (1-10)",
                       "default": 3,
                       "minimum": 1,
                       "maximum": 10
                     }
                   }
                 }
               }
             }
           },
           "responses": {
             "200": {
               "description": "Successful search",
               "content": {
                 "application/json": {
                   "schema": {
                     "type": "object",
                     "properties": {
                       "results": {
                         "type": "array",
                         "items": {
                           "type": "object",
                           "properties": {
                             "id": {"type": "integer"},
                             "name": {"type": "string"},
                             "description": {"type": "string"},
                             "property_type": {"type": "string"},
                             "room_type": {"type": "string"},
                             "price": {"type": "number"},
                             "weekly_price": {"type": "number", "nullable": true}
                           }
                         }
                       }
                     }
                   }
                 }
               }
             }
           }
         }
       }
     }
   }
   ```

1. Select **Create tool** to add the tool to your agent.

---
## Task 5 – Test your agent

Time to see your agent in action!

On the chat screen, enter messages like:

```
Find beachside apartments with great reviews.
```

```
Recommend a quiet cabin for families.
```

```
Show modern apartments near downtown.
```

Try other variations you can think of!

The agent calls the Function, which embeds and queries PostgreSQL, then summarizes the results.


## Task 6 – Clean up

```azurecli
az group delete --name $RG_NAME --yes --no-wait
```

---

## Key takeaways

This exercise demonstrates a foundational pattern for building AI agents with PostgreSQL and Microsoft Foundry. The **RentalAdvisor** agent you created is just one example. The same architecture supports multiple specialized agents working together. For example, you could build more agents for booking, reviews, pricing, and more.

**Agents you could add to this project:**

- **BookingAgent** – Handles reservations, checks availability, and manages to book confirmations using PostgreSQL transaction tables
- **ReviewAnalyzer** – Analyzes sentiment from the reviews table, summarizes guest feedback, and identifies property strengths/weaknesses
- **PriceOptimizer** – Recommends dynamic pricing based on seasonal trends, demand patterns, and historical booking data
- **MaintenanceScheduler** – Tracks property maintenance requests, schedules repairs, and alerts property managers
- **CustomerSupportAgent** – Answers FAQs, handles guest inquiries, and escalates complex issues to human staff

Each agent would use the same pattern: an Azure Function connected to PostgreSQL, registered as a custom tool in Microsoft Foundry. Agents can work independently or collaborate, for example, **RentalAdvisor** finds properties, then hands off to **BookingAgent** to complete the reservation.

**Architecture strengths:**

- **PostgreSQL's AI capabilities** handle embeddings and vector search natively, eliminating the need for separate vector databases
- **Microsoft Foundry** orchestrates multi-agent conversations, manages context, and handles complex reasoning
- **Azure Functions provides lightweight, scalable API endpoints that connect your data to AI agents
- **Secure by design** – managed identities, function keys, and Azure's security features protect your data

This modular approach scales from simple single-agent scenarios to sophisticated multi-agent systems that handle complex business processes across your data.