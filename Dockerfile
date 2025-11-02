FROM redmine:5.1-alpine

# Installation de dépendances supplémentaires si nécessaire
RUN apk add --no-cache \
    imagemagick \
    tzdata \
    git \
    build-base \
    postgresql-client

# Configuration du fuseau horaire
ENV TZ=Europe/Paris
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Copier la configuration database
COPY config/database.yml /usr/src/redmine/config/database.yml

# Configuration pour l'envoi d'emails (créez configuration.yml si nécessaire)
# COPY configuration.yml /usr/src/redmine/config/

# Installation de plugins populaires (exemples)
WORKDIR /usr/src/redmine/plugins

# Plugin Agile (gestion de projet agile)
# RUN git clone https://github.com/redmineup/redmine_agile.git

# Plugin CKEditor (éditeur WYSIWYG)
# RUN git clone https://github.com/a-ono/redmine_ckeditor.git

# Plugin Drawio (diagrammes)
# RUN git clone https://github.com/mikitex70/redmine_drawio.git

WORKDIR /usr/src/redmine

# Installation des dépendances des plugins
RUN bundle install --without development test

# Copie de thèmes personnalisés (si vous en avez)
# COPY themes/* /usr/src/redmine/public/themes/

# Script d'initialisation personnalisé
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["rails", "server", "-b", "0.0.0.0"]
