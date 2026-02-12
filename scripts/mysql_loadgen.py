import mysql.connector
import random
import time

# MySQL server connection parameters
db_config = {
    "host": "localhost",
    "user": "",
    "password": "",
    "database": "loadgen"
}

# Number of queries to execute
num_queries = 10000

# List of example SQL queries
sql_queries = [
    "INSERT INTO users (username, email) VALUES ('user3', 'user3@example.com')",
    "UPDATE users SET username = 'user3a' WHERE email = 'user3@example.com'",
    "DELETE FROM users WHERE username = 'user3a'"
]

# Create a MySQL connection
conn = mysql.connector.connect(**db_config)

# Function to execute queries sequentially
def execute_next_query(query_index):
    if query_index < len(sql_queries):
        query = sql_queries[query_index]
        cursor = conn.cursor()
        cursor.execute(query)
        conn.commit()
        print(f"Query {query_index + 1} executed.")
        return query_index + 1
    else:
        return query_index

# Generate load by executing queries in order
try:
    for i in range(num_queries):
        current_query_index = 0
        while current_query_index < len(sql_queries):
            current_query_index = execute_next_query(current_query_index)
            # time.sleep(0.1)  # Add a fixed delay between queries
            time.sleep(random.uniform(1, 5))  # Add some random delay
except Exception as e:
    print(f"Error: {e}")
finally:
    conn.close()
    print("Load generation complete.")
