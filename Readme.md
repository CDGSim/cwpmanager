# CWPManager

CWPManager est un gestionnaire de position de contrôle pour le simulateur approche de CDG.
Il permet de configurer et basculer des positions ODS et AMAN pour les ratacher à une branche de simulation (exercise group).

Il se présente sous la forme d'un serveur web HTTP. Différentes routes permettent de déclencher l'exécution de commandes SSH sur les machines ODS et AMAN.

## Gestion courante
### Compilation

Le serveur peut être compilé à l'aide de Docker. Le Dockerfile contient la définition d'une image nommée `build` qui permet de compiler le code au sein d'un conteneur.

L'image finale récupère l'exécutable compilé depuis `build`, et lance l'application en exposant le port 8080.

Pour compiler le serveur, utiliser : `docker-compose build`

### Lancement et arrêt du serveur

Le lancement se fait via Docker. Il faut au préalable définir une variable d'environnement `CONFIG` contenant les paramètres du serveur. Pour lancer le serveur, en définissant cette variable d'environnment, utiliser : `CONFIG=$(cat config.json) docker-compose up -d app`.

Cette commande lance le serveur en mode détaché. Vous pouvez afficher les conteneurs Docker en cours d'exécution avec `docker ps`.

Pour stopper un conteneur, utiliser `docker stop nom_du_conteneur`.

Pour afficher les logs d'un conteneur, utiliser `docker logs nom_du_conteneur`.

## Fonctionnement
### Routes du serveur HTTP

Les clients agissent avec le serveur via les routes suivantes.

| **Méthode** | **URL** | **Paramètres** | **Action** |
|---|---|---|---|
| GET | / | - | Affiche une représentation des positions de contrôle. Peut être utilisé pour afficher rapidement l'état du serveur via un navigateur web. |
| WebSocket | /distribution | - | Permet l'envoi et la réception d'une représentation des positions de contrôle. Tout changement détecté entraine la reconfiguration des positions ODS correspondantes. |
| POST | /restartAMAN/branchID | branchID : identifiant de la branche concernée | Redémarre une branche AMAN correspondante, en utilisant les rôles de chaque position de contrôle. |
| POST | /stopAMAN/branchID | branchID : identifiant de la branche concernée | Arrête la branche AMAN correspondante. |
| GET | /didSetODS/positionName/branch/branchID | branchID : identifiant de la branche concernée | Permet au serveur de suivre les modifications apportées. |
