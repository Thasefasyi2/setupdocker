#!/bin/bash

echo "[INFO] Membuat folder data jika belum ada..."
mkdir -p "$(pwd)/n8n_data"

echo "[INFO] Starting cloudflared tunnel..."
CLOUDFLARE_URL=""

cloudflared tunnel --url http://localhost:5678 | while IFS= read -r line
do
    echo "$line"

    if [[ "$line" == *"trycloudflare.com"* ]]; then
        CLOUDFLARE_URL=$(echo "$line" | grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com')
        echo "[INFO] Public URL found: $CLOUDFLARE_URL"

        echo "[INFO] Running n8n container..."
        docker run -d \
          -p 5678:5678 \
          -v "$(pwd)/n8n_data:/home/node/.n8n" \
          -e N8N_COMMUNITY_PACKAGES_ALLOW=true \
          -e N8N_EDITOR_BASE_URL="$CLOUDFLARE_URL" \
          -e WEBHOOK_URL="$CLOUDFLARE_URL" \
          -e N8N_DEFAULT_BINARY_DATA_MODE=filesystem \
          --name n8n_auto \
          n8nio/n8n:latest

        echo "[DONE] n8n is running at: $CLOUDFLARE_URL"
        echo "Press Ctrl+C to stop the tunnel..."
        break
    fi
done
