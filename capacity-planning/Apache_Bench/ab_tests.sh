#!/bin/bash

# ==========================
# ANB Rising Stars - AB Tests
# ==========================
# This script runs load tests using Apache Bench (ab)
# against the public API endpoint and extracts key metrics.
#
# Metrics:
#   - Throughput (Requests/min)
#   - Response Time (Average in ms)
#   - Utilization (CPU/Mem/I/O: must be monitored separately with docker stats or APM)
#
# Results are stored in ./capacity-planning/Apache_Bench/results/
# and summarized in ./capacity-planning/Apache_Bench/summary.csv

URL="http://localhost:8080/api/public/videos"
TOTAL_REQUESTS=500   # total requests per test
RESULTS_DIR="./capacity-planning/Apache_Bench/results"
SUMMARY_FILE="$RESULTS_DIR/summary.csv"

# Create results directory
mkdir -p $RESULTS_DIR

# Write CSV header
echo "Concurrency,Throughput(req/min),AvgResponseTime(ms)" > $SUMMARY_FILE

echo "Starting load tests with Apache Bench"
echo "Target endpoint: $URL"
echo "Results will be saved in: $RESULTS_DIR"
echo "Summary will be saved in: $SUMMARY_FILE"
echo

# Concurrency levels to test
for c in 10 50 100 200 500
do
  echo "Running test with $c concurrent users..."
  RESULT_FILE="$RESULTS_DIR/ab_c${c}.txt"

  # Run ab and capture output
  ab -n $TOTAL_REQUESTS -c $c $URL > "$RESULT_FILE"

  # Extract throughput (req/sec) and convert to req/min
  THROUGHPUT=$(grep "Requests per second" "$RESULT_FILE" | awk '{print $4}')
  THROUGHPUT_MIN=$(echo "$THROUGHPUT * 60" | bc)

  # Extract mean response time (ms)
  RESP_TIME=$(grep "Time per request:" "$RESULT_FILE" | head -n 1 | awk '{print $4}')

  # Append to summary CSV
  echo "$c,$THROUGHPUT_MIN,$RESP_TIME" >> $SUMMARY_FILE

  echo "   Result saved to $RESULT_FILE"
  echo "   Metrics -> Throughput: ${THROUGHPUT_MIN} req/min | Avg Response Time: ${RESP_TIME} ms"
done

echo
echo "All tests completed."
echo "Summary available at $SUMMARY_FILE"
echo
echo "Note: Resource Utilization (CPU, Memory, I/O) must be monitored in parallel using:"
echo "docker stats"
echo "or an external APM tool."