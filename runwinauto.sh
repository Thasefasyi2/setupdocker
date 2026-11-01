#!/bin/bash

# ==========================================
# KONFIGURASI
# ==========================================
CONTAINER_NAME="n8n_bash"
IMAGE_NAME="n8nio/n8n:latest"
CF_LOG_FILE="cloudflared_tunnel.log"

# ==========================================
# 1. JALANKAN CLOUDFLARED & AMBIL LINK
# ==========================================
echo "[1/4] Menyiapkan Cloudflared tunnel..."

# Bunuh proses cloudflared lama agar port tidak bentrok
pkill -f "cloudflared tunnel --url" 2>/dev/null

# Jalankan cloudflared di background
cloudflared tunnel --url http://localhost:5678 > "$CF_LOG_FILE" 2>&1 &
CF_PID=$!

echo "  -> Menunggu link tunnel tersedia (maksimal 15 detik)..."
TIMEOUT=15
ELAPSED=0
TUNNEL_URL=""

while [ $ELAPSED -lt $TIMEOUT ]; do
    if [ -f "$CF_LOG_FILE" ]; then
        TUNNEL_URL=$(grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare\.com' "$CF_LOG_FILE" | head -n 1)
        if [ -n "$TUNNEL_URL" ]; then
            break
        fi
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

if [ -z "$TUNNEL_URL" ]; then
    echo "  -> ❌ Gagal mendapatkan link Cloudflared. Cek file $CF_LOG_FILE"
    kill $CF_PID 2>/dev/null
    exit 1
fi
echo "  -> ✅ Link Cloudflared didapatkan: $TUNNEL_URL"

# ==========================================
# 2. CEK & HAPUS CONTAINER LAMA
# ==========================================
echo "[2/4] Mengecek container lama..."
if docker inspect "$CONTAINER_NAME" &> /dev/null; then
    echo "  -> Container ditemukan. Menghapus untuk update URL..."
    docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1
    echo "  -> Container lama berhasil dihapus."
else
    echo "  -> Container belum ada. Melanjutkan..."
fi

# ==========================================
# 3. CEK & PASTIKAN FOLDER DATA ADA
# ==========================================
echo "[3/4] Mengecek folder data..."
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
  DATA_FOLDER="$(pwd | sed 's|^\([A-Za-z]\):|/\L\1|')/n8n_data"
else
  DATA_FOLDER="${PWD}/n8n_data"
fi

if [ ! -d "$DATA_FOLDER" ]; then
  echo "  -> Folder tidak ada. Membuat folder n8n_data..."
  mkdir -p "$DATA_FOLDER"
else
  echo "  -> Folder n8n_data sudah ada. Data Anda aman."
fi

# ==========================================
# 4. JALANKAN CONTAINER BARU (SINTAKS ASLI ANDA)
# ==========================================
echo "[4/4] Menjalankan container n8n_bash..."

# MENGGUNAKAN SINTAKS PERSIS SEPERTI SCRIPT ASLI ANDA YANG BERHASIL
# (N8N_ENCRYPTION_KEY DIHAPUS agar tidak bentrok dengan data yang sudah ada)
docker run -d \
  --name "$CONTAINER_NAME" \
  -p 5678:5678 \
  -v "/$(pwd -W | sed 's|:\\|/|g')/n8n_data:/home/node/.n8n" \
  -e N8N_COMMUNITY_PACKAGES_ALLOW=true \
  -e N8N_EDITOR_BASE_URL="$TUNNEL_URL" \
  -e WEBHOOK_URL="$TUNNEL_URL" \
  -e N8N_DEFAULT_BINARY_DATA_MODE=filesystem \
  --restart unless-stopped \
  "$IMAGE_NAME"

if [ $? -eq 0 ]; then
    echo "===================================================="
    echo " ✅ n8n BERHASIL DIJALANKAN!"
    echo " 🔗 Akses di browser: $TUNNEL_URL"
    echo " 💾 Data tersimpan di: $DATA_FOLDER"
    echo "===================================================="
else
    echo "❌ Gagal menjalankan container. Cek: docker logs $CONTAINER_NAME"
fi