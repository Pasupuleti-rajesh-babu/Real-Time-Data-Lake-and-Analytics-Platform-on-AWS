#!/bin/bash

# Create a temporary directory
mkdir -p temp

# Copy the Lambda function
cp kinesis_ingest.py temp/

# Install dependencies
pip install boto3 -t temp/

# Create ZIP file
cd temp
zip -r ../kinesis_ingest.zip .
cd ..

# Clean up
rm -rf temp 