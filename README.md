# Déploiement de Redmine avec Docker

Ce projet fournit une configuration complète pour déployer Redmine avec Docker, incluant PostgreSQL comme base de données et Nginx comme reverse proxy pour la production.

## 📋 Prérequis

- Docker (version 20.10+)
- Docker Compose (version 1.29+)
- Au moins 2GB de RAM disponible
- 10GB d'espace disque libre

## 🚀 Démarrage rapide

### Mode développement

```bash
# Cloner ou télécharger les fichiers
# Rendre le script exécutable
chmod +x deploy.sh

# Lancer le déploiement en mode développement
./deploy.sh dev
```

Redmine sera accessible sur: http://localhost:3000

### Mode production

```bash
# Lancer le déploiement en mode production
./deploy.sh prod
```

Redmine sera accessible sur:
- HTTP: http://localhost (redirige vers HTTPS)
- HTTPS: https://localhost

## 📁 Structure des fichiers

```
.
├── docker-compose.yml              # Configuration Docker Compose pour dev
├── docker-compose.production.yml   # Configuration Docker Compose pour prod
├── Dockerfile                      # Image Docker personnalisée
├── docker-entrypoint.sh           # Script d'initialisation
├── nginx.conf                     # Configuration Nginx
├── configuration.yml.example      # Exemple de configuration email
├── .env                          # Variables d'environnement (créé automatiquement)
├── deploy.sh                     # Script de déploiement automatisé
├── plugins/                      # Dossier pour les plugins Redmine
├── themes/                       # Dossier pour les thèmes Redmine
└── ssl/                         # Certificats SSL (prod)
```

## ⚙️ Configuration

### Variables d'environnement

Le fichier `.env` contient les configurations principales:

```bash
# Base de données
POSTGRES_DB=redmine
POSTGRES_USER=redmine
POSTGRES_PASSWORD=your_secure_password

# Redmine
REDMINE_PORT=3000
REDMINE_SECRET_KEY=your_secret_key
```

### Configuration email

1. Copiez `configuration.yml.example` vers `configuration.yml`
2. Modifiez les paramètres SMTP selon votre fournisseur
3. Redémarrez le conteneur Redmine

Exemple pour Gmail:
```yaml
production:
  email_delivery:
    delivery_method: :smtp
    smtp_settings:
      enable_starttls_auto: true
      address: "smtp.gmail.com"
      port: 587
      domain: "gmail.com"
      authentication: :plain
      user_name: "votre-email@gmail.com"
      password: "votre-mot-de-passe-application"
```

## 🔧 Personnalisation

### Installation de plugins

1. Téléchargez le plugin dans le dossier `plugins/`
2. Redémarrez le conteneur:
```bash
docker-compose restart redmine
```

Plugins recommandés:
- **Redmine Agile**: Gestion de projet Agile/Scrum
- **Redmine CKEditor**: Éditeur WYSIWYG
- **Redmine DrawIO**: Intégration de diagrammes

### Installation de thèmes

1. Téléchargez le thème dans le dossier `themes/`
2. Redémarrez le conteneur
3. Activez le thème dans Administration > Paramètres > Affichage

## 🔐 Sécurité

### Premières étapes après l'installation

1. **Changez le mot de passe admin** (par défaut: admin/admin)
2. Créez un nouvel utilisateur administrateur
3. Désactivez ou supprimez le compte admin par défaut
4. Configurez les permissions et rôles

### Certificats SSL (Production)

Pour la production, remplacez les certificats auto-signés:

```bash
# Placez vos certificats dans le dossier ssl/
cp /path/to/your/cert.pem ssl/
cp /path/to/your/key.pem ssl/
```

Ou utilisez Let's Encrypt avec Certbot.

## 💾 Sauvegarde et restauration

### Sauvegarde

```bash
# Sauvegarde de la base de données
docker exec redmine-postgres pg_dump -U redmine redmine > backup_$(date +%Y%m%d).sql

# Sauvegarde des fichiers uploadés
docker run --rm -v redmine_files:/data -v $(pwd):/backup \
  alpine tar czf /backup/files_$(date +%Y%m%d).tar.gz /data

# Sauvegarde des plugins
tar czf plugins_$(date +%Y%m%d).tar.gz plugins/

# Sauvegarde des thèmes
tar czf themes_$(date +%Y%m%d).tar.gz themes/
```

### Restauration

```bash
# Restaurer la base de données
docker exec -i redmine-postgres psql -U redmine redmine < backup_20240101.sql

# Restaurer les fichiers
docker run --rm -v redmine_files:/data -v $(pwd):/backup \
  alpine tar xzf /backup/files_20240101.tar.gz -C /

# Restaurer plugins et thèmes
tar xzf plugins_20240101.tar.gz
tar xzf themes_20240101.tar.gz
```

## 🛠️ Commandes utiles

```bash
# Exécuter les migrations de la BDD
docker exec -it redmine-app bundle exec rake db:migrate RAILS_ENV=production

# Charger les données par défaut de Redmine (création des tables dans la BDD)
docker exec -it redmine-app bundle exec rake redmine:load_default_data RAILS_ENV=production REDMINE_LANG=en

# Voir les logs
docker-compose logs -f redmine

# Accéder au shell du conteneur
docker exec -it redmine-app /bin/bash

# Console Rails
docker exec -it redmine-app rails console

# Redémarrer les services
docker-compose restart

# Arrêter les services
docker-compose down

# Arrêter et supprimer les volumes (ATTENTION: perte de données!)
docker-compose down -v

# Voir l'utilisation des ressources
docker stats

# Nettoyer le cache Redmine
docker exec redmine-app bundle exec rake tmp:clear
```

## 📊 Monitoring

### Santé des services

```bash
# Vérifier l'état des conteneurs
docker-compose ps

# Vérifier la santé de PostgreSQL
docker exec redmine-postgres pg_isready -U redmine

# Vérifier la santé de Redmine
curl -I http://localhost:3000
```

### Logs

Les logs sont disponibles via Docker:
- Logs Redmine: `docker-compose logs -f redmine`
- Logs PostgreSQL: `docker-compose logs -f postgres`
- Logs Nginx (prod): `docker-compose logs -f nginx`

## 🚨 Dépannage

### Problèmes courants

**1. Erreur de connexion à la base de données**
```bash
# Vérifier que PostgreSQL est démarré
docker-compose ps postgres

# Vérifier les logs
docker-compose logs postgres
```

**2. Erreur de permission sur les fichiers**
```bash
# Corriger les permissions
docker exec redmine-app chown -R redmine:redmine /usr/src/redmine/files
```

**3. Plugins ne se chargent pas**
```bash
# Migrer les plugins manuellement
docker exec redmine-app bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

**4. Assets non compilés (production)**
```bash
# Recompiler les assets
docker exec redmine-app bundle exec rake assets:precompile RAILS_ENV=production
```

## 📈 Optimisation des performances

### PostgreSQL

Ajoutez ces paramètres dans docker-compose pour optimiser PostgreSQL:

```yaml
postgres:
  command: >
    postgres
    -c shared_buffers=256MB
    -c effective_cache_size=1GB
    -c maintenance_work_mem=64MB
    -c checkpoint_completion_target=0.9
    -c wal_buffers=16MB
```

### Redmine

Pour améliorer les performances de Redmine:

1. Activez la mise en cache dans Administration > Paramètres
2. Utilisez un serveur de cache (Redis/Memcached)
3. Optimisez les requêtes en limitant les résultats affichés

## 🔄 Mise à jour

### Mise à jour de Redmine

```bash
# Sauvegarder d'abord !
./backup.sh

# Mettre à jour l'image
docker-compose pull redmine

# Redémarrer avec la nouvelle version
docker-compose up -d

# Migrer la base de données
docker exec redmine-app bundle exec rake db:migrate RAILS_ENV=production
```

## 📝 Licence

Ce projet de déploiement est fourni sous licence MIT. Redmine lui-même est sous licence GPL v2.

## 🤝 Support

Pour des questions spécifiques à:
- Ce déploiement Docker: Créez une issue sur ce repository
- Redmine: https://www.redmine.org/projects/redmine/boards
- Docker: https://forums.docker.com/

## 📚 Ressources

- [Documentation officielle Redmine](https://www.redmine.org/guide)
- [Redmine sur Docker Hub](https://hub.docker.com/_/redmine)
- [Guide des plugins Redmine](https://www.redmine.org/plugins)
- [API REST Redmine](https://www.redmine.org/projects/redmine/wiki/Rest_api)
