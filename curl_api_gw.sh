#!/bin/bash

# Usage: ./multi_curl.sh <total_requests> <num_threads>

start=$(gdate +%s.%3N)

TOTAL_REQUESTS=$1
NUM_THREADS=$2
URL="https://bfj0w0fxc2.execute-api.us-east-1.amazonaws.com/dev/salutation"

# Basic validation
if ! [[ "$TOTAL_REQUESTS" =~ ^[0-9]+$ ]] || ! [[ "$NUM_THREADS" =~ ^[0-9]+$ ]] || [ "$TOTAL_REQUESTS" -le 0 ] || [ "$NUM_THREADS" -le 0 ]; then
  echo "Usage: $0 <total_requests> <num_threads>"
  exit 1
fi

# Calculate how many requests per thread (some threads may do one more)
REQS_PER_THREAD=$(( TOTAL_REQUESTS / NUM_THREADS ))
EXTRA_REQUESTS=$(( TOTAL_REQUESTS % NUM_THREADS ))

function make_requests() {
  local count=$1
  for ((i=0; i<count; i++)); do
    response=$(curl -s "$URL")
    echo "Response: $response"
  done
} 

# Launch threads
for ((t=0; t<NUM_THREADS; t++)); do
  count=$REQS_PER_THREAD
  if [ $t -lt $EXTRA_REQUESTS ]; then
    count=$((count + 1))
  fi
  make_requests $count &
done

# Wait for all threads to finish
wait
end=$(gdate +%s.%3N)
diff=$(echo "$end - $start" | bc)
echo "Elapsed time: ${diff} seconds"
