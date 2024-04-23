Let's build a recommendation system using semantic search. The system will recommend a number of listings based on a provided sample listing. The sample could be from the listing the user is currently viewing, or their preferences. We'll implement the system as a PostgreSQL function leveraging the `azure_openai` extension.

DIAGRAM:

- Sample data CSV --> database table in a flexible server
- description column from the sample --> OpenAI API & back into vector column
- function receiving query text + result count, performing `<=>` search using OpenAI embeddings
- arrow from function to return rows with dashed arrow into "app, report, etc"

By the end of this exercise, you'll have defined a function `recommend_listing` that provides at most `numResults` listings most similar to the supplied `sampleListingId`. You can use this data to drive new opportunities, such as joining recommended listings against discounted listings.

## Prequisites & setup

This unit assumes you have completed the steps in the previous exercise: generate vector embeddings.

## Create the recommendation function

The recommendation function takes a `sampleListingId`, and returns the `numResults` most similar other listings. To do so, it creates an embedding of the sample listing's name and description, then runs semantic search of that query vector against the listing embeddings.

```postgresql
CREATE FUNCTION
    recommend_listing(sampleListingId int, numResults int) 
RETURNS TABLE(
            out_listingName text,
            out_listingDescription text,
            out_score real)
AS $$  
DECLARE
    queryEmbedding vector(1536); 
    sampleListingText text; 
BEGIN 
    sampleListingText := (
      SELECT
        name || ' ' || description
      FROM
        listings WHERE id = sampleListingId
    ); 

    queryEmbedding := (
      azure_openai.create_embeddings('embedding', sampleListingText, max_attempts => 5, retry_delay_ms => 500)
    );

    RETURN QUERY  
    SELECT
        name::text,
        description,
        -- cosine distance:
        (listings.listing_vector <=> queryEmbedding)::real AS score
    FROM
        listings  
    ORDER BY score ASC LIMIT numResults;
END $$
LANGUAGE plpgsql; 
```

See the [Recommendation System](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/generative-ai-recommendation-system) example for more ways to customize this function, for example combining several text columns into an embedding vector.

## Query the recommendation function

To query the recommendation function, pass it a listing ID and number of recommendations to make.

```postgresql
select out_listingName, out_score from recommend_listing( (SELECT id from listings limit 1), 20); -- search for 20 listing recommendations closest to a listing
```

The result will be something like:

```
           out_listingname           |  out_score  
-------------------------------------+-------------
 Sweet Seattle Urban Homestead 2 Bdr | 0.012512862
 Lovely Cap Hill Studio has it all!  |  0.09572035
 Metrobilly Retreat                  |   0.0982959
 Cozy Seattle Apartment Near UW      |  0.10320047
 Sweet home in the heart of Fremont  |  0.10442386
 Urban Chic, West Seattle Apartment  |  0.10654513
 Private studio apartment with deck  | 0.107096426
 Light and airy, steps to the Lake.  |  0.11008232
 Backyard Studio Apartment near UW   | 0.111279964
 2bed Rm Inner City Suite Near Dwtn  | 0.111340374
 West Seattle Vacation Junction      | 0.111758955
 Green Lake Private Ground Floor BR  | 0.112196356
 Stylish Queen Anne Apartment        |  0.11250153
 Family Friendly Modern Seattle Home |  0.11257711
 Bright Cheery Room in Seattle House |  0.11290849
 Big sunny central house with view!  |  0.11382967
 Modern, Light-Filled Fremont Flat   | 0.114443965
 Chill Central District 2BR          |   0.1153879
 Sunny Bedroom w/View: Wallingford   |  0.11549795
 Seattle Turret House (Apt 4)        |  0.11590502
(20 rows)
```

## Check your work

1. Make sure the function exists with the correct signature:

   ```postgresql
   \df recommend_listing
   ```

   You should see the following:

   ```
    public | recommend_listing | TABLE(out_listingname text, out_listingdescription text, out_score real) | samplelistingid integer, numre
   sults integer | func
   ```

2. Make sure you can query it. This should return results:

   ```postgresql
   select out_listingName, out_score from recommend_listing( (SELECT id from listings limit 1), 20); -- search for 20 listing recommendations closest to a listing
   ```

