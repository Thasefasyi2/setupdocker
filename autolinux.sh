#!/bin/bash

# ==========================================
# KONFIGURASI
# ==========================================
CONTAINER_NAME="n8n_bash"
IMAGE_NAME="n8nio/n8n:latest"
CF_LOG_FILE="cloudflared_tunnel.log"

# ==========================================
# 1. PEMBERSIHAN AGRESIF (ANTI USER ERROR)
# ==========================================
echo "[1/5] Membersihkan proses cloudflared lama (jika ada)..."

if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
  # --- WINDOWS ---
  # Taskkill akan mematikan paksa semua proses cloudflared.exe beserta child process-nya
  taskkill /F /IM cloudflared.exe /T > /dev/null 2>&1
  echo "  -> Proses cloudflared Windows dihentikan."
else
  # --- LINUX / MAC ---
  # pkill akan mencari dan mematikan proses yang mengandung kata 'cloudflared'
  pkill -f "cloudflared" > /dev/null 2>&1
  echo "  -> Proses cloudflared Linux dihentikan."
fi

# Beri jeda 2 detik agar sistem operasi benar-benar melepaskan Port 5678
sleep 2

# ==========================================
# 2. JALANKAN CLOUDFLARED & AMBIL LINK
# ==========================================
echo "[2/5] Menyiapkan Cloudflared tunnel baru..."

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
    echo "  -> âŒ Gagal mendapatkan link Cloudflared. Pastikan cloudflared terinstal dan ada koneksi internet."
    echo "  -> Cek file $CF_LOG_FILE untuk detail error."
    kill $CF_PID 2>/dev/null
    exit 1
fi
echo "  -> âœ… Link Cloudflared didapatkan: $TUNNEL_URL"

# ==========================================
# 3. CEK & HAPUS CONTAINER LAMA
# ==========================================
echo "[3/5] Mengecek container n8n lama..."
if docker inspect "$CONTAINER_NAME" &> /dev/null; then
    echo "  -> Container ditemukan. Menghapus untuk memastikan URL terupdate..."
    docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1
    echo "  -> Container lama berhasil dihapus."
else
    echo "  -> Container belum ada. Melanjutkan..."
fi

# ==========================================
# 4. CEK FOLDER DATA & PERBAIKI PERMISSION
# ==========================================
echo "[4/5] Mengecek folder data dan permission..."

if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
  # --- WINDOWS ---
  DATA_FOLDER="$(pwd | sed 's|^\([A-Za-z]\):|/\L\1|')/n8n_data"
  VOL_PATH="/$(pwd -W | sed 's|:\\|/|g')/n8n_data"
else
  # --- LINUX / MAC ---
  DATA_FOLDER="${PWD}/n8n_data"
  VOL_PATH="$DATA_FOLDER"
  
  # Buat folder jika belum ada
  if [ ! -d "$DATA_FOLDER" ]; then
    mkdir -p "$DATA_FOLDER"
  fi
  
  # PERBAIKAN PERMISSION LINUX:
  # Mengubah pemilik folder ke UID 1000 (user 'node' di dalam Docker)
  # agar tidak terjadi error "EACCES: permission denied"
  chown -R 1000:1000 "$DATA_FOLDER" 2>/dev/null
fi

echo "  -> Path data: $DATA_FOLDER"

# ==========================================
# 5. JALANKAN CONTAINER BARU
# ==========================================
echo "[5/5] Menjalankan container n8n_bash..."

docker run -d \
  --name "$CONTAINER_NAME" \
  -p 5678:5678 \
  -v "$VOL_PATH:/home/node/.n8n" \
  -e N8N_COMMUNITY_PACKAGES_ALLOW=true \
  -e N8N_EDITOR_BASE_URL="$TUNNEL_URL" \
  -e WEBHOOK_URL="$TUNNEL_URL" \
  -e N8N_DEFAULT_BINARY_DATA_MODE=filesystem \
  --restart unless-stopped \
  "$IMAGE_NAME"

if [ $? -eq 0 ]; then
    echo "===================================================="
    echo " âœ… n8n BERHASIL DIJALANKAN!"
    echo " ðŸ”— Akses di browser: $TUNNEL_URL"
    echo " ðŸ’¾ Data tersimpan di: $DATA_FOLDER"
    echo "===================================================="
else
    echo "âŒ Gagal menjalankan container. Cek: docker logs $CONTAINER_NAME"
fi
