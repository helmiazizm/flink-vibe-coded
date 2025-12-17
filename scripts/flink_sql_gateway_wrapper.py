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
    
    def _get_query_type(self, query: str) -> str:
        """Determine the type of SQL query"""
        cleaned = query.strip().upper()
        
        if cleaned.startswith('SELECT') or cleaned.startswith('WITH'):
            return 'select'
        elif cleaned.startswith('INSERT'):
            return 'insert'
        elif cleaned.startswith('CREATE TABLE'):
            return 'create_table'
        elif cleaned.startswith('UPDATE'):
            return 'update'
        elif cleaned.startswith('DELETE'):
            return 'delete'
        elif cleaned.startswith('MERGE'):
            return 'merge'
        else:
            return 'other'
    
    def _get_job_id_from_operation(self, op_handle: str) -> Optional[str]:
        """Get job ID from operation handle by checking the operation info"""
        try:
            # Try to get job info from operation
            r = requests.get(
                f"{self.url}/v1/sessions/{self.session_id}/operations/{op_handle}/info"
            )
            if r.status_code == 200:
                info = r.json()
                if 'jobId' in info:
                    return info['jobId']
            
            # Fallback: Get from SHOW JOBS and match by recent timing
            r = requests.post(
                f"{self.url}/v1/sessions/{self.session_id}/statements",
                json={"statement": "SHOW JOBS"}
            )
            r.raise_for_status()
            jobs_op_handle = r.json()['operationHandle']
            
            start = time.time()
            while time.time() - start < 10:
                r = requests.get(
                    f"{self.url}/v1/sessions/{self.session_id}/operations/{jobs_op_handle}/status"
                )
                r.raise_for_status()
                status = r.json().get('status')
                
                if status == 'FINISHED':
                    break
                elif status == 'ERROR':
                    return None
                
                time.sleep(0.5)
            
            time.sleep(0.5)
            r = requests.get(
                f"{self.url}/v1/sessions/{self.session_id}/operations/{jobs_op_handle}/result/0",
                timeout=10
            )
            r.raise_for_status()
            result = r.json()
            
            if 'results' not in result or 'columns' not in result['results']:
                return None
            
            results_data = result['results']
            if 'data' not in results_data or not results_data['data']:
                return None
            
            # Get the most recent RUNNING job (likely the one we just created)
            rows = results_data['data']
            if rows:
                # Return the first job's ID (most recent)
                first_row = rows[0]
                if 'fields' in first_row and first_row['fields']:
                    return first_row['fields'][0]  # First column is usually job id
            
            return None
            
        except Exception:
            return None
    
    def sql(self, query: str, timeout: int = 300, table_name: str = "result"):
        """
        Execute SQL on Flink and optionally load results into DuckDB.
        
        - SELECT queries are BLOCKED (use batch tables via JDBC connector instead)
        - INSERT queries start streaming jobs (user must stop manually)
        - Other queries execute normally
        """
        query_type = self._get_query_type(query)
        is_select = query_type == 'select'
        is_create_table = query_type == 'create_table'
        is_insert = query_type == 'insert'
        op_handle = None
        
        # Block ALL SELECT queries
        if is_select:
            print("✗ Error: SELECT queries are blocked in this wrapper")
            print("  Reason: SELECT on streaming sources creates jobs that are hard to manage")
            print("  Solution:")
            print("    1. Use INSERT INTO to write streaming data to a sink (Paimon/JDBC)")
            print("    2. Create batch tables using JDBC connector")
            print("    3. Query batch tables with native Flink SQL Client")
            return
        
        try:            
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
            
            # For INSERT INTO streaming jobs, get job ID and warn user
            if is_insert:
                job_id = self._get_job_id_from_operation(op_handle)
                print(f"✓ Streaming INSERT job started successfully")
                if job_id:
                    print(f"  Job ID: {job_id}")
                    print(f"  ⚠ WARNING: This job will run continuously!")
                    print(f"  To stop it, run: sql(\"STOP JOB '{job_id}'\")")
                else:
                    print(f"  ⚠ WARNING: This job will run continuously!")
                    print(f"  To stop it, run SHOW JOBS to get the Job ID, then: sql(\"STOP JOB '<job-id>'\")")
                return
            
            # For CREATE TABLE, no results to fetch
            if is_create_table:
                print("✓ Table created successfully")
                return
            
            # For other non-SELECT queries
            print("✓ Statement executed successfully")
        
        except Exception as e:
            print(f"✗ Error executing query: {e}")
    
    def q(self, query: str):
        """Execute SQL on DuckDB"""
        try:
            self.db.sql(query).show()
        except Exception as e:
            print(f"✗ Query failed: {e}")
    
    def tables(self):
        """Show all DuckDB tables"""
        self.db.sql("SHOW TABLES").show()
    
    def describe(self, table_name: str):
        """Describe table schema"""
        self.db.sql(f"DESCRIBE {table_name}").show()
    
    def close(self):
        """Close session"""
        if self.session_id:
            try:
                requests.delete(f"{self.url}/v1/sessions/{self.session_id}")
            except:
                pass
        self.db.close()


# Global instance
_flink: Optional[Flink] = None


def sql(query: str, timeout: int = 300, table: str = "result"):
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