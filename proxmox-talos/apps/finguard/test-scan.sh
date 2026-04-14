#!/bin/bash
set -e

FINGUARD_URL="${FINGUARD_URL:-https://finguard.botocudo.net}"
FINGUARD_USER="${FINGUARD_USER:-admin}"
FINGUARD_PASS="${FINGUARD_PASS:-admin123}"
IMAGE_NAME="finguard-test"
CONTAINER_NAME="finguard-test-runner"

echo "=== FinGuard Scan Test ==="
echo "Target: $FINGUARD_URL"
echo ""

# Build a minimal test container
echo "[1/4] Building test container..."
docker build -q -t "$IMAGE_NAME" -f - . <<'DOCKERFILE'
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates jq && rm -rf /var/lib/apt/lists/*
WORKDIR /tests
DOCKERFILE

# Run the test container
echo "[2/4] Downloading test samples..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
docker run -d --name "$CONTAINER_NAME" "$IMAGE_NAME" sleep 300 >/dev/null

docker exec "$CONTAINER_NAME" bash -c '
  mkdir -p /tests/samples

  echo "  Downloading EICAR test file..."
  curl -sSfL -o /tests/samples/eicar.com "https://secure.eicar.org/eicar.com" 2>/dev/null || \
    printf "X5O!P%%@AP[4\\PZX54(P^)7CC)7}\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\$H+H*" > /tests/samples/eicar.com

  echo "  Downloading safe-file.pdf..."
  curl -sSfL -o /tests/samples/safe-file.pdf \
    "https://raw.githubusercontent.com/fafiorim/finguard/main/samples/safe-file.pdf"

  echo "  Downloading file_active_content.pdf..."
  curl -sSfL -o /tests/samples/file_active_content.pdf \
    "https://raw.githubusercontent.com/fafiorim/finguard/main/samples/file_active_content.pdf"

  echo ""
  echo "  Files ready:"
  ls -lh /tests/samples/
'

echo ""
echo "[3/4] Uploading files to FinGuard..."
echo ""

for file in eicar.com safe-file.pdf file_active_content.pdf; do
  echo "--- $file ---"
  docker exec "$CONTAINER_NAME" bash -c "
    RESP=\$(curl -sk -u '${FINGUARD_USER}:${FINGUARD_PASS}' \
      -F 'file=@/tests/samples/${file}' \
      '${FINGUARD_URL}/api/upload' 2>&1)

    STATUS=\$(echo \"\$RESP\" | jq -r '.results[0].status // \"error\"')
    MSG=\$(echo \"\$RESP\" | jq -r '.results[0].message // .results[0].error // \"unknown\"')
    IS_SAFE=\$(echo \"\$RESP\" | jq -r '.results[0].scanResult.isSafe // \"N/A\"')

    if [ \"\$STATUS\" = \"success\" ]; then
      ICON='SAFE'
    elif [ \"\$STATUS\" = \"warning\" ]; then
      ICON='MALWARE'
    else
      ICON='FAIL'
    fi

    echo \"  [\$ICON] Status: \$STATUS\"
    echo \"         Message: \$MSG\"
    echo \"         isSafe: \$IS_SAFE\"
  "
  echo ""
done

echo "[4/4] Checking scan history..."
docker exec "$CONTAINER_NAME" bash -c "
  curl -sk -u '${FINGUARD_USER}:${FINGUARD_PASS}' \
    '${FINGUARD_URL}/api/scan-results' | jq -r '
    \"Total records: \(length)\n\",
    (.[:10][] |
      (if .isSafe == true then \"SAFE\"
       elif .isSafe == false then \"MALWARE\"
       else \"N/A\" end) as \$icon |
      \"  [\(\$icon)] \(.filename) - \(.action) (by \(.uploadedBy))\"
    )
  '
"

# Cleanup
echo ""
echo "=== Cleanup ==="
docker rm -f "$CONTAINER_NAME" >/dev/null
echo "Container removed. Done."
