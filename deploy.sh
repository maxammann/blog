#!/bin/sh

# Default settings
DEPLOY_PREFIX=""
USE_HASH=false
CUSTOM_HASH=""

# Parse command line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefix)
            DEPLOY_PREFIX="$2"
            shift 2
            ;;
        --unique)
            USE_HASH=true
            shift
            ;;
        --hash)
            CUSTOM_HASH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--prefix DIR] [--unique] [--hash HASH]"
            exit 1
            ;;
    esac
done

# Generate random hash if needed or use custom hash
if [ -n "$CUSTOM_HASH" ]; then
    # Use the provided hash
    if [ -n "$DEPLOY_PREFIX" ]; then
        DEPLOY_PREFIX="${DEPLOY_PREFIX}-${CUSTOM_HASH}"
    else
        DEPLOY_PREFIX="${CUSTOM_HASH}"
    fi
elif [ "$USE_HASH" = true ]; then
    # Generate a random hash
    RANDOM_HASH=$(date +%s | sha256sum | head -c 16)
    if [ -n "$DEPLOY_PREFIX" ]; then
        DEPLOY_PREFIX="${DEPLOY_PREFIX}-${RANDOM_HASH}"
    else
        DEPLOY_PREFIX="${RANDOM_HASH}"
    fi
fi

# Create target directory path
TARGET_PATH="/var/www/html"
if [ -n "$DEPLOY_PREFIX" ]; then
    TARGET_PATH="${TARGET_PATH}/${DEPLOY_PREFIX}"
    echo "Deploying to prefix: ${DEPLOY_PREFIX}"
fi

# Clean existing public directory
rm -rf public/

# Build with correct base URL
if [ -n "$DEPLOY_PREFIX" ]; then
    hugo --gc --baseURL="https://maxammann.org/${DEPLOY_PREFIX}/"
else
    hugo --gc
fi

# Deploy using rsync
rsync -r --progress public/ maxammann.org:"${TARGET_PATH}"

# Output deployment URL
if [ -n "$DEPLOY_PREFIX" ]; then
    echo "Deployed to https://maxammann.org/${DEPLOY_PREFIX}"
else
    echo "Deployed to https://maxammann.org/"
fi
