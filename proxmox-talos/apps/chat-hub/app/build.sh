#!/bin/bash

# Build and push script for chat-hub
# Usage: ./build.sh [registry/image:tag]

IMAGE=${1:-"ghcr.io/fafiorim/chat-hub:latest"}

echo "Building chat-hub image: $IMAGE"

# Build the image
docker build -t "$IMAGE" .

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo ""
    echo "To push to registry, run:"
    echo "  docker push $IMAGE"
    echo ""
    echo "Then update the Kubernetes deployment to use: $IMAGE"
else
    echo "Build failed!"
    exit 1
fi
