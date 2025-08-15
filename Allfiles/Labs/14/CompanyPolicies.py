import os
from contextlib import contextmanager
from dotenv import load_dotenv
import psycopg2
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

# Retrieve top-k rows by cosine similarity (embedding must be present)



# Format retrieved chunks for the model prompt



# Call Azure OpenAI to answer using the provided context



# Main: prompt, retrieve, answer, loop on demand
if __name__ == "__main__":
    while True:
        q = input("Enter your question (or press Enter to use a sample): ").strip() \
            or "How many vacation days do employees get?"

        chunks = retrieve_chunks(q, top_k=5)
        if not chunks:
            print("\nNo relevant content found.")
        else:
            answer = generate_answer(q, chunks)
            print("\n--- Answer ---\n", answer)

        again = input("\nAsk another question? [y/N]: ").strip().lower()
        if again in ("y", "yes"):
            os.system("cls" if os.name == "nt" else "clear")
            continue
        else:
            print("Goodbye!")
            break
