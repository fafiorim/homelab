#!/bin/bash

# Ollama Status Monitor
# Check the status of Ollama service and loaded models

OLLAMA_URL="${1:-http://10.10.21.6:11434}"

echo "================================================"
echo "Ollama Status Monitor"
echo "================================================"
echo "Endpoint: $OLLAMA_URL"
echo "Time: $(date)"
echo ""

# Check if Ollama is reachable
echo "1. Connectivity Check"
echo "-------------------"
if curl -s --max-time 5 "$OLLAMA_URL/api/version" > /dev/null 2>&1; then
    VERSION=$(curl -s "$OLLAMA_URL/api/version" | jq -r '.version')
    echo "✅ Ollama is reachable (version: $VERSION)"
else
    echo "❌ Ollama is NOT reachable"
    exit 1
fi
echo ""

# Check currently running models
echo "2. Currently Loaded Models"
echo "-------------------"
RUNNING_MODELS=$(curl -s "$OLLAMA_URL/api/ps" | jq -r '.models')
MODEL_COUNT=$(echo "$RUNNING_MODELS" | jq 'length')

if [ "$MODEL_COUNT" -eq 0 ]; then
    echo "No models currently loaded in memory"
else
    echo "Loaded models: $MODEL_COUNT"
    echo "$RUNNING_MODELS" | jq -r '.[] | "  • \(.name) - VRAM: \(.size_vram / 1024 / 1024 / 1024 | round)GB - Context: \(.context_length) - Expires: \(.expires_at)"'

    # Calculate total VRAM usage
    TOTAL_VRAM=$(echo "$RUNNING_MODELS" | jq '[.[].size_vram] | add')
    TOTAL_VRAM_GB=$(echo "scale=2; $TOTAL_VRAM / 1024 / 1024 / 1024" | bc)
    echo ""
    echo "  Total VRAM Usage: ${TOTAL_VRAM_GB}GB"
fi
echo ""

# Response time test
echo "3. Response Time Test"
echo "-------------------"
START_TIME=$(date +%s.%N)
curl -s "$OLLAMA_URL/api/version" > /dev/null
END_TIME=$(date +%s.%N)
RESPONSE_TIME=$(echo "$END_TIME - $START_TIME" | bc)
echo "API response time: ${RESPONSE_TIME}s"
echo ""

# Available models
echo "4. Available Models"
echo "-------------------"
TOTAL_MODELS=$(curl -s "$OLLAMA_URL/api/tags" | jq '.models | length')
echo "Total models available: $TOTAL_MODELS"
echo ""

# Simple load test
echo "5. Simple Request Test (optional)"
echo "-------------------"
read -p "Test a simple request to check if models are responding? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter model name (e.g., mistral:latest): " MODEL_NAME

    echo "Sending test request to $MODEL_NAME..."
    START_TIME=$(date +%s.%N)

    RESPONSE=$(curl -s -X POST "$OLLAMA_URL/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$MODEL_NAME\",
            \"prompt\": \"Say hello\",
            \"stream\": false
        }")

    END_TIME=$(date +%s.%N)
    REQUEST_TIME=$(echo "$END_TIME - $START_TIME" | bc)

    if echo "$RESPONSE" | jq -e '.response' > /dev/null 2>&1; then
        RESPONSE_TEXT=$(echo "$RESPONSE" | jq -r '.response')
        echo "✅ Model responded successfully"
        echo "Response: $RESPONSE_TEXT"
        echo "Time taken: ${REQUEST_TIME}s"

        # Check if it's slow
        if (( $(echo "$REQUEST_TIME > 30" | bc -l) )); then
            echo "⚠️  WARNING: Response time is slow (>30s). Model may be under heavy load."
        fi
    else
        echo "❌ Model did not respond properly"
        echo "$RESPONSE"
    fi
fi

echo ""
echo "================================================"
echo "Monitoring complete"
echo "================================================"
