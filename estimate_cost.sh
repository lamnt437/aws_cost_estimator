#!/bin/bash

# Function to estimate Lambda cost based on invocation count and duration
estimate_lambda_cost() {
  # Arguments passed to the function
  FUNCTION_NAME=$1
  START_TIME=$2
  END_TIME=$3
  MEMORY_GB=$4  # Memory size in GB, e.g., 0.5 for 512MB

  echo "Estimating cost for Lambda function: $FUNCTION_NAME"
  
  # Fetch the invocation count from CloudWatch
  invocations=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/Lambda \
      --metric-name Invocations \
      --dimensions Name=FunctionName,Value="$FUNCTION_NAME" \
      --start-time "$START_TIME" \
      --end-time "$END_TIME" \
      --period 86400 \
      --statistics Sum \
      --query "Datapoints[0].Sum" --output text)

  # Fetch the total duration from CloudWatch (in milliseconds)
  duration=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/Lambda \
      --metric-name Duration \
      --dimensions Name=FunctionName,Value="$FUNCTION_NAME" \
      --start-time "$START_TIME" \
      --end-time "$END_TIME" \
      --period 86400 \
      --statistics Sum \
      --query "Datapoints[0].Sum" --output text)

  # Handle the case where no data is returned (invocations or duration is null)
  if [ "$invocations" == "None" ] || [ -z "$invocations" ]; then
    invocations=0
  fi

  if [ "$duration" == "None" ] || [ -z "$duration" ]; then
    duration=0
  fi

  # Calculate costs
  request_cost=$(echo "scale=6; ($invocations / 1000000) * 0.20" | bc)
  duration_cost=$(echo "scale=6; ($duration / 1000) * $MEMORY_GB * 0.00001667" | bc)

  # Calculate the total cost
  total_cost=$(echo "scale=6; $request_cost + $duration_cost" | bc)

  # Print the results
  echo "Total Invocations: $invocations"
  echo "Total Duration (ms): $duration"
  echo "Request Cost: $request_cost USD"
  echo "Duration Cost: $duration_cost USD"
  echo "Total Estimated Cost for $FUNCTION_NAME: $total_cost USD"
  echo "----------------------------------------------------"

  # Append results to CSV file
  echo "$FUNCTION_NAME,$invocations,$duration,$request_cost,$duration_cost,$total_cost" >> lambda_costs.csv
}

# Function to get memory size in GB for a Lambda function
get_lambda_memory_gb() {
  FUNCTION_NAME=$1
  memory_mb=$(aws lambda get-function-configuration --function-name "$FUNCTION_NAME" --query "MemorySize" --output text)
  # Convert MB to GB
  MEMORY_GB=$(echo "scale=3; $memory_mb / 1024" | bc)
  echo "$MEMORY_GB"
}

# Input variables
START_TIME="2024-10-01T00:00:00Z"   # Specify the start time
END_TIME="2024-10-31T23:59:59Z"     # Specify the end time

# CSV file setup
CSV_FILE="lambda_costs.csv"
echo "FunctionName,Invocations,TotalDuration,RequestCost,DurationCost,TotalCost" > $CSV_FILE

# Fetch the list of all Lambda function names
function_list=$(aws lambda list-functions --query "Functions[*].FunctionName" --output text)

# Loop through each Lambda function and estimate the cost
for function_name in $function_list; do
  # Get memory size in GB for the function
  memory_gb=$(get_lambda_memory_gb "$function_name")

  # Estimate the cost for the Lambda function and append to CSV
  estimate_lambda_cost "$function_name" "$START_TIME" "$END_TIME" "$memory_gb"
done

echo "Cost estimation completed. Results saved to $CSV_FILE"
