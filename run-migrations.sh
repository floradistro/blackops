#!/bin/bash
# Apply Supabase migrations via SQL execution
# Requires psql to be installed

set -e

SUPABASE_URL="uaednwpxursknmwdeejn.supabase.co"
DB_PASSWORD="your_db_password_here"  # You'll need to get this from Supabase dashboard

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Applying Supabase migrations..."
echo ""

# Check if psql is installed
if ! command -v psql &> /dev/null; then
    echo -e "${RED}✗ Error: psql is not installed${NC}"
    echo "Please install PostgreSQL client tools:"
    echo "  macOS: brew install postgresql"
    echo "  or use Postgres.app from https://postgresapp.com"
    exit 1
fi

# Function to apply a single migration
apply_migration() {
    local migration_file=$1
    local migration_name=$(basename "$migration_file")

    echo -e "${YELLOW}→${NC} Applying: $migration_name"

    if PGPASSWORD="$DB_PASSWORD" psql \
        -h "db.$SUPABASE_URL" \
        -p 5432 \
        -U postgres \
        -d postgres \
        -f "$migration_file" \
        -v ON_ERROR_STOP=1 \
        --quiet; then
        echo -e "${GREEN}✓${NC} Success: $migration_name"
        return 0
    else
        echo -e "${RED}✗${NC} Failed: $migration_name"
        return 1
    fi
}

# Apply migrations in order
MIGRATIONS_DIR="./supabase/migrations"

apply_migration "$MIGRATIONS_DIR/20260119_product_field_values_and_schema_assignments.sql" || exit 1
apply_migration "$MIGRATIONS_DIR/20260119_fix_product_stock_status.sql" || exit 1

echo ""
echo -e "${GREEN}✓ All migrations applied successfully!${NC}"
echo ""
echo "Note: If you see an error about the database password, please:"
echo "1. Go to your Supabase project dashboard"
echo "2. Navigate to Settings > Database"
echo "3. Copy the database password"
echo "4. Update the DB_PASSWORD variable in this script"
