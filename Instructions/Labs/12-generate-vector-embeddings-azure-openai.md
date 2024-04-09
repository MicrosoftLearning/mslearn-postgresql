To perform semantic search, we need to generate embedding vectors from a model, then use a vector database to store and query those embeddings. Here, you'll set up a database, populate it with sample data, and run semantic searches against those listings.

DIAGRAM:

- Sample data CSV --> database table in a flexible server
- description column from the sample --> OpenAI API & back into vector column
- query text, through OpenAI into vector, then arrow to document vectors showing the `<=>` distance operator

By the end of this exercise, you'll have an Azure Database for PostgreSQL flexible server instance with the `vector` and `azure_ai` extensions enabled. You'll generate embeddings for the [Seattle Airbnb Open Data](https://www.kaggle.com/datasets/airbnb/seattle?select=listings.csv) dataset's `listings` table. You'll also run semantic searches against these listings by generating a query's embedding vector and performing a vector cosine distance search.

## Prerequisites & setup

1. An Azure subscription - [Create one for free](https://azure.microsoft.com/free/cognitive-services?azure-portal=true).
2. Access granted to Azure OpenAI in the desired Azure subscription. Currently, access to this service is granted only by application. You can apply for access to Azure OpenAI by completing the form at https://aka.ms/oai/access.
3. An Azure OpenAI resource with the `text-embedding-ada-002` (Version 2) model deployed. This model is currently only available in [certain regions](https://learn.microsoft.com/azure/ai-services/openai/concepts/models#model-summary-table-and-region-availability). If you do not have a resource, the process for creating one is documented in the [Azure OpenAI resource deployment guide](https://learn.microsoft.com/azure/ai-services/openai/how-to/create-resource).
4. An Azure Database for PostgreSQL Flexible Server instance in your Azure subscription. If you do not have a resource, use either the [Azure portal](https://learn.microsoft.com/azure/postgresql/flexible-server/quickstart-create-server-portal) or the [Azure CLI](https://learn.microsoft.com/azure/postgresql/flexible-server/quickstart-create-server-cli) guide for creating one.

## Open a database connection

If you're using Microsoft Entra authentication, you can connect using `psql` with an access token. For detailed instructions, read [Authenticate with Microsoft Entra ID](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-configure-sign-in-azure-ad-authentication#authenticate-with-microsoft-entra-id).

Example with Bash:

```bash
export PGHOST=<your db server>
export PGUSER=<your user email>
export PGPORT=5432
export PGDATABASE=<your db name>
export PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query "[accessToken]" -o tsv)
psql sslmode=require
```

If you're using Cloud Shell, it already knows who you are (ie you're already authenticated with your Azure credentials in that session of the shell). Otherwise, you can run `az login` from a command line, as described [here](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively) to fetch the access token for your user.

**Suggestion**: You may wish to save the script provided above inside a file, to authenticate new sessions quickly. Make sure you use the `az account` command in the script, not the actual password.

If you're authenticating to PostgreSQL with a user and its corresponding password, you can connect using the following command (it will prompt you for the password):

```bash
psql --host=<postgresql_server_fqdn> --port=5432 --username=<database_user> --dbname=<database_name>
```

## Setup: Configure extensions

To store and query vectors, and to generate embeddings, you need to allow-list and enable two extensions for Azure Database for PostgreSQL Flexible Server: `vector` and `azure_ai`.

1. To allow-list both extensions, add `vector` and `azure_ai` to the server parameter `azure.extensions`, as per the instructions provided in [How to use PostgreSQL extensions](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-extensions#how-to-use-postgresql-extensions).

2. To enable the `vector` extension, run the following SQL command. For detailed instructions, read [How to enable and use `pgvector` on Azure Database for PostgreSQL - Flexible Server](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-use-pgvector#enable-extension).

   ```postgresql
   CREATE EXTENSION vector;
   ```

3. To enable the `azure_ai` extension, run the following SQL command. You'll need the endpoint and API key for the Azure OpenAI resource. For detailed instructions, read [Enable the `azure_ai` extension](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/generative-ai-azure-overview#enable-the-azure_ai-extension).

   ```postgresql
   CREATE EXTENSION azure_ai;
   SELECT azure_ai.set_setting('azure_openai.endpoint', 'https://<endpoint>.openai.azure.com');
   SELECT azure_ai.set_setting('azure_openai.subscription_key', '<API Key>');
   ```

## Load the sample data

First, let's load the [Seattle Airbnb Open Data dataset's `listings` table](https://www.kaggle.com/datasets/airbnb/seattle?select=listings.csv) into the Azure Database for PostgreSQL flexible server instance.

The full `listings` sample table has 92 columns<!-- (TODO link to listings.csv) -->. To simplify, we'll only import three: `id`, `name`, and `description`. <!-- This data is stored in (TODO link to listings-reduced.csv). -->

1. Create the `listings` table in your database.

   In the `psql` prompt, run:

    ```sql
   CREATE TABLE listings (
       id INT PRIMARY KEY,
       name VARCHAR(255) NOT NULL,
       description TEXT NOT NULL
   );
    ```

   This creates an empty table.

   ```
   # SELECT * from listings;
    id | name | description
   ----+------+-------------
   (0 rows)
   ```

2. Import the `listings.csv` file.

   In the `psql` prompt, run:

   ```postgresql
   \copy listings(id, name, description) FROM '/path/to/listings-reduced.csv' DELIMITER ',' CSV HEADER
   ```

   You should get a confirmation that 3,818 rows were copied. You can double-check the table row count:

   ```
   # SELECT COUNT(*) FROM listings;
    count
   -------
     3818
   (1 row)
   ```

**Suggestion**: If you're running psql from the Cloud Shell, you can upload the CSV file to the file system of that shell, by using the *Upload file* button in the shell toolbar. The file is uploaded to the home directory. If you didn't change the context directory of the shell, since you started the shell, you should still be positioned in the home directory and, therefore, referring to the upload copy of `listings-reduced.csv` doesn't need a path qualifier.

![Cloud Shell toolbar highlighting the upload button](media/12-uploadfile.png)

To reset your sample data, you can execute `DROP TABLE listings`, and repeat all steps from [Load the sample data](#load-the-sample-data).

To learn more about the `\copy` command used in the previous step, refer to [psql's copy meta-command](https://www.postgresql.org/docs/current/app-psql.html#APP-PSQL-META-COMMANDS-COPY). To learn about the differences between psql's meta-command `\copy` (client side) and `copy` (server side) command, refer to [COPY command](https://www.postgresql.org/docs/current/sql-copy.html#NOTES).

## Create and store embedding vectors

Now that we have some sample data, it's time to generate and store the embedding vectors. The `azure_ai` extension makes it easy to call the Azure OpenAI embedding API.

1. Add the embedding vector column.

   The `text-embedding-ada-002` model is configured to return 1,536 dimensioins, so use that for the vector column size.

   ```postgresql
   ALTER TABLE listings ADD COLUMN listing_vector vector(1536);
   ```

1. Generate an embedding vector for the description of each listing, by calling Azure OpenAI through the create_embeddings user defined function, which is implemented by the azure_ai extension:

   ```postgresql
   UPDATE listings
   SET listing_vector = azure_openai.create_embeddings('<embedding-ada-002>', description)
   WHERE listing_vector IS NULL;
   ```

   Note that the active quotas may not allow updating all ~4k rows in a single call. In that case, you may run this query to generate 100 embeddings. To have the embedding generated for the description of all listings, run the query multiple times. Running it once is enough for this module.

   ```postgresql
   UPDATE listings
   SET listing_vector = azure_openai.create_embeddings('<embedding-ada-002>', description)
   FROM (SELECT id FROM listings WHERE listing_vector IS NULL ORDER BY id LIMIT 100) subset
   WHERE listings.id = subset.id;
   ```

1. See an example vector by running this query:

   ```sql
   SELECT listing_vector FROM listings LIMIT 1;
   ```

   You will get a result similar to this, but with 1536 vector columns:

   ```
   postgres=> SELECT listing_vector FROM listings LIMIT 1;
   -[ RECORD 1 ]--+------ ...
   listing_vector | [-0.0018742813,-0.04530062,0.055145424, ... ]
   ```

## Perform a semantic search query

Now that you have listings data augmented with embedding vectors, it's time to run a semantic search query. To do so, get the query string embedding vector, then perform a cosine search to find the listings whose descriptions are most semantically similar to the query.

1. Generate the embedding for the query string.

   ```postgresql
   postgres=> SELECT azure_openai.create_embeddings('embedding-ada-002', 'bright natural light');
   ```

   You will get a result like this:

   ```
   -[ RECORD 1 ]-----+-- ...
   create_embeddings | {-0.0020871465,-0.002830255,0.030923981, ...}
   ```

1. Use the embedding in a cosine search (`<=>` represents cosine distance operation), fetching the top 10 most similar listings to the query.

   ```
   SELECT id, name FROM listings ORDER BY listing_vector <=> azure_openai.create_embeddings('embedding-ada-002', 'bright natural light')::vector LIMIT 10;
   ```

   You'll get a result similar to this. Results may vary, depending on which rows were assigned embedding vectors, and what were the exact values the embeddings model produced for any given description:

   ```
      id   |                name                 
   --------+-------------------------------------
    315120 | Large, comfy, light, garden studio
    429453 | Sunny Bedroom #2 w/View: Wallingfrd
     17951 | West Seattle, The Starlight Studio
     48848 | green suite seattle - dog friendly
    116221 | Modern, Light-Filled Fremont Flat
    206781 | Bright & Spacious Studio
    356566 | Sunny Bedroom w/View: Wallingford
      9419 | Golden Sun vintage warm/sunny
    136480 | Bright Cheery Room in Seattle House
    180939 | Central District Green GardenStudio
   (10 rows)
   ```

1. You may also project the `description` column, to be able to read the text of the matching rows whose description were semantically similar. For example, this query returns the best match:

   ```
   SELECT id, name, description FROM listings ORDER BY listing_vector <=> azure_openai.create_embeddings('embedding-ada-002', 'bright natural light')::vector LIMIT 1;
   ```

   Which prints something like:

   ```
      id   |                name                | description
   --------+------------------------------------+------------
    315120 | Large, comfy, light, garden studio | Wonderfully appointed, spacious, light, and a true respite for you to enjoy! We've had the pleasure of furnishing it with a combination of antiques and modern furniture, paintings and art-work, and pretty cool tchotchkes of all sorts. A visual feast! This large studio apartment is spacious, light, and fully, beautifully, furnished. Extremely comfy queen bed with additional air beds available. Garden setting with private, warm, sunny southwest entrance via a tree and bush-lined path. Another east-facing garden path leads to the large shared deck, complete with stream and a beautiful koi pond. Apartment has two large skylights (one giving you a view of the stars when in bed!) and the extremely capacious bathroom has yet a third - as well as a full tub, should you want that relaxing feature. Beautiful, private garden view from the large south-facing window as well as from the French doors. Antique and modern furniture, French chandelier; dining table with chairs. Fresh blueberries, raspbe
   (1 row)
   ```

   To intuitively understand semantic search, observe that the description doesn't actually contain the terms "bright" or "natural". But it does describe the apartment as "light", "sunny", and featuring "skylights".

## Check your work

After performing the above steps, the `listings` table contains sample data from [Seattle Airbnb Open Data](https://www.kaggle.com/datasets/airbnb/seattle/data?select=listings.csv) on Kaggle. The listings were augmented with embedding vectors to execute semantic searches.

1. Confirm the listings table has 4 columns: `id`, `name`, `description`, and `listing_vector`.

   ```postgresql
   \d listings
   ```

   It should print something like:

   ```
                            Table "public.listings"
        Column     |          Type          | Collation | Nullable | Default 
   ----------------+------------------------+-----------+----------+---------
    id             | integer                |           | not null | 
    name           | character varying(255) |           | not null | 
    description    | text                   |           | not null | 
    listing_vector | vector(1536)           |           |          | 
   Indexes:
       "listings_pkey" PRIMARY KEY, btree (id)
   ```

1. Confirm that at least one row has a populated listing_vector column.

   ```postgresql
   SELECT COUNT(*) > 0 FROM listings WHERE listing_vector IS NOT NULL;
   ```

   The result must show a `t`, meaning true. An indication that there's at least one row with embeddings of its corresponding description column:

   ```
    ?column? 
   ----------
    t
   (1 row)
   ```

   Confirm the embedding vector has 1536 dimensions:

   ```
   SELECT vector_dims(listing_vector) FROM listings WHERE listing_vector IS NOT NULL LIMIT 1;
   ```

   Yielding:

   ```
    vector_dims 
   -------------
           1536
   (1 row)
   ```

1. Confirm that semantic searches return results.

   Use the embedding in a cosine search, fetching the top 10 most similar listings to the query.

   ```
   SELECT id, name FROM listings ORDER BY listing_vector <=> azure_openai.create_embeddings('embedding-ada-002', 'bright natural light')::vector LIMIT 10;
   ```

   You'll get a result like this, depending on which rows were assigned embedding vectors:

   ```
      id   |                name                 
   --------+-------------------------------------
    315120 | Large, comfy, light, garden studio
    429453 | Sunny Bedroom #2 w/View: Wallingfrd
     17951 | West Seattle, The Starlight Studio
     48848 | green suite seattle - dog friendly
    116221 | Modern, Light-Filled Fremont Flat
    206781 | Bright & Spacious Studio
    356566 | Sunny Bedroom w/View: Wallingford
      9419 | Golden Sun vintage warm/sunny
    136480 | Bright Cheery Room in Seattle House
    180939 | Central District Green GardenStudio
   (10 rows)
   ```

