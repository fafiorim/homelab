#!/bin/bash

# Ollama Model Management Script
# Easily list, load, and unload models

OLLAMA_URL="${OLLAMA_URL:-http://10.10.21.6:11434}"

show_usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  list              List all available models"
    echo "  loaded            Show currently loaded models"
    echo "  unload <model>    Unload a specific model from memory"
    echo "  unload-all        Unload all models from memory"
    echo "  status            Show comprehensive status"
    echo ""
    echo "Examples:"
    echo "  $0 loaded"
    echo "  $0 unload qwen3-vl:8b"
    echo "  $0 unload-all"
    echo ""
    echo "Environment:"
    echo "  OLLAMA_URL=${OLLAMA_URL}"
}

list_models() {
    echo "Available Models:"
    echo "=================="
    curl -s "$OLLAMA_URL/api/tags" | jq -r '.models[] | "  • \(.name) - Size: \(.size / 1024 / 1024 / 1024 | round)GB - Params: \(.details.parameter_size)"'
}

show_loaded() {
    echo "Currently Loaded Models:"
    echo "========================"
    RUNNING=$(curl -s "$OLLAMA_URL/api/ps")
    COUNT=$(echo "$RUNNING" | jq '.models | length')

    if [ "$COUNT" -eq 0 ]; then
        echo "No models currently loaded in memory"
    else
        echo "$RUNNING" | jq -r '.models[] | "  • \(.name) - VRAM: \(.size_vram / 1024 / 1024 / 1024 | round)GB - Expires: \(.expires_at)"'

        TOTAL_VRAM=$(echo "$RUNNING" | jq '[.models[].size_vram] | add')
        TOTAL_GB=$(echo "scale=2; $TOTAL_VRAM / 1024 / 1024 / 1024" | bc)
        echo ""
        echo "Total VRAM Usage: ${TOTAL_GB}GB"
    fi
}

unload_model() {
    MODEL="$1"
    if [ -z "$MODEL" ]; then
        echo "Error: Model name required"
        echo "Usage: $0 unload <model-name>"
        exit 1
    fi

    echo "Unloading model: $MODEL"
    RESPONSE=$(curl -s -X POST "$OLLAMA_URL/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$MODEL\", \"keep_alive\": 0}")

    DONE_REASON=$(echo "$RESPONSE" | jq -r '.done_reason')

    if [ "$DONE_REASON" = "unload" ]; then
        echo "✅ Successfully unloaded: $MODEL"
    else
        echo "❌ Failed to unload model"
        echo "$RESPONSE" | jq '.'
    fi
}

unload_all() {
    echo "Unloading all models..."
    MODELS=$(curl -s "$OLLAMA_URL/api/ps" | jq -r '.models[].name')

    if [ -z "$MODELS" ]; then
        echo "No models currently loaded"
        exit 0
    fi

    while IFS= read -r model; do
        echo "Unloading: $model"
        curl -s -X POST "$OLLAMA_URL/api/generate" \
            -H "Content-Type: application/json" \
            -d "{\"model\": \"$model\", \"keep_alive\": 0}" > /dev/null
        echo "  ✅ Unloaded: $model"
    done <<< "$MODELS"

    echo ""
    echo "All models unloaded successfully"
}

show_status() {
    echo "Ollama Status"
    echo "============="
    echo ""

    # Version
    VERSION=$(curl -s "$OLLAMA_URL/api/version" | jq -r '.version')
    echo "Version: $VERSION"
    echo ""

    # Loaded models
    show_loaded
    echo ""

    # Available models count
    TOTAL=$(curl -s "$OLLAMA_URL/api/tags" | jq '.models | length')
    echo "Total Available Models: $TOTAL"
}

# Main command handling
case "$1" in
    list)
        list_models
        ;;
    loaded)
        show_loaded
        ;;
    unload)
        unload_model "$2"
        ;;
    unload-all)
        unload_all
        ;;
    status)
        show_status
        ;;
    -h|--help|"")
        show_usage
        ;;
    *)
        echo "Error: Unknown command '$1'"
        echo ""
        show_usage
        exit 1
        ;;
esac
