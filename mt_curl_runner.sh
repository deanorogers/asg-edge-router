#!/bin/bash

# Validate input (ensure both are positive integers)
if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -le 0 ] || ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -le 0 ]; then
  echo "Usage: $0 <number_of_requests> <number_of_threads>"
  exit 1
fi

num_requests=$1
num_threads=$2

# Function to run curl in parallel
download() {
  local thread_id=$1
    for ((i = 0; i < num_requests / num_threads; i++)); do
      tmpfile=$(mktemp "/tmp/response_${thread_id}_${i}_XXXXXX")

      response=$(curl -s -w "%{time_total}" -o "$tmpfile" http://nginx-alb-1986895030.us-east-1.elb.amazonaws.com:8080/salutation)
      time_taken="$response"
      body=$(< "$tmpfile")
      rm -f "$tmpfile"
      echo "Thread $thread_id | Time: ${time_taken}s | Response: $body"
      sleep 0.5
      #      sleep_time=$(echo "scale=3; $RANDOM/32767" | bc)
      #      echo "Sleep time ${sleep_time}"
      #      sleep "$sleep_time"    sleep "$sleep_time"
    done
}

# Run the function in parallel
for ((t = 0; t < num_threads; t++)); do
  download "$t" &
done

# Wait for all background jobs to complete
wait
