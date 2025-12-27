#!/bin/bash

echo "=========================================="
echo "Testing CDC Gateway"
echo "=========================================="

# Test 1: Health Check
echo -e "\n[1] Testing health endpoint..."
HEALTH=$(curl -s http://localhost:5001/health)
if echo "$HEALTH" | grep -q "healthy"; then
    echo "✓ Health check passed"
else
    echo "✗ Health check failed"
fi

# Test 2: List Jobs
echo -e "\n[2] Listing jobs..."
JOBS=$(curl -s http://localhost:5001/jobs)
echo "$JOBS" | python3 -m json.tool

# Test 3: Submit a job
echo -e "\n[3] Submitting a sample CDC job..."
RESULT=$(curl -s -X POST http://localhost:5001/submit -F "file=@flink-jobs/sample-cdc.yaml")
echo "$RESULT" | python3 -m json.tool

# Test 4: Verify file in shared volume
echo -e "\n[4] Checking shared volume..."
docker exec jobmanager ls -lh /shared/cdc-yaml/

echo -e "\n=========================================="
echo "Test complete!"
echo "=========================================="
