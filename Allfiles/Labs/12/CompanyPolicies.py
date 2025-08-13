import csv, os
from contextlib import contextmanager

# Third-party libs
from dotenv import load_dotenv
import psycopg2
from psycopg2.extras import execute_batch
from langchain_openai import AzureChatOpenAI

load_dotenv()

# Create a short-lived PostgreSQL connection
@contextmanager
def get_conn():
    conn = psycopg2.connect(
        host=os.getenv("PGHOST"),
        user=os.getenv("PGUSER"),
        password=os.getenv("PGPASSWORD"),
        dbname=os.getenv("PGDATABASE"),
        connect_timeout=10,
    )
    try:
        yield conn
    finally:
        conn.close()

# Load CSV rows and create embeddings in the database
def load_csv_and_embed(csv_path, batch_size=100):
    sql = """
    INSERT INTO company_policies (title, department, policy_text, embedding)
    VALUES (%s, %s, %s, azure_openai.create_embeddings(%s, %s)::vector)
    """
    emb_depl = os.getenv("OPENAI_EMBED_DEPLOYMENT")
    rows = []
    with open(csv_path, newline='', encoding="utf-8") as f:
        reader = csv.DictReader(f)  # Expected headers: title, department, policy_text
        for r in reader:
            rows.append((r["title"], r["department"], r["policy_text"], emb_depl, r["policy_text"]))
    with get_conn() as conn, conn.cursor() as cur:
        for i in range(0, len(rows), batch_size):
            execute_batch(cur, sql, rows[i:i+batch_size], page_size=batch_size)
        conn.commit()

# Retrieve top-k rows by cosine similarity
def retrieve_chunks(question, top_k=5):
    sql = """
    WITH q AS (SELECT azure_openai.create_embeddings(%s, %s)::vector AS qvec)
    SELECT id, title, policy_text
    FROM company_policies, q
    ORDER BY embedding <=> q.qvec
    LIMIT %s;
    """
    params = (os.getenv("OPENAI_EMBED_DEPLOYMENT"), question, top_k)
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
    return [{"id": r[0], "title": r[1], "text": r[2]} for r in rows]

# Format retrieved chunks for the model prompt
def format_context(chunks):
    return "\n\n".join([f"[{c['title']}] {c['text']}" for c in chunks])

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
        {"role": "system", "content": "You are a helpful assistant. Answer ONLY from the provided context. If it isn't in the context, say you don’t have enough information. Cite policy titles in square brackets, e.g., [Vacation policy]."},
        {"role": "user", "content": f"Question: {question}\nContext:\n{format_context(chunks)}"},
    ]
    return llm.invoke(messages).content

if __name__ == "__main__":
    # Load CSV and generate embeddings
    load_csv_and_embed("company_policies.csv")
    print("Loaded CSV and generated embeddings.")

    # Prompt the learner for a question
    q = input("Enter your question (or press Enter to use a sample): ").strip() \
        or "How many vacation days do employees get?"

    # Retrieve chunks and generate a grounded answer
    chunks = retrieve_chunks(q, top_k=5)
    if not chunks:
        print("No relevant content found.")
    else:
        answer = generate_answer(q, chunks)
        print("\n--- Answer ---\n", answer)
