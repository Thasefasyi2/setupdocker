#!/bin/bash

# Nama folder dan container
CONTAINER_NAME="waha_bash"
IMAGE_NAME="devlikeapro/waha:latest"

# MASUKKAN LINK CLOUDFLARE KAMU DI SINI (jika ingin pakai webhook publik)
# WEBHOOK_URL="https://strikes-dont-hindu-again.trycloudflare.com"

# 1. Tentukan folder session
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
  SESSION_FOLDER="$(pwd | sed 's|^\([A-Za-z]\):|/\L\1|')/waha_session"
else
  SESSION_FOLDER="${PWD}/waha_session"
fi

# 2. Cek folder session
if [ ! -d "$SESSION_FOLDER" ]; then
  echo "Folder session belum ada. Membuat folder..."
  mkdir -p "$SESSION_FOLDER"
else
  echo "Folder session sudah ada. Menggunakan folder lama..."
fi

# 3. Hapus container lama jika ada
if [ "$(docker ps -a -q -f name=$CONTAINER_NAME)" ]; then
    echo "Menghapus container lama $CONTAINER_NAME..."
    docker rm -f $CONTAINER_NAME
fi

# 4. Jalankan container baru Waha
echo "Menjalankan container Waha di port 3000..."
docker run -d \
  -p 3000:3000 \
  -v "$SESSION_FOLDER:/app/.waha" \
  -e WAHA_WEBHOOK_ENABLED=true \
  -e WAHA_WEBHOOK_BASE_URL="$WEBHOOK_URL" \
  -e WAHA_WEBHOOK_URL="$WEBHOOK_URL" \
  --name $CONTAINER_NAME \
  $IMAGE_NAME

echo "✅ WAHA backend siap digunakan!"
echo "🌍 Akses lokal: http://localhost:3000"
echo "🌐 Webhook URL (Cloudflare): $WEBHOOK_URL"
echo "🗂️  Data session tersimpan di folder: $SESSION_FOLDER"
