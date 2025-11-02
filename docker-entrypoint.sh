#!/bin/sh
set -e

# Attendre PostgreSQL
echo "Waiting for PostgreSQL..."
max_attempts=30
attempt=0

until PGPASSWORD=$REDMINE_DB_PASSWORD psql -h "$REDMINE_DB_POSTGRES" -p "${REDMINE_DB_PORT:-5432}" -U "$REDMINE_DB_USERNAME" -d "$REDMINE_DB_DATABASE" -c '\q' 2>/dev/null; do
  attempt=$((attempt + 1))
  if [ $attempt -eq $max_attempts ]; then
    echo "❌ Could not connect to PostgreSQL after $max_attempts attempts"
    exit 1
  fi
  echo "PostgreSQL is unavailable - sleeping (attempt $attempt/$max_attempts)"
  sleep 2
done

echo "✓ PostgreSQL is ready!"

# Créer la base de données si elle n'existe pas
bundle exec rake db:create 2>/dev/null || true

# Vérifier si la base est initialisée
TABLE_COUNT=$(PGPASSWORD=$REDMINE_DB_PASSWORD psql -h "$REDMINE_DB_POSTGRES" -p "${REDMINE_DB_PORT:-5432}" -U "$REDMINE_DB_USERNAME" -d "$REDMINE_DB_DATABASE" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ' || echo "0")

echo "Found $TABLE_COUNT tables in database"

if [ "$TABLE_COUNT" -lt 10 ]; then
  echo "=== Running database migrations ==="
  bundle exec rake db:migrate RAILS_ENV=production
  
  echo "=== Loading default data ==="
  bundle exec rake redmine:load_default_data RAILS_ENV=production REDMINE_LANG=fr
EOF
  echo "✓ Database initialized!"
else
  echo "✓ Database already initialized with $TABLE_COUNT tables"
fi

# Installer les plugins
echo "Migrating plugins..."
bundle exec rake redmine:plugins:migrate RAILS_ENV=production || true

# Générer la clé secrète si elle n'existe pas
if [ -z "$REDMINE_SECRET_KEY_BASE" ]; then
  export REDMINE_SECRET_KEY_BASE=$(bundle exec rake secret)
  echo "Generated secret key base"
fi

# Compiler les assets
echo "Compiling assets..."
bundle exec rake assets:precompile

# Nettoyer le cache
bundle exec rake tmp:clear

echo "Starting Redmine..."
exec "$@"
