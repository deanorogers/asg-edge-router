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
  for ((i=0; i<num_requests / num_threads; i++)); do
    response=$(curl -s http://nginx-alb-551814795.us-east-1.elb.amazonaws.com:8080/salutation)
    echo "Response: $response"
  done
}

# Run the function in parallel
for ((t=0; t<num_threads; t++)); do
  download &
done

# Wait for all background jobs to complete
wait
