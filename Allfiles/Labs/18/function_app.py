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
                     SELECT azure_openai.create_embeddings('embedding', %s, max_attempts => 5, retry_delay_ms => 500)::vector AS emb
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
