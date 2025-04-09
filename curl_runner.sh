#!/bin/bash


# Validate input (ensure it's a positive integer)
if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -le 0 ]; then
  echo "Please enter a valid positive integer."
  exit 1
fi

# Run curl command the specified number of times
for ((i=1; i<=$1; i++)); do
  #echo "Request #$i:"
  response=$(curl -s http://nginx-alb-782537157.us-east-1.elb.amazonaws.com:8080/salutation)  # Capture response
  echo "Response: $response"
done

