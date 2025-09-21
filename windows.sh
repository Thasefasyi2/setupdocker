#!/bin/bash

# Nama folder dan container
CONTAINER_NAME="n8n_bash"
IMAGE_NAME="n8nio/n8n:latest"

# 1. Tentukan folder data dengan benar
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
  # Windows Git Bash / WSL
  DATA_FOLDER="$(pwd | sed 's|^\([A-Za-z]\):|/\L\1|')/n8n_data"
else
  # Linux / Mac
  DATA_FOLDER="${PWD}/n8n_data"
fi

# 2. Cek folder
if [ ! -d "$DATA_FOLDER" ]; then
  echo "Folder n8n_data tidak ada. Membuat folder..."
  mkdir -p "$DATA_FOLDER"
else
  echo "Folder n8n_data sudah ada. Menggunakan folder yang ada..."
fi

# 3. Cek container
if [ "$(docker ps -a -q -f name=$CONTAINER_NAME)" ]; then
    echo "Container $CONTAINER_NAME sudah ada."
    if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
        echo "Container sedang berjalan."
    else
        echo "Container stop. Menjalankan ulang..."
        docker start $CONTAINER_NAME
    fi
else
    echo "Container $CONTAINER_NAME belum ada. Membuat dan menjalankan baru..."
    docker run -d \
      -p 5678:5678 \
      -v "/$(pwd -W | sed 's|:\\|/|g')/n8n_data:/home/node/.n8n" \
      -e N8N_COMMUNITY_PACKAGES_ALLOW=true \
      -e N8N_EDITOR_BASE_URL="https://dom-copies-serial-hdtv.trycloudflare.com" \
      -e WEBHOOK_URL="https://dom-copies-serial-hdtv.trycloudflare.com" \
      -e N8N_DEFAULT_BINARY_DATA_MODE=filesystem \
      --name $CONTAINER_NAME \
      $IMAGE_NAME
fi
