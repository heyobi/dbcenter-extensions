#!/bin/bash
mkdir -p packages

echo "--- Building Docker Image (NO CACHE) ---"
# --no-cache parametresi eklendi
docker build -t pgvector-builder .

echo "--- Running Builder ---"
docker run --rm \
  --platform linux/amd64 \
  -v $(pwd)/packages:/packages \
  pgvector-builder

echo "--- DONE ---"
ls -lh packages