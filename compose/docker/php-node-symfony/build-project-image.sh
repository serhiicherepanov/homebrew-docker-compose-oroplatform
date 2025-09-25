#!/bin/bash
set -euo pipefail

# Build project image with custom certificates
# Usage: ./build-project-image.sh <project-dir> <base-image> <target-image>

PROJECT_DIR="${1:-}"
BASE_IMAGE="${2:-}"
TARGET_IMAGE="${3:-}"

if [ -z "$PROJECT_DIR" ] || [ -z "$BASE_IMAGE" ] || [ -z "$TARGET_IMAGE" ]; then
    echo "Usage: $0 <project-dir> <base-image> <target-image>"
    echo "Example: $0 /path/to/project ghcr.io/digitalspacestdio/orodc-php-node-symfony:8.4-22-2-alpine my-project-php:latest"
    exit 1
fi

# Check if project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Project directory '$PROJECT_DIR' does not exist"
    exit 1
fi

CERT_DIR="$PROJECT_DIR/.crt"
DOCKERFILE_TEMPLATE="/tmp/Dockerfile.project-certs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if certificates directory exists and contains files
if [ ! -d "$CERT_DIR" ]; then
    echo "Info: No .crt directory found in project. Building standard image..."
    docker tag "$BASE_IMAGE" "$TARGET_IMAGE"
    exit 0
fi

# Count certificate files
cert_count=$(find "$CERT_DIR" -type f \( -name "*.crt" -o -name "*.pem" \) | wc -l)
if [ "$cert_count" -eq 0 ]; then
    echo "Info: No certificate files found in .crt directory. Building standard image..."
    docker tag "$BASE_IMAGE" "$TARGET_IMAGE"
    exit 0
fi

echo "Found $cert_count certificate(s) in $CERT_DIR"
echo "Building project image with custom certificates..."

# Create temporary Dockerfile
cat > "$DOCKERFILE_TEMPLATE" << 'EOF'
# Auto-generated Dockerfile for project with custom certificates
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Switch back to root to install certificates
USER root

# Copy certificates from project's .crt directory
COPY .crt/* /tmp/project-certs/

# Install certificates and convert PEM to CRT if needed
RUN set -eux; \
    mkdir -p /usr/local/share/ca-certificates; \
    for cert_file in /tmp/project-certs/*; do \
        if [ -f "$cert_file" ]; then \
            cert_name=$(basename "$cert_file"); \
            cert_ext="${cert_name##*.}"; \
            cert_base="${cert_name%.*}"; \
            \
            # Handle different certificate formats
            case "$cert_ext" in \
                pem|PEM) \
                    # Convert PEM to CRT format and install
                    cp "$cert_file" "/usr/local/share/ca-certificates/${cert_base}.crt"; \
                    echo "Installed PEM certificate: $cert_name -> ${cert_base}.crt"; \
                    ;; \
                crt|CRT) \
                    # Install CRT directly
                    cp "$cert_file" "/usr/local/share/ca-certificates/${cert_name}"; \
                    echo "Installed CRT certificate: $cert_name"; \
                    ;; \
                *) \
                    echo "Skipping unsupported certificate format: $cert_name"; \
                    ;; \
            esac; \
        fi; \
    done; \
    \
    # Update certificate store
    update-ca-certificates; \
    \
    # Clean up temporary files
    rm -rf /tmp/project-certs; \
    \
    # Show installed certificates
    echo "=== Installed project certificates ==="; \
    ls -la /usr/local/share/ca-certificates/ || true; \
    echo "======================================"

# Switch back to the application user
ARG PHP_USER_NAME=developer
USER ${PHP_USER_NAME}
EOF

# Build the project image with certificates
echo "Building Docker image..."
cd "$PROJECT_DIR"
docker build \
    --file "$DOCKERFILE_TEMPLATE" \
    --build-arg BASE_IMAGE="$BASE_IMAGE" \
    --build-arg PHP_USER_NAME="${PHP_USER_NAME:-developer}" \
    --tag "$TARGET_IMAGE" \
    .

# Clean up
rm -f "$DOCKERFILE_TEMPLATE"

echo "Successfully built project image: $TARGET_IMAGE"
echo "Certificates from $CERT_DIR have been installed in the image."
