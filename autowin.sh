#!/bin/bash

# ==========================================
# KONFIGURASI KHUSUS WINDOWS
# ==========================================
CONTAINER_NAME="n8n_bash"
IMAGE_NAME="docker.n8n.io/n8nio/n8n"
CF_LOG_FILE="cloudflared_tunnel.log"

# ==========================================
# 1. PEMBERSIHAN AGRESIF (ANTI USER ERROR)
# ==========================================
echo "[1/5] Membersihkan proses cloudflared lama (jika ada)..."
# Taskkill adalah cara paling ampuh di Windows untuk mematikan proses yang nyangkut
taskkill /F /IM cloudflared.exe /T > /dev/null 2>&1
echo "  -> Proses cloudflared Windows dihentikan."
sleep 2

# ==========================================
# 2. JALANKAN CLOUDFLARED & AMBIL LINK
# ==========================================
echo "[2/5] Menyiapkan Cloudflared tunnel baru..."
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
# 3. CEK & HAPUS CONTAINER LAMA
# ==========================================
echo "[3/5] Mengecek container n8n lama..."
if docker inspect "$CONTAINER_NAME" &> /dev/null; then
    echo "  -> Container ditemukan. Menghapus untuk update URL..."
    docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1
    echo "  -> Container lama berhasil dihapus."
else
    echo "  -> Container belum ada. Melanjutkan..."
fi

# ==========================================
# 4. CEK FOLDER DATA
# ==========================================
echo "[4/5] Mengecek folder data..."
DATA_FOLDER="${PWD}/n8n_data"

if [ ! -d "$DATA_FOLDER" ]; then
  echo "  -> Folder tidak ada. Membuat folder n8n_data..."
  mkdir -p "$DATA_FOLDER"
else
  echo "  -> Folder n8n_data sudah ada. Data Anda aman."
fi

# ==========================================
# 5. JALANKAN CONTAINER BARU
# ==========================================
echo "[5/5] Menjalankan container n8n_bash..."

# MENGGUNAKAN SINTAKS VOLUME PERSIS SEPERTI SCRIPT ASLI ANDA YANG BERHASIL
docker run -d \
  --name "$CONTAINER_NAME" \
  -p 5678:5678 \
  -v "/${PWD}/n8n_data:/home/node/.n8n" \
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