Recall that the listings company wants to analyze market trends, like most popular phrases or places. The team also wants to enhance protections for personally identifiable information (PII). The current data is stored in an Azure Database for PostgreSQL flexible server. The project budget is small, so it's important to minimize upfront costs, as well as ongoing costs maintaining keywords and tags. The developers are wary of how many forms PII can take, and prefer a cost-effective, vetted solution over an in-house regular expression matcher.

DIAGRAM:

- Listings sample documents
- Azure AI Language API
- Insights extracted from documents via API: key phrases, entities, PII
- Store back into DB columns

Here, you'll integrate the database with Azure AI Language services using the `azure_ai` extension. The extension provides user-defined SQL function APIs to several Azure Cognitive Service APIs including:

- key phrase extraction
- entity recognition
- PII recognition

This will allow the data science team to quickly join against listing popularity data to determine market trends. It will also give application developers a PII-safe text to present in situations that don't require accessing it. Storing identified entities enables human review in case of inquiry, or false positive PII recognition (thinking something is PII that isn't).

By the end, you'll have four new columns in the `listings` table with extracted insights:

* `key_phrases`
* `recognized_entities`
* `pii_safe_description`
* `pii_entities`

## Prerequisites & setup

1. An Azure subscription - [Create one for free](https://azure.microsoft.com/free/cognitive-services?azure-portal=true).
2. A [Language resource](https://portal.azure.com/#create/Microsoft.CognitiveServicesTextAnalytics) in the Azure portal. Once you have a Language resource, go to **Resource Management > Keys and Endpoint** to get your key and endpoint for Azure Cognitive Services.
3. An Azure Database for PostgreSQL Flexible Server instance in your Azure subscription. If you do not have a resource, use either the [Azure portal](https://learn.microsoft.com/azure/postgresql/flexible-server/quickstart-create-server-portal) or the [Azure CLI](https://learn.microsoft.com/azure/postgresql/flexible-server/quickstart-create-server-cli) guide for creating one.

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

## Setup: configure extension

To use the Azure AI Language services, you need to allow-list and enable an extensions for Azure Database for PostgreSQL Flexible Server.

1. Add `azure_ai` to the server parameter `azure.extensions`, following these [instructions](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-extensions#how-to-use-postgresql-extensions).

2. Enable the `azure_ai` extension. You'll need the endpoint and API key for the Azure OpenAI resource. For detailed instructions, see: [Enable the `azure_ai` extension](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/generative-ai-azure-overview#enable-the-azure_ai-extension).

   ```postgresql
   CREATE EXTENSION azure_ai;
   select azure_ai.set_setting('azure_cognitive.endpoint','https://<endpoint>.cognitiveservices.azure.com');
   select azure_ai.set_setting('azure_cognitive.subscription_key', '<API Key>');
   -- the region setting is only required for the translate function
   select azure_ai.set_setting('azure_cognitive.region', '<API Key>');
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

## Extract key phrases

1. The key phrases are extracted as `text[]` as revealed by the `pg_typeof` function:

   ```postgresql
   SELECT pg_typeof(azure_cognitive.extract_key_phrases('The food was delicious and the staff were wonderful.', 'en-us'));
   ```

   Create a column to contain the key results.

   ```postgresql
   ALTER TABLE listings ADD COLUMN key_phrases text[];
   ```

1. Populate the column in batches. You may wish to adjust the `LIMIT` value depending on quota. Feel free to run the command as many times as you like; you don't need all rows populated for this exercise.

   ```postgresql
   UPDATE listings
   SET key_phrases = azure_cognitive.extract_key_phrases(description)
   FROM (SELECT id FROM listings WHERE key_phrases IS NULL ORDER BY id LIMIT 100) subset
   WHERE listings.id = subset.id;
   ```

1. Query listings by key phrases:

   ```postgresql
   SELECT id, name FROM listings WHERE 'market' = ANY(key_phrases);
   ```

   You will get results like this, depending on which listings have key phrases populated:

   ```
      id    |                name                 
   ---------+-------------------------------------
     931154 | Met Tower in Belltown! MT2
     931758 | Hottest Downtown Address, Pool! MT2
    1084046 | Near Pike Place & Space Needle! MT2
    1084084 | The Best of the Best, Seattle! MT2
   ```

## Named entity recognition

1. The entities are extracted as `azure_cognitive.entity[]` as revealed by the `pg_typeof` function:

   ```postgresql
   select pg_typeof(azure_cognitive.recognize_entities('For more information, see Cognitive Services Compliance and Privacy notes.', 'en-us'));
   ```

   Create a column to contain the key results.

   ```postgresql
   ALTER TABLE listings ADD COLUMN entities azure_cognitive.entity[];
   ```

2. Populate the column in batches. This may take several minutes. You may wish to adjust the `LIMIT` value depending on quota or to return more quickly with partial results. Feel free to run the command as many times as you like; you don't need all rows populated for this exercise.

   ```postgresql
   UPDATE listings
   SET entities = azure_cognitive.recognize_entities(description, 'en-us')
   FROM (SELECT id FROM listings WHERE entities IS NULL ORDER BY id LIMIT 500) subset
   WHERE listings.id = subset.id;
   ```

3. You may now query all listings' entities to find properties with decks:

   ```postgresql
   SELECT id, name
   FROM   listings, unnest(entities) e
   WHERE  e.text LIKE '%roof%deck%'
   LIMIT  10;
   ```

   which returns something like this:

   ```
      id    |                name                 
   ---------+-------------------------------------
     430610 | 3br/3ba.  modern, roof deck, garage
     430610 | 3br/3ba.  modern, roof deck, garage
    1214306 | Private Bed/bath in Home: green (A)
      74328 | Spacious Designer Condo
     938785 | Best Ocean Views By Pike Place! PA1
      23430 | 1 Bedroom Modern Water View Condo
     828298 | 2 Bedroom Sparkling City Oasis
     338043 | large modern unit & fab location
     872152 | Luxurious Local Lifestyle 2Bd/2+Bth
     116221 | Modern, Light-Filled Fremont Flat
   (10 rows)
   ```

## PII Recognition

1. The entities are extracted as `azure_cognitive.pii_entity_recognition_result` as revealed by the `pg_typeof` function:

   ```postgresql
   select pg_typeof(azure_cognitive.recognize_pii_entities('For more information, see Cognitive Services Compliance and Privacy notes.', 'en-us'));
   ```

   This is a composite type containing redacted text and an array of PII entities, as verified by:

   ```
   \d azure_cognitive.pii_entity_recognition_result
   ```

   which prints:

   ```
         Composite type "azure_cognitive.pii_entity_recognition_result"
       Column     |           Type           | Collation | Nullable | Default 
   ---------------+--------------------------+-----------+----------+---------
    redacted_text | text                     |           |          | 
    entities      | azure_cognitive.entity[] |           |          | 
   ```

   

   Create a column to contain the redacted text, and another for the recognized entities:

   ```postgresql
   ALTER TABLE listings ADD COLUMN description_pii_safe text;
   ALTER TABLE listings ADD COLUMN pii_entities azure_cognitive.entity[];
   ```

2. Populate the column in batches. This may take several minutes. You may wish to adjust the `LIMIT` value depending on quota or to return more quickly with partial results. Feel free to run the command as many times as you like; you don't need all rows populated for this exercise.

   ```postgresql
   UPDATE listings
   SET
     description_pii_safe = pii.redacted_text,
     pii_entities = pii.entities
   FROM (SELECT id, description FROM listings WHERE description_pii_safe IS NULL OR pii_entities IS NULL ORDER BY id LIMIT 100) subset,
   LATERAL azure_cognitive.recognize_pii_entities(subset.description, 'en-us') as pii
   WHERE listings.id = subset.id;
   ```

3. You may now display listing descriptions with any potential PII redacted:

   ```postgresql
   SELECT description_pii_safe
   FROM listings
   WHERE description_pii_safe IS NOT NULL
   LIMIT 1;
   ```

   which displays:

   ```
    A lovely stone-tiled room with kitchenette. New full mattress futon bed. Fridge, microwave, kettle for coffee and tea. Separate entrance into book-lined mudroom. Large bathroom with Jacuzzi  (shared occasionally with ***** to do laundry). Stone-tiled, radiant heated floor, 300 sq ft room with 3 large windows. The bed is queen-sized futon and has a full-sized mattress with topper. Bedside tables and reading lights on both sides. Also large leather couch with cushions. Kitchenette is off the side wing of the main room and  has a microwave, and fridge, and an electric kettle for making coffee or tea. Kitchen table with two chairs to use for meals or as desk. Extra high-speed WiFi is also provided. Access to English Garden. The Ballard Neighborhood is a great place to visit: *10 minute walk to downtown Ballard with fabulous bars and restaurants, great ****** farmers market, nice three-screen cinema, and much more. *5 minute walk to the Ballard Locks, where ships enter and exit Puget Sound 
   (1 row)
   ```

   

4. You may also identify the entities recognized in PII; for example the same listing as above:

   ```postgresql
   SELECT entities
   FROM listings
   WHERE entities IS NOT NULL
   LIMIT 1;
   ```

   which displays:

   ```
                           pii_entities                         
   -------------------------------------------------------------
    {"(hosts,PersonType,\"\",0.93)","(Sunday,DateTime,Date,1)"}
   (1 row)
   ```

## Check your work

Let's make sure we were able to populate extracted key phrases, recognized entities, and PII.

1. Check key phrases:

   ```postgresql
   SELECT COUNT(*) FROM listings WHERE key_phrases IS NOT NULL;
   ```

   You should see something like this, depending how many batches you ran:

   ```
    count 
   -------
      100
   (1 row)
   ```

   

1. Check recognized entities:

   ```postgresql
   SELECT COUNT(*) FROM listings WHERE entities IS NOT NULL;
   ```

   You should see something like:

   ```
    count 
   -------
      500
   (1 row)
   ```

1. Check redacted PII:

   ```postgresql
   SELECT COUNT(*) FROM listings WHERE description_pii_safe IS NOT NULL;
   ```

   If you loaded a single batch of 100, you should see:

   ```
    count 
   -------
      100
   (1 row)
   ```

   You can check how many listings had PII detected:

   ```postgresql
   SELECT COUNT(*) FROM listings WHERE description != description_pii_safe;
   ```

   You should see something like:

   ```
    count 
   -------
       87
   (1 row)
   ```

1. Check detected PII entities: per the above, we should have 13 without an empty PII array.

  ```postgresql
SELECT COUNT(*) FROM listings WHERE pii_entities IS NULL AND description_pii_safe IS NOT NULL;
  ```

  Result:

  ```
 count 
-------
    13
(1 row)
  ```

  