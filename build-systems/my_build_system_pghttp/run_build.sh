#!/bin/bash
mkdir -p packages

echo "--- Building Docker Image (pg_http env) ---"
docker build -t pghttp-builder .

echo "--- Running Builder ---"
docker run --rm \
  --platform linux/amd64 \
  -v $(pwd)/packages:/packages \
  pghttp-builder

echo "--- DONE ---"
ls -lh packages