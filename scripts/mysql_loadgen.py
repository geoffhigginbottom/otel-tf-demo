# import mysql.connector
# import random
# import time

import mysql.connector
from mysql.connector import pooling
import random
import time
import threading

# MySQL server connection parameters
db_config = {
    "host": "localhost",
    "user": "",
    "password": "",
    "database": "loadgen"
}

NUM_THREADS = 5
QUERIES_PER_THREAD = 2000
SLOW_QUERY_PROBABILITY = 0.1  # 10% of queries will be slow

# Connection pool
pool = pooling.MySQLConnectionPool(
    pool_name="mypool",
    pool_size=NUM_THREADS,
    **db_config
)

def generate_user():
    user_id = random.randint(1, 1000000)
    username = f"user{user_id}"
    email = f"user{user_id}@example.com"
    return username, email

def worker(thread_id):
    conn = pool.get_connection()
    cursor = conn.cursor(buffered=True)

    for i in range(QUERIES_PER_THREAD):
        username, email = generate_user()

        # Decide if this will be a slow query
        if random.random() < SLOW_QUERY_PROBABILITY:
            query = "SELECT SLEEP(3)"
            params = ()
            query_type = "SLOW"
        else:
            queries = [
                ("INSERT INTO users (username, email) VALUES (%s, %s)", (username, email), "INSERT"),
                ("UPDATE users SET username = %s WHERE email = %s", (username + "a", email), "UPDATE"),
                ("DELETE FROM users WHERE email = %s", (email,), "DELETE"),
                ("SELECT * FROM users WHERE email = %s", (email,), "SELECT"),
            ]

            query, params, query_type = random.choice(queries)

        try:
            cursor.execute(query, params)

            # Only commit for writes
            if query_type in ["INSERT", "UPDATE", "DELETE"]:
                conn.commit()

            print(f"[Thread {thread_id}] {query_type}")

        except Exception as e:
            print(f"[Thread {thread_id}] Error: {e}")

        # Small jitter between queries
        time.sleep(random.uniform(0.05, 0.3))

    cursor.close()
    conn.close()
    print(f"[Thread {thread_id}] Finished")

# Start threads
threads = []

for i in range(NUM_THREADS):
    t = threading.Thread(target=worker, args=(i,))
    t.start()
    threads.append(t)

# Wait for all threads
for t in threads:
    t.join()

print("Load generation complete.")