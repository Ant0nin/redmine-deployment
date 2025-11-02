#!/bin/sh
set -e

# Attendre que la base de données soit prête
echo "Waiting for database..."
until PGPASSWORD=$REDMINE_DB_PASSWORD psql -h "$REDMINE_DB_POSTGRES" -U "$REDMINE_DB_USERNAME" -d "$REDMINE_DB_DATABASE" -c '\q' 2>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done

echo "Database is ready!"

# Créer la base de données si elle n'existe pas
bundle exec rake db:create 2>/dev/null || true

# Exécuter les migrations
echo "Running database migrations..."
bundle exec rake db:migrate RAILS_ENV=production

# Charger les données par défaut si c'est la première installation
if [ ! -f /usr/src/redmine/files/.initialized ]; then
  echo "Loading default data..."
  bundle exec rake redmine:load_default_data REDMINE_LANG=en RAILS_ENV=production || true
  touch /usr/src/redmine/files/.initialized
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
