---
lab:
    title: 'Build and test an AI agent with Foundry Agent Service and PostgreSQL'
    module: 'Implement generative AI agents with Azure Database for PostgreSQL'
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
   - An **Azure Database for PostgreSQL Flexible Server** named `rentals`
   - An **Azure Storage Account** for Function App operations
   - An **Azure OpenAI Service** with text-embedding-ada-002 model deployed
   - An **Microsoft Foundry** project for building the agent

> Note the PostgreSQL server **FQDN**, username (`pgAdmin`), and password, you'll use these in the next steps.

## Connect to your database using psql in the Azure Cloud Shell

You connect to the `rentals` database on your Azure Database for PostgreSQL server using the [psql command-line utility](https://www.postgresql.org/docs/current/app-psql.html) from the [Azure Cloud Shell](https://learn.microsoft.com/azure/cloud-shell/overview).

1. In the [Azure portal](https://portal.azure.com/), navigate to your newly created Azure Database for PostgreSQL server.

1. In the resource menu, under **Settings**, select **Databases** and then select **Connect** for the `rentals` database. Selecting **Connect** doesn't actually connect you to the database; it simply provides instructions for connecting to the database using various methods. Review the instructions to **Connect from browser or locally** and use those instructions to connect using the Azure Cloud Shell.

   ![Screenshot of the Azure Database for PostgreSQL Databases page. Databases and Connect for the rentals database are highlighted by red boxes.](./media/17-postgresql-rentals-database-connect.png)

1. Open the **Cloud Shell (Bash)** in the Azure portal if it's not already open.

1. In the Cloud Shell, run the `psql` command provided in the **Connect from browser or locally** instructions. It should look similar to the following command (replace `<your-postgresql-server-name>` with your actual server name):
   ```bash
   psql -h <your-postgresql-server-name>.postgres.database.azure.com -p 5432 -U pgAdmin rentals
   ```

1. At the "Password for user pgAdmin" prompt in the Cloud Shell, enter the randomly generated password for the **pgAdmin** sign in.

   Once you sign in, the `psql` prompt for the `rentals` database is displayed.

1. Throughout the remainder of this exercise, you continue working in the Cloud Shell, so it helps to expand the pane within your browser window by selecting the **Maximize** button at the top right of the pane.

## Task 1 – Enable extensions and configure Azure AI settings

```sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS azure_ai;

SELECT azure_ai.set_setting('azure_openai.endpoint', 'https://<your-openai-account>.openai.azure.com');
SELECT azure_ai.set_setting('azure_openai.subscription_key', '<your-api-key>');
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

1. Select **Review + Create → Create**, wait for deployment, then open your new Function App.

1. Select **Go to resource** to open the Function App overview page.

### 3.2 Configure managed identity and storage (Cloud Shell)

Now configure the Function App to use managed identity for secure access to the storage account that was created during the initial deployment.

1. Switch to **Cloud Shell (Bash)** in the Azure portal.

1. Set your Function App and resource group variables:
   ```bash
   FUNCAPP_NAME=<your-function-app-name>   # e.g., func-rental-search-abc123
   RG_NAME=<your-resource-group-name>      # e.g., rg-learn-postgresql-ai-westus3
   echo "Function App: $FUNCAPP_NAME"
   echo "Resource Group: $RG_NAME"
   ```

1. Enable system-assigned managed identity on the Function App:
   ```bash
   az functionapp identity assign \
     --name $FUNCAPP_NAME \
     --resource-group $RG_NAME
   
   PRINCIPAL_ID=$(az functionapp identity show \
     --name $FUNCAPP_NAME \
     --resource-group $RG_NAME \
     --query principalId \
     --output tsv)
   
   echo "Managed identity enabled with Principal ID: $PRINCIPAL_ID"
   ```

1. Find the existing storage account that was created during the initial deployment:

   Azure Functions requires a storage account for internal operations like metadata, logs, and coordination. The Bicep template already created one for you. Now you configure the Function App to access it using managed identity for secure, connection-string-free access.

   ```bash
   # Find the storage account in your resource group
   STORAGE_NAME=$(az storage account list \
     --resource-group $RG_NAME \
     --query "[0].name" \
     --output tsv)
   
   echo "Found storage account: $STORAGE_NAME"
   
   # Get the storage account resource ID
   STORAGE_ID=$(az storage account show \
     --name $STORAGE_NAME \
     --resource-group $RG_NAME \
     --query id \
     --output tsv)
   
   # Grant Storage Blob Data Contributor role to the Function App identity
   az role assignment create \
     --assignee $PRINCIPAL_ID \
     --role "Storage Blob Data Contributor" \
     --scope $STORAGE_ID
   
   # Grant Storage Queue Data Contributor role to the Function App identity
   az role assignment create \
     --assignee $PRINCIPAL_ID \
     --role "Storage Queue Data Contributor" \
     --scope $STORAGE_ID
   
   # Grant Storage Table Data Contributor role to the Function App identity
   az role assignment create \
     --assignee $PRINCIPAL_ID \
     --role "Storage Table Data Contributor" \
     --scope $STORAGE_ID
   
   echo "Managed identity granted Contributor roles for Blob, Queue, and Table storage."
   ```
   
1. Remove any existing AzureWebJobsStorage connection string setting:

   The Function App usually is created with a default connection string pointing to a storage account using shared keys. When using managed identity, you must remove this old setting first.

   ```bash
   # Remove old connection string setting if it exists
   az functionapp config appsettings delete \
     --name $FUNCAPP_NAME \
     --resource-group $RG_NAME \
     --setting-names "AzureWebJobsStorage"
   
   echo "Removed old AzureWebJobsStorage connection string (if it existed)."
   ```

1. Update the Function App to use managed identity for storage:

   ```bash
   # Get the blob endpoint
   BLOB_ENDPOINT=$(az storage account show \
     --name $STORAGE_NAME \
     --resource-group $RG_NAME \
     --query primaryEndpoints.blob \
     --output tsv)
   
   # Configure Function App to use managed identity for storage
   az functionapp config appsettings set \
     --name $FUNCAPP_NAME \
     --resource-group $RG_NAME \
     --settings \
       "AzureWebJobsStorage__accountName=$STORAGE_NAME" \
       "AzureWebJobsStorage__blobServiceUri=${BLOB_ENDPOINT}" \
       "AzureWebJobsStorage__queueServiceUri=$(echo $BLOB_ENDPOINT | sed 's/blob/queue/')" \
       "AzureWebJobsStorage__tableServiceUri=$(echo $BLOB_ENDPOINT | sed 's/blob/table/')" \
       "AzureWebJobsStorage__credential=managedidentity"
   
   echo "Storage configured to use managed identity."
   ```

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

1. Restart the Function App to apply the settings:
   ```bash
   az functionapp restart \
     --name $FUNCAPP_NAME \
     --resource-group $RG_NAME
   
   echo "Function App restarted."
   ```

These entries become the Function's runtime environment variables. Azure Functions automatically maps them to `os.getenv("<NAME>")` in your Python code, allowing `function_app.py` to connect to PostgreSQL securely at runtime.

### 3.4 Author the Python code (Cloud Shell)

Now create the Function's Python code files.

If Cloud Shell prompts you to **switch to Classic mode** when using `code`, accept it. If the shell reloads, rerun the variable commands from step 3.2 and start here again.

1. Set up a working folder:
   ```bash
   mkdir -p $HOME/rental-search-func
   cd $HOME/rental-search-func
   ```

1. Create `requirements.txt`:
   ```bash
   code requirements.txt
   ```
   Paste and save:
   ```text
   azure-functions>=1.20.0,<2.0.0
   psycopg[binary]>=3.2.1,<4.0.0
   ```

1. Create `function_app.py`:

   This Python file implements the Azure Function using the v2 programming model. *The Microsoft Foundry agent calls this API to retrieve rental property data when responding to user queries.* The code:
   
      - **Connects to PostgreSQL** using environment variables for secure authentication
      - **Defines a search endpoint** (`/search`) that accepts POST requests with query text and result count
      - **Validates input** to ensure query safety
      - **Executes vector search** by calling PostgreSQL's `azure_openai.create_embeddings()` function to generate embeddings on-demand, then uses pgvector's `<->` operator to find the most similar listings
      - **Returns JSON results** formatted for the AI agent to consume
      - **Requires function-level authentication** to protect your data

   ```bash
   code function_app.py
   ```

   Paste and save:
   
   ```python
   import os
   import json
   import logging
   import psycopg
   import azure.functions as func
   from datetime import datetime

   # Configure logging
   logging.basicConfig(level=logging.INFO)
   logger = logging.getLogger(__name__)

   app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

   # Database connection parameters from environment variables
   PGHOST = os.getenv("PGHOST")
   PGDB = os.getenv("PGDB", "rentals")
   PGUSER = os.getenv("PGUSER")
   PGPASSWORD = os.getenv("PGPASSWORD")
   PGSSLMODE = os.getenv("PGSSLMODE", "require")

   def log_env_vars():
      """Log environment variables for debugging (masked)"""
      logger.info("=== Environment Variables ===")
      logger.info(f"PGHOST: {PGHOST}")
      logger.info(f"PGDB: {PGDB}")
      logger.info(f"PGUSER: {PGUSER}")
      logger.info(f"PGPASSWORD: {'***' if PGPASSWORD else 'NOT SET'}")
      logger.info(f"PGSSLMODE: {PGSSLMODE}")
      logger.info("============================")

   def get_db_conn():
      logger.info("Creating database connection...")
      try:
         conn = psycopg.connect(
               host=PGHOST,
               dbname=PGDB,
               user=PGUSER,
               password=PGPASSWORD,
               sslmode=PGSSLMODE,
               autocommit=True,
               connect_timeout=10
         )
         logger.info("Database connection successful!")
         return conn
      except Exception as e:
         logger.error(f"Database connection failed: {str(e)}")
         raise

   @app.route(route="search", methods=["POST"])
   def search(req: func.HttpRequest) -> func.HttpResponse:
      timestamp = datetime.utcnow().isoformat()
      logger.info(f"========== NEW REQUEST {timestamp} ==========")
      
      try:
         # Log environment on first request
         log_env_vars()
         
         # Parse request body
         logger.info("Parsing request body...")
         try:
               req_body = req.get_json()
               logger.info(f"Request body parsed: {req_body}")
         except Exception as e:
               logger.error(f"Failed to parse JSON: {str(e)}")
               return func.HttpResponse(
                  json.dumps({"error": "Invalid JSON in request body", "details": str(e)}),
                  mimetype="application/json",
                  status_code=400
               )
         
         query = req_body.get('query')
         k = req_body.get('k', 3)
         
         logger.info(f"Query: '{query}', k: {k}")
         
         if not query:
               logger.warning("Query parameter missing")
               return func.HttpResponse(
                  json.dumps({"error": "Missing 'query' parameter"}),
                  mimetype="application/json",
                  status_code=400
               )
         
         # Validate k
         if not isinstance(k, int) or k < 1 or k > 10:
               logger.warning(f"Invalid k value: {k}, using default 3")
               k = 3
         
         # Connect to database
         logger.info("Connecting to PostgreSQL...")
         with get_db_conn() as conn:
               with conn.cursor() as cur:
                  # Generate embedding and perform vector search in one query
                  logger.info("Performing semantic search...")
                  search_query = """
                     WITH query_embedding AS (
                        SELECT azure_openai.create_embeddings('embedding', %s, max_attempts => 5, retry_delay_ms => 500) AS emb
                     )
                     SELECT l.id, l.name, l.description, l.property_type, l.room_type, l.price, l.weekly_price
                     FROM listings l, query_embedding qe
                     WHERE l.listing_vector IS NOT NULL
                     ORDER BY l.listing_vector <-> qe.emb
                     LIMIT %s;
                  """
                  
                  try:
                     cur.execute(search_query, (query, k))
                     rows = cur.fetchall()
                     logger.info(f"Vector search returned {len(rows)} results")
                  except Exception as e:
                     logger.error(f"Vector search failed: {str(e)}")
                     raise
                  
                  # Format results
                  logger.info("Formatting results...")
                  results = []
                  for idx, row in enumerate(rows):
                     logger.info(f"Processing row {idx + 1}: id={row[0]}, name={row[1][:30]}...")
                     results.append({
                           "id": row[0],
                           "name": row[1],
                           "description": row[2],
                           "property_type": row[3],
                           "room_type": row[4],
                           "price": float(row[5]) if row[5] is not None else None,
                           "weekly_price": float(row[6]) if row[6] is not None else None
                     })
                  
                  logger.info(f"Successfully formatted {len(results)} results")
                  logger.info("========== REQUEST COMPLETED SUCCESSFULLY ==========")
                  
                  return func.HttpResponse(
                     json.dumps({"results": results}),
                     mimetype="application/json",
                     status_code=200
                  )
                  
      except ValueError as e:
         logger.error(f"ValueError: {str(e)}", exc_info=True)
         return func.HttpResponse(
               json.dumps({"error": "Invalid JSON in request body", "details": str(e)}),
               mimetype="application/json",
               status_code=400
         )
      except Exception as e:
         logger.error(f"FATAL ERROR: {str(e)}", exc_info=True)
         return func.HttpResponse(
               json.dumps({"error": str(e), "type": type(e).__name__}),
               mimetype="application/json",
               status_code=500
         )
   ```

1. Create `host.json`:
   ```bash
   code host.json
   ```
   Paste and save:
   ```json
   {
      "version": "2.0",
      "logging": {
         "applicationInsights": {
            "samplingSettings": {
            "isEnabled": true,
            "excludedTypes": "Request"
            }
         },
         "logLevel": {
            "default": "Information",
            "Function": "Information"
         }
      },
      "extensionBundle": {
         "id": "Microsoft.Azure.Functions.ExtensionBundle",
         "version": "[4.*, 5.0.0)"
      }
   }
   ```

1. Verify the files were created:
   ```bash
   ls -la
   echo "---"
   echo "Files created successfully:"
   echo "- requirements.txt"
   echo "- function_app.py"
   echo "- host.json"
   ```

### 3.5 Deploy and test (Cloud Shell)

1. **Ensure variables are set** (if Cloud Shell reloaded, rerun these commands):

   ```bash
   # If variables are not set, run:
   FUNCAPP_NAME=<your-function-app-name>
   RG_NAME=<your-resource-group-name>
   echo "Function App: $FUNCAPP_NAME"
   echo "Resource Group: $RG_NAME"
   ```

1. **Deploy the Function via zip** (This step takes several minutes to run):

   ```bash
   cd $HOME/rental-search-func
   
   # Clean up any previous deployment
   rm -f app.zip
   
   # Create zip file (exclude hidden files and git directories)
   zip -r app.zip . -x ".*" "*.git*" "__pycache__/*" "*.pyc"
   
   # Deploy to Azure
   az functionapp deployment source config-zip \
     --name $FUNCAPP_NAME \
     --resource-group $RG_NAME \
     --src app.zip \
     --build-remote true

   echo "Deployment initiated. Waiting for completion..."
   sleep 30
   ```

1. **Restart the Function App to ensure all changes take effect**:
   ```bash
   az functionapp restart \
     --name $FUNCAPP_NAME \
     --resource-group $RG_NAME
   
   echo "Function App restarted. Waiting for startup..."
   sleep 20
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
   echo "Your Function Key (save this for Task 4):"
   echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
   echo "$FUNC_KEY"
   echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
   echo ""
   echo "Search endpoint:"
   echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
   echo "https://$HOST/api/search"
   echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
   echo ""
   echo "For Task 4, you'll need:"
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

## Task 4 – Register the API as a custom tool in Microsoft Foundry

Now register your Function API with Microsoft Foundry so the agent can call it.

> **Note**: This exercise uses an HTTP-triggered Azure Function with an OpenAPI specification, which allows the agent to call your function as a custom tool. Microsoft Foundry also supports native queue-based integration for queue-triggered functions, but the HTTP approach with OpenAPI offers simpler deployment and direct REST API access suitable for this learning scenario.

1. Go to [AI Foundry (Preview)](https://ai.azure.com/).  

1. Navigate to your project, then select **Agents** from the left menu.

1. Select **+ New agent** and configure:
   - **Agent name**: `RentalAdvisor`
   - **Deployment**: select the latest GPT-4 deployment available
   - Select **Create**

1. In the agent setup page, scroll down to the **Actions (0)** section and select **Add**.

1. In the **Create a custom tool** wizard:

   **Step 1 - Tool details**:
   - **Name**: `postgresqlRentalSearch`
   - **Description**: `Searches vacation rental properties using semantic search on PostgreSQL. Returns property listings matching natural language queries.`
   - Select **Next**

1. On **Step 2 - Define schema**:

   - **Authentication method**: Select **Anonymous** from the dropdown.
   - In the **OpenAPI Specification** text area, paste the following specification, replacing `<your-func-host>` with your Function App hostname and `<your-function-key>` with your function key from step 3.5:
   
   > **Note**: This approach embeds the function key as a query parameter in the OpenAPI specification. The specification is stored securely by Microsoft Foundry and the key is not exposed to end users.
   
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
         "url": "https://<your-func-host>/api/search"
       }
     ],
     "paths": {
       "/": {
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

1. Select **Next** and then select **Create Tool**.

1. Update the agent instructions:

   ```
   You are an assistant for Margie's Travel helping customers find vacation rental properties.
   
   When users ask for property recommendations, use the postgresqlRentalSearch tool with their 
   natural language query and a reasonable k value (3-5 results). 
   
   Use the JSON results from the tool to craft a friendly, natural-language response that 
   highlights the property names, descriptions, and prices. Be conversational and helpful.
   ```

Your agent is now ready to use the PostgreSQL-backed rental search tool!

---

## Task 5 – Test your agent

Time to see your agent in action!

Select the **Playground**:

On the chat screen, enter queries like:

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