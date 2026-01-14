#!/bin/bash
set -e

# Fork script: Transforms @supabase/stripe-sync-engine to @pretzelai/stripe-sync-engine
# Run this after pulling updates from the upstream supabase repo
#
# Changes made:
# 1. Removes "alter function owner to postgres" from migration (works with any Postgres, not just Supabase)
# 2. Renames package from @supabase to @pretzelai
# 3. Updates all internal references
# 4. Applies custom patches from scripts/patches/
# 5. Builds the package
#
# To add new patches:
#   Create a .patch file in scripts/patches/ using: git diff > scripts/patches/my-fix.patch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Starting fork transformation..."

# 1. Get the upstream version
UPSTREAM_VERSION=$(npm view @supabase/stripe-sync-engine version 2>/dev/null || echo "0.48.1")
echo "==> Upstream version: $UPSTREAM_VERSION"

# 2. Remove the postgres role ownership line from migration (general Postgres compatibility)
MIGRATION_FILE="$ROOT_DIR/packages/sync-engine/src/database/migrations/0012_add_updated_at.sql"
if grep -q "alter function set_updated_at() owner to postgres;" "$MIGRATION_FILE"; then
    echo "==> Removing postgres role ownership from migration..."
    sed -i '' '/alter function set_updated_at() owner to postgres;/d' "$MIGRATION_FILE"
fi

# 3. Update sync-engine package.json (name and version)
SYNC_ENGINE_PKG="$ROOT_DIR/packages/sync-engine/package.json"
echo "==> Updating sync-engine package.json..."
sed -i '' 's/"name": "@supabase\/stripe-sync-engine"/"name": "@pretzelai\/stripe-sync-engine"/' "$SYNC_ENGINE_PKG"
sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$UPSTREAM_VERSION\"/" "$SYNC_ENGINE_PKG"

# 4. Update fastify-app package.json dependency
FASTIFY_PKG="$ROOT_DIR/packages/fastify-app/package.json"
echo "==> Updating fastify-app package.json..."
sed -i '' 's/"@supabase\/stripe-sync-engine": "workspace:"/"@pretzelai\/stripe-sync-engine": "workspace:"/' "$FASTIFY_PKG"

# 5. Update all imports in fastify-app source files
echo "==> Updating imports in fastify-app..."
find "$ROOT_DIR/packages/fastify-app/src" -type f -name "*.ts" -exec \
    sed -i '' 's/@supabase\/stripe-sync-engine/@pretzelai\/stripe-sync-engine/g' {} \;

# 6. Clean .npmrc (remove Supabase CI/CD config)
NPMRC_FILE="$ROOT_DIR/.npmrc"
echo "==> Cleaning .npmrc..."
echo "" > "$NPMRC_FILE"

# 7. Apply patches (custom fixes for our fork)
PATCHES_DIR="$SCRIPT_DIR/patches"
if [ -d "$PATCHES_DIR" ]; then
    echo "==> Applying patches..."
    for patch in "$PATCHES_DIR"/*.patch; do
        if [ -f "$patch" ]; then
            echo "    Applying $(basename "$patch")..."
            # Use -N to skip already applied patches, --ignore-whitespace for flexibility
            git apply --ignore-whitespace "$patch" 2>/dev/null || {
                echo "    (patch already applied or doesn't match, skipping)"
            }
        fi
    done
fi

# 8. Install dependencies (re-link workspace packages)
echo "==> Installing dependencies..."
cd "$ROOT_DIR"
pnpm install

# 9. Build
echo "==> Building..."
pnpm run build

echo ""
echo "==> Fork transformation complete!"
echo "==> Package: @pretzelai/stripe-sync-engine@$UPSTREAM_VERSION"
echo ""
echo "To publish, run:"
echo "  npm publish --access public ./packages/sync-engine"
