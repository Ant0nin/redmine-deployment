#!/bin/bash

# Script de déploiement Redmine
# Usage: ./deploy.sh [dev|prod]

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier l'environnement
ENV=${1:-dev}

if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
    log_error "Environnement invalide. Utilisez: ./deploy.sh [dev|prod]"
    exit 1
fi

log_info "Déploiement de Redmine en mode: $ENV"

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    log_error "Docker n'est pas installé!"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose n'est pas installé!"
    exit 1
fi

# Créer le fichier .env s'il n'existe pas
if [ ! -f .env ]; then
    log_warn "Fichier .env non trouvé. Création avec les valeurs par défaut..."
    
    # Générer des mots de passe sécurisés
    DB_PASSWORD=$(openssl rand -base64 32)
    SECRET_KEY=$(openssl rand -hex 64)
    
    cat > .env << EOF
# Configuration de la base de données
POSTGRES_DB=redmine
POSTGRES_USER=redmine
POSTGRES_PASSWORD=$DB_PASSWORD

# Configuration de Redmine
REDMINE_PORT=3000
REDMINE_SECRET_KEY=$SECRET_KEY
EOF
    
    log_info "Fichier .env créé avec des mots de passe sécurisés"
    log_warn "IMPORTANT: Sauvegardez ces informations:"
    echo "  - DB Password: $DB_PASSWORD"
    echo "  - Secret Key: $SECRET_KEY"
else
    log_info "Utilisation du fichier .env existant"
fi

# Créer les répertoires nécessaires
log_info "Création des répertoires..."
mkdir -p ssl plugins themes

# Mode développement
if [ "$ENV" = "dev" ]; then
    log_info "Démarrage en mode développement..."
    
    # Arrêter les conteneurs existants
    docker-compose down
    
    # Démarrer les services
    docker-compose up -d
    
    # Attendre que Redmine soit prêt
    log_info "Attente du démarrage de Redmine..."
    sleep 10
    
    # Vérifier l'état des services
    docker-compose ps
    
    log_info "Redmine est accessible sur: http://localhost:3000"
    log_info "Identifiants par défaut: admin / admin"

# Mode production
elif [ "$ENV" = "prod" ]; then
    log_info "Démarrage en mode production..."
    
    # Vérifier les certificats SSL
    if [ ! -f ssl/cert.pem ] || [ ! -f ssl/key.pem ]; then
        log_warn "Certificats SSL non trouvés. Génération de certificats auto-signés..."
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ssl/key.pem \
            -out ssl/cert.pem \
            -subj "/C=FR/ST=State/L=City/O=Organization/CN=redmine.example.com"
        
        log_warn "Certificats auto-signés créés. Pour la production, utilisez des certificats valides!"
    fi
    
    # Construire l'image personnalisée
    log_info "Construction de l'image Docker personnalisée..."
    docker-compose -f docker-compose.production.yml build
    
    # Arrêter les conteneurs existants
    docker-compose -f docker-compose.production.yml down
    
    # Démarrer les services
    docker-compose -f docker-compose.production.yml up -d
    
    # Attendre que Redmine soit prêt
    log_info "Attente du démarrage de Redmine..."
    sleep 20
    
    # Vérifier l'état des services
    docker-compose -f docker-compose.production.yml ps
    
    log_info "Redmine est accessible sur:"
    log_info "  - HTTP: http://localhost"
    log_info "  - HTTPS: https://localhost"
    log_info "Identifiants par défaut: admin / admin"
fi

# Afficher les logs
log_info "Pour voir les logs, utilisez:"
if [ "$ENV" = "dev" ]; then
    echo "  docker-compose logs -f"
else
    echo "  docker-compose -f docker-compose.production.yml logs -f"
fi

log_info "Déploiement terminé avec succès!"

# Instructions post-installation
cat << EOF

${GREEN}=== Instructions post-installation ===${NC}

1. Changez immédiatement le mot de passe admin après la première connexion

2. Configuration email (optionnel):
   - Copiez configuration.yml.example vers configuration.yml
   - Modifiez les paramètres SMTP
   - Redémarrez le conteneur Redmine

3. Installation de plugins:
   - Placez les plugins dans le dossier ./plugins
   - Redémarrez le conteneur Redmine

4. Installation de thèmes:
   - Placez les thèmes dans le dossier ./themes
   - Redémarrez le conteneur Redmine

5. Sauvegarde:
   - Base de données: docker exec redmine-postgres pg_dump -U redmine redmine > backup.sql
   - Fichiers: docker run --rm -v redmine_files:/data -v \$(pwd):/backup alpine tar czf /backup/files.tar.gz /data

6. Commandes utiles:
   - Arrêter: docker-compose down
   - Redémarrer: docker-compose restart
   - Logs: docker-compose logs -f [service]
   - Shell Redmine: docker exec -it redmine-app /bin/bash
   - Console Rails: docker exec -it redmine-app rails console

EOF
