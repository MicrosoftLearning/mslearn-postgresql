To perform semantic search, we need to generate embedding vectors from a model, then use a vector database to store and query those embeddings. Here, you'll set up a database, populate it with sample data, and run semantic searches against those listings.

DIAGRAM:

- Sample data CSV --> database table in a flexible server
- description column from the sample --> OpenAI API & back into vector column
- query text, through OpenAI into vector, then arrow to document vectors showing the `<=>` distance operator

By the end of this exercise, you'll have an Azure Database for PostgreSQL flexible server instance with the `pgvector` and `azure_ai` extensions enabled. You'll generate embeddings for the [Seattle Airbnb Open Data](https://www.kaggle.com/datasets/airbnb/seattle?select=listings.csv) dataset's `listings` table. You'll also run semantic searches against these listings by generating a query's embedding vector and performing a vector cosine distance search.

## Prerequisites & setup

1. An Azure subscription - [Create one for free](https://azure.microsoft.com/free/cognitive-services?azure-portal=true).
2. Access granted to Azure OpenAI in the desired Azure subscription. Currently, access to this service is granted only by application. You can apply for access to Azure OpenAI by completing the form at https://aka.ms/oai/access.
3. An Azure OpenAI resource with the `text-embedding-ada-002` (Version 2) model deployed. This model is currently only available in [certain regions](https://learn.microsoft.com/azure/ai-services/openai/concepts/models#model-summary-table-and-region-availability). If you do not have a resource, the process for creating one is documented in the [Azure OpenAI resource deployment guide](https://learn.microsoft.com/azure/ai-services/openai/how-to/create-resource).
4. An Azure Database for PostgreSQL Flexible Server instance in your Azure subscription. If you do not have a resource, use either the [Azure portal](https://learn.microsoft.com/azure/postgresql/flexible-server/quickstart-create-server-portal) or the [Azure CLI](https://learn.microsoft.com/azure/postgresql/flexible-server/quickstart-create-server-cli) guide for creating one.

## Open a database connection

If you're using Microsoft Entra authentication, you can connect using `psql` with an access token. For more detailed instructions, see: [Authenticate with Microsoft Entra ID](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-configure-sign-in-azure-ad-authentication#authenticate-with-microsoft-entra-id). Example with Bash:

```bash
export PGHOST=<your db server>
export PGUSER=<your user email>
export PGPORT=5432
export PGDATABASE=<your db name>
export PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query "[accessToken]" -o tsv)
psql sslmode=require
```

If you're using Cloud Shell, it already knows who you are. Otherwise, you can run `az login` from a command line as described [here](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively) to fetch the access token for your user.

**TIP**: you may wish to put the above in a script to authenticate new sessions quickly. Make sure to use the `az account` command in the script, not the actual password.

If you're using a user and password, you can connect like this; it will prompt you for the password:

```bash
psql --host=<your db server> --port=5432 --username=<db user> --dbname=<db name>
```

## Setup: configure extensions

To store and query vectors, and to generate embeddings, you need to allow-list and enable two extensions for Azure Database for PostgreSQL Flexible Server.

1. Add `vector` and `azure_ai` to the server parameter `azure.extensions`, following these [instructions](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-extensions#how-to-use-postgresql-extensions).

2. Enable the `vector` extension. For detailed instructions, see: [How to enable and use `pgvector` on Azure Database for PostgreSQL - Flexible Server](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-use-pgvector#enable-extension).

   ```postgresql
   CREATE EXTENSION vector;
   ```

3. Enable the `azure_ai` extension. You'll need the endpoint and API key for the Azure OpenAI resource. For detailed instructions, see: [Enable the `azure_ai` extension](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/generative-ai-azure-overview#enable-the-azure_ai-extension).

   ```postgresql
   CREATE EXTENSION azure_ai;
   SELECT azure_ai.set_setting('azure_openai.endpoint','https://<endpoint>.openai.azure.com');
   SELECT azure_ai.set_setting('azure_openai.subscription_key', '<API Key>');
   ```

## Load the sample data

First, let's load the [Seattle Airbnb Open Data](https://www.kaggle.com/datasets/airbnb/seattle?select=listings.csv) dataset's `listings` table into the Azure Database for PostgreSQL flexible server instance.

The full `listings` sample table (TODO link to listings.csv) has 92 columns. To simplify, we'll only import 3: the listing's `id`, its `name`, and its `description`. This data is stored in (TODO link to listings-reduced.csv).

1. Create the `listings` table in your database.

   In the `psql` session, run this SQL:

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

   In the `psql` session, run this command:

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

**TIP**: if you're using Cloud Shell, you can upload the CSV file to the file system running `psql` using the *Upload file* button in the shell toolbar. This uploads the file to the home directory. If you didn't change the directory of the shell, then `listings-reduced.csv` will not need a path qualifier.

![Cloud Shell toolbar highlighting the upload button](media/12-uploadfile.png)

To reset your sample data, you may execute `DROP TABLE listings` and restart this process.

Read more about the `\copy` command [here](https://www.postgresql.org/docs/current/sql-copy.html), noting the difference between `copy` (server side) and `\copy` (client side).

## Create and store embedding vectors

Now that we have some sample data, it's time to generate and store the embedding vectors. The `azure_ai` extension makes it easy to call the Azure OpenAI embedding API.

1. Add the embedding vector column.

   The `text-embedding-ada-002` model is configured to return 1,536 dimensioins, so use that for the vector column size.

   ```postgresql
   ALTER TABLE listings ADD COLUMN listing_vector vector(1536);
   ```

1. Generate an embedding vector for each listing by calling Azure OpenAI.

   ```postgresql
   UPDATE listings
   SET listing_vector = azure_openai.create_embeddings('<deployment name serving model text-embedding-ada-002>', description)
   WHERE listing_vector IS NULL;
   ```

   Note that the active quotas may not allow updating all ~4k rows in a single call. You may run this query to generate 100 embeddings. To generate an embedding for each listing, run the query multiple times. Running it once is enough for this module.

   ```postgresql
   UPDATE listings
   SET listing_vector = azure_openai.create_embeddings('<deployment name serving model text-embedding-ada-002>', description)
   FROM (SELECT id FROM listings WHERE listing_vector IS NULL ORDER BY id LIMIT 100) subset
   WHERE listings.id = subset.id;
   ```

1. See an example vector by running this query:

   ```sql
   SELECT listing_vector FROM listings LIMIT 1;
   ```

   You will get a result like this, but with 1536 vector columns:

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

1. Use the embedding in a cosine search, fetching the top 10 most similar listings to the query.

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

1. You may also select the `description` to see which text matched. For example, this returns the best match:

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

   The result:

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

