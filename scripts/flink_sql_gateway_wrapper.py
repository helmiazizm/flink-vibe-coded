import requests
import time
import duckdb
from typing import Optional
import secrets


class Flink:
    def __init__(self, host: str = "localhost", port: int = 8083):
        self.url = f"http://{host}:{port}"
        self.session_id: Optional[str] = None
        self.db = duckdb.connect(":memory:")
        self._create_session()
    
    def _create_session(self):
        """Create a new session"""
        r = requests.post(f"{self.url}/v1/sessions", json={})
        r.raise_for_status()
        self.session_id = r.json()['sessionHandle']
    
    def _initialize_settings(self):
        """Initialize Flink settings for checkpointing and performance"""
        settings = [
            "SET 'execution.checkpointing.interval' = '3s'",
            "SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE'",
            "SET 'execution.checkpointing.timeout' = '10min'",
            "SET 'pipeline.object-reuse' = 'true'",
            "SET 'table.exec.sink.not-null-enforcer' = 'drop'"
        ]
        
        for setting in settings:
            try:
                r = requests.post(
                    f"{self.url}/v1/sessions/{self.session_id}/statements",
                    json={"statement": setting}
                )
                r.raise_for_status()
                op_handle = r.json()['operationHandle']
                
                # Wait for SET command to complete
                start = time.time()
                while time.time() - start < 10:
                    r = requests.get(
                        f"{self.url}/v1/sessions/{self.session_id}/operations/{op_handle}/status"
                    )
                    r.raise_for_status()
                    status = r.json().get('status')
                    
                    if status == 'FINISHED':
                        break
                    elif status == 'ERROR':
                        break
                    
                    time.sleep(0.5)
            except Exception:
                pass
    
    def _get_query_type(self, query: str) -> str:
        """Determine the type of SQL query"""
        cleaned = query.strip().upper()
        
        if cleaned.startswith('SELECT') or cleaned.startswith('WITH'):
            return 'select'
        elif cleaned.startswith('INSERT'):
            return 'insert'
        elif cleaned.startswith('UPDATE'):
            return 'update'
        elif cleaned.startswith('DELETE'):
            return 'delete'
        elif cleaned.startswith('MERGE'):
            return 'merge'
        else:
            return 'other'
    
    def _generate_job_name(self, query_type: str) -> str:
        """Generate a unique job name based on query type"""
        random_suffix = secrets.token_hex(8)
        return f"{query_type}_job_{random_suffix}"
    
    def _set_job_name(self, job_name: str):
        """Set the job name for the next query"""
        try:
            set_query = f"SET 'pipeline.name' = '{job_name}'"
            r = requests.post(
                f"{self.url}/v1/sessions/{self.session_id}/statements",
                json={"statement": set_query}
            )
            r.raise_for_status()
            op_handle = r.json()['operationHandle']
            
            # Wait for SET command to complete
            start = time.time()
            while time.time() - start < 10:
                r = requests.get(
                    f"{self.url}/v1/sessions/{self.session_id}/operations/{op_handle}/status"
                )
                r.raise_for_status()
                status = r.json().get('status')
                
                if status == 'FINISHED':
                    return True
                elif status == 'ERROR':
                    return False
                
                time.sleep(0.5)
        except Exception:
            return False
        return False
    
    def _get_job_id_by_name(self, job_name: str) -> Optional[str]:
        """Get job ID by querying SHOW JOBS and filtering by job name"""
        try:
            # Execute SHOW JOBS
            r = requests.post(
                f"{self.url}/v1/sessions/{self.session_id}/statements",
                json={"statement": "SHOW JOBS"}
            )
            r.raise_for_status()
            op_handle = r.json()['operationHandle']
            
            # Wait for completion
            start = time.time()
            while time.time() - start < 30:
                r = requests.get(
                    f"{self.url}/v1/sessions/{self.session_id}/operations/{op_handle}/status"
                )
                r.raise_for_status()
                status = r.json().get('status')
                
                if status == 'FINISHED':
                    break
                elif status == 'ERROR':
                    return None
                
                time.sleep(0.5)
            
            # Fetch results
            time.sleep(1)
            r = requests.get(
                f"{self.url}/v1/sessions/{self.session_id}/operations/{op_handle}/result/0",
                timeout=10
            )
            r.raise_for_status()
            result = r.json()
            
            if 'results' not in result or 'columns' not in result['results']:
                return None
            
            results_data = result['results']
            columns = [col['name'] for col in results_data['columns']]
            
            if 'data' not in results_data or not results_data['data']:
                return None
            
            # Extract rows
            rows = []
            for row_data in results_data['data']:
                if 'fields' in row_data:
                    rows.append(row_data['fields'])
            
            if not rows:
                return None
            
            # Load into temporary DuckDB table
            temp_table = f"jobs_{secrets.token_hex(4)}"
            safe_columns = [f'"{col}"' for col in columns]
            
            # Create table
            col_defs = [f"{safe_columns[i]} VARCHAR" for i in range(len(columns))]
            create_sql = f"CREATE TABLE {temp_table} ({', '.join(col_defs)})"
            self.db.execute(create_sql)
            
            # Insert data
            placeholders = ', '.join(['?' for _ in columns])
            insert_sql = f"INSERT INTO {temp_table} VALUES ({placeholders})"
            self.db.executemany(insert_sql, rows)
            
            # Find the job ID by job name
            # Column names might be different, try common variations
            query_attempts = [
                f"SELECT \"job id\" FROM {temp_table} WHERE \"job name\" = '{job_name}'",
                f"SELECT \"Job ID\" FROM {temp_table} WHERE \"Job Name\" = '{job_name}'",
                f"SELECT job_id FROM {temp_table} WHERE job_name = '{job_name}'",
            ]
            
            job_id = None
            for query in query_attempts:
                try:
                    result = self.db.execute(query).fetchone()
                    if result and result[0]:
                        job_id = result[0]
                        break
                except Exception:
                    continue
            
            # Clean up temp table
            self.db.execute(f"DROP TABLE {temp_table}")
            
            return job_id
            
        except Exception:
            return None
    
    def _stop_job_via_sql(self, job_id: str):
        """Stop a Flink job using the STOP JOB SQL statement"""
        stop_commands = [
            f"STOP JOB '{job_id}'",
            f"STOP JOB '{job_id}' WITH SAVEPOINT"
        ]
        
        for stop_query in stop_commands:
            try:
                r = requests.post(
                    f"{self.url}/v1/sessions/{self.session_id}/statements",
                    json={"statement": stop_query},
                    timeout=10
                )
                r.raise_for_status()
                op_handle = r.json()['operationHandle']
                
                # Wait for the stop command to complete
                start = time.time()
                while time.time() - start < 30:
                    r = requests.get(
                        f"{self.url}/v1/sessions/{self.session_id}/operations/{op_handle}/status",
                        timeout=10
                    )
                    r.raise_for_status()
                    status = r.json().get('status')
                    
                    if status == 'FINISHED':
                        print(f"✓ Stopped job {job_id}")
                        return True
                    elif status == 'ERROR':
                        break
                    
                    time.sleep(1)
            except Exception:
                continue
        
        return False
    
    def sql(self, query: str, timeout: int = 120, table_name: str = "result"):
        """Execute SQL on Flink and optionally load results into DuckDB"""
        query_type = self._get_query_type(query)
        is_select = query_type == 'select'
        op_handle = None
        job_name = None
        job_id = None
        
        try:
            # Initialize settings for INSERT, UPDATE, and MERGE queries
            if query_type in ['insert', 'update', 'merge']:
                self._initialize_settings()
            
            # Set a custom job name for all queries
            job_name = self._generate_job_name(query_type)
            self._set_job_name(job_name)
            
            # Submit query
            r = requests.post(
                f"{self.url}/v1/sessions/{self.session_id}/statements",
                json={"statement": query}
            )
            r.raise_for_status()
            op_handle = r.json()['operationHandle']
            
            # Wait for completion
            start = time.time()
            while time.time() - start < timeout:
                r = requests.get(
                    f"{self.url}/v1/sessions/{self.session_id}/operations/{op_handle}/status"
                )
                r.raise_for_status()
                status = r.json().get('status')
                
                if status == 'FINISHED':
                    break
                elif status == 'ERROR':
                    error = r.json().get('errorMessage', 'Unknown error')
                    print(f"✗ Query failed: {error}")
                    return
                
                time.sleep(1)
            else:
                print(f"✗ Query timeout after {timeout}s")
                return
            
            # Wait for results to be ready
            time.sleep(2)
            
            # Fetch results with retry logic
            result = None
            for attempt in range(3):
                try:
                    r = requests.get(
                        f"{self.url}/v1/sessions/{self.session_id}/operations/{op_handle}/result/0",
                        timeout=30
                    )
                    if r.status_code == 200:
                        result = r.json()
                        break
                    elif r.status_code == 500:
                        # Wait a bit longer and retry
                        time.sleep(2)
                        continue
                    else:
                        r.raise_for_status()
                except requests.exceptions.RequestException as e:
                    if attempt < 2:
                        time.sleep(2)
                        continue
                    else:
                        # If it's a non-SELECT query, this might be expected
                        if not is_select:
                            print("✓ Statement executed successfully")
                            return
                        print(f"✗ Failed to fetch results: {e}")
                        return
            
            if result is None:
                if not is_select:
                    print("✓ Statement executed successfully")
                    return
                print("✗ Failed to fetch results after retries")
                return
            
            # Check if query returned results
            if 'results' not in result or 'columns' not in result['results']:
                print("✓ Statement executed successfully")
                return
            
            results_data = result['results']
            columns = [col['name'] for col in results_data['columns']]
            
            if 'data' not in results_data or not results_data['data']:
                print(f"✓ Query returned 0 rows")
                return
            
            # Extract rows
            rows = []
            for row_data in results_data['data']:
                if 'fields' in row_data:
                    rows.append(row_data['fields'])
            
            if not rows:
                print(f"✓ Query returned 0 rows")
                return
            
            # Create DuckDB table
            self.db.execute(f"DROP TABLE IF EXISTS {table_name}")
            safe_columns = [f'"{col}"' for col in columns]
            
            # Infer types from first row
            col_types = []
            for val in rows[0]:
                if val is None:
                    col_types.append("VARCHAR")
                elif isinstance(val, bool):
                    col_types.append("BOOLEAN")
                elif isinstance(val, int):
                    col_types.append("INTEGER")
                elif isinstance(val, float):
                    col_types.append("DOUBLE")
                else:
                    col_types.append("VARCHAR")
            
            # Create table
            col_defs = [f"{safe_columns[i]} {col_types[i]}" for i in range(len(columns))]
            create_sql = f"CREATE TABLE {table_name} ({', '.join(col_defs)})"
            self.db.execute(create_sql)
            
            # Insert data
            placeholders = ', '.join(['?' for _ in columns])
            insert_sql = f"INSERT INTO {table_name} VALUES ({placeholders})"
            self.db.executemany(insert_sql, rows)
            
            print(f"✓ Loaded {len(rows)} rows into table: {table_name}")
            self.db.sql(f"SELECT * FROM {table_name}").show()
        
        finally:
            # Only stop the job if it's a SELECT query
            if is_select and job_name:
                job_id = self._get_job_id_by_name(job_name)
                if job_id:
                    self._stop_job_via_sql(job_id)
    
    def q(self, query: str):
        """Execute SQL on DuckDB"""
        try:
            self.db.sql(query).show()
        except Exception as e:
            print(f"✗ Query failed: {e}")
    
    def tables(self):
        """Show all tables"""
        self.db.sql("SHOW TABLES").show()
    
    def describe(self, table_name: str):
        """Describe table schema"""
        self.db.sql(f"DESCRIBE {table_name}").show()
    
    def close(self):
        """Close session"""
        if self.session_id:
            requests.delete(f"{self.url}/v1/sessions/{self.session_id}")
        self.db.close()


# Global instance
_flink: Optional[Flink] = None


def sql(query: str, timeout: int = 120, table: str = "result"):
    """Execute SQL on Flink and load results into DuckDB table"""
    global _flink
    if _flink is None:
        _flink = Flink()
    _flink.sql(query, timeout, table)


def q(query: str):
    """Execute SQL on DuckDB"""
    global _flink
    if _flink is None:
        _flink = Flink()
    _flink.q(query)


def tables():
    """Show all DuckDB tables"""
    global _flink
    if _flink is None:
        _flink = Flink()
    _flink.tables()


def describe(table: str):
    """Describe table schema"""
    global _flink
    if _flink is None:
        _flink = Flink()
    _flink.describe(table)


def connect(host: str = "localhost", port: int = 8083):
    """Connect to Flink SQL Gateway"""
    global _flink
    if _flink:
        _flink.close()
    _flink = Flink(host, port)
    print(f"✓ Connected to SQL Gateway at {host}:{port}")


def close():
    """Close connection"""
    global _flink
    if _flink:
        _flink.close()
        _flink = None