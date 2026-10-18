# TrackMyThings

App iPhone minimaliste pour noter en deux touches qu'une tâche récurrente a été faite
(prise de statine, charge de la voiture…) et recevoir une alerte si elle ne l'a pas été
à temps.

## Fonctionnement

### Utilisation

1. Touchez l'icône de l'app.
2. Touchez l'événement, par exemple 💊 Statine, puis confirmez.
3. L'événement est enregistré à la date et à l'heure actuelles, puis l'app se ferme toute seule.

Chaque bouton indique depuis combien de temps l'événement a été fait. Il passe **en rouge** en cas de retard.

### L'app

- **Écran principal** : un gros bouton par événement. Après un appui, une confirmation s'affiche. Une fois l'événement enregistré, l'app se ferme toute seule (réglable).
- **✍️ Entrée manuelle** (écran principal et journal) : choisir un type d'événement et une date et heure passées, par exemple pour un oubli.
- **Journal** :
  - tous les événements de tous les types, regroupés par jour, avec un filtre par type ;
  - l'état de chaque type (dernière fois, nombre de fois sur 30 jours, retard) ;
  - toucher une entrée pour changer son heure, sa date ou son type, ou la supprimer ;
  - suppression aussi par glissement ;
  - export CSV (bouton partager).
- **Réglages** (⚙️) :
  - ajouter, modifier ou supprimer des types d'événements (nom, emoji, fréquence en heures, jours ou semaines) ;
  - changer leur ordre : bouton **Réordonner**, puis glisser les poignées ≡ ;
  - activer ou désactiver la confirmation et la fermeture automatique.

### Événements automatiques

Certains événements n'ont pas besoin de confirmation, par exemple 🗑️ Sortir les poubelles.
Dans ⚙️ Réglages › le type › **Validation**, choisissez **Automatique**, puis réglez :

- la **première échéance**, par exemple mardi 20:00 ;
- la **fréquence**, par exemple 1 semaine.

À chaque échéance, l'entrée est ajoutée au journal toute seule, à l'heure prévue. Si l'app est fermée, elle est ajoutée à la prochaine ouverture, avec la bonne date.
Une notification peut signaler chaque échéance. Si ça n'a pas été fait, supprimez l'entrée dans le journal : elle ne sera pas recréée.

### Alertes

Pour chaque type dont l'alerte est activée, une notification locale est programmée à l'échéance (dernière fois + fréquence).
Elle est relancée à +2 h, +6 h, +1 j, +2 j et +3 j. Le bouton **« ✓ Fait maintenant »** de la notification enregistre l'événement sans ouvrir l'app.
Tout fonctionne en local, sans serveur ni compte.

> Pour une prise quotidienne dont l'heure varie un peu, une fréquence de 26 heures évite les alertes inutiles.

### Sauvegarde sur GitHub

Après chaque modification (enregistrement, suppression, réglage), l'app envoie tout son contenu, c'est-à-dire les types d'événements, le journal et les réglages, dans le fichier `trackmythings.json` d'un dépôt GitHub privé. Si le téléphone est hors ligne, elle le fait au lancement suivant.

GitHub garde chaque version, donc on peut revenir à n'importe quel jour.

Avant chaque envoi, l'app fusionne la sauvegarde avec ce qu'elle a. Après une réinstallation, il suffit de renseigner à nouveau le jeton : l'historique revient tout seul, sans doublons. Les entrées supprimées ne réapparaissent pas.

**Créer le jeton d'accès** (sur github.com, depuis un navigateur) :

1. Cliquez sur votre photo de profil › **Settings** › **Developer settings** (tout en bas à gauche) › **Personal access tokens** › **Fine-grained tokens** › **Generate new token**.
2. Remplissez :
   - **Token name** : `TrackMyThings iPhone` ;
   - **Expiration** : la durée la plus longue proposée. Notez la date : il faudra recréer un jeton à l'expiration ;
   - **Repository access** : **Only select repositories**, puis `trackmythings-data` ;
   - **Permissions** › **Repository permissions** › **Contents** : **Read and write**. « Metadata : Read-only » s'ajoute tout seul.
3. Cliquez sur **Generate token**, puis copiez le jeton, qui commence par `github_pat_`. Il n'est affiché qu'une seule fois.

**Dans l'app**, ouvrez ⚙️ Réglages › **Sauvegarde GitHub** :

1. Vérifiez le dépôt : `pierrebiz/trackmythings-data`.
2. Collez le jeton.
3. Touchez **Enregistrer et synchroniser**. La ligne verte « Dernière sauvegarde » confirme que ça fonctionne.

Le jeton est rangé dans le trousseau sécurisé de l'iPhone. Il ne donne accès qu'au dépôt de sauvegarde.

## Installation sans l'App Store

### 1. Récupérer l'IPA (le fichier d'installation)

À chaque modification du code, GitHub compile l'app sur un Mac.

1. Sur GitHub, ouvrez l'onglet **Actions**, puis le dernier run **Build** marqué ✓.
2. En bas de la page, téléchargez l'artefact **TrackMyThings-ipa**.
3. Dézippez-le pour obtenir `TrackMyThings.ipa`.

L'outil d'installation signe l'app avec votre Apple ID.

### 2. L'installer avec un Apple ID gratuit, sans Mac

Deux outils au choix.

**Sideloadly (PC Windows, le plus simple)**

1. Installez [Sideloadly](https://sideloadly.io) et iTunes, la version téléchargée depuis le site d'Apple, pas celle du Microsoft Store.
2. Branchez l'iPhone en USB, puis glissez `TrackMyThings.ipa` dans Sideloadly.
3. Entrez votre Apple ID et cliquez sur **Start**.
4. **Tous les 7 jours**, recommencez l'étape 3, sinon l'app ne s'ouvre plus. Vos données sont conservées.

**SideStore (renouvellement depuis l'iPhone, sans ordinateur après l'installation)**

1. Suivez le guide d'installation de [SideStore](https://docs.sidestore.io). Il faut un ordinateur (Windows, Linux ou Mac) une seule fois, pour créer le fichier d'appairage.
2. Copiez `TrackMyThings.ipa` dans l'app Fichiers de l'iPhone. Dans SideStore, ouvrez **My Apps**, touchez **+** et choisissez le fichier.
3. Les 7 jours se renouvellent depuis SideStore, sur l'iPhone, sans ordinateur.

AltStore Classic (avec AltServer sur PC) fonctionne aussi.

### 3. Sur l'iPhone

1. Activez le **Mode développeur** : Réglages › Confidentialité et sécurité › Mode développeur. L'iPhone redémarre ; confirmez ensuite avec **Activer**.
2. Faites confiance au certificat : Réglages › Général › VPN et gestion de l'appareil › votre Apple ID › Faire confiance.
3. Lancez l'app une fois et acceptez les notifications.

### Limites d'un Apple ID gratuit

- Il faut renouveler l'app **tous les 7 jours**.
- 3 apps installées ainsi au maximum, SideStore compris.
- 10 identifiants d'app par semaine. TrackMyThings en utilise 1.

### Avec un Mac (alternative)

1. Dans `project.yml`, renseignez `DEVELOPMENT_TEAM`.
2. Lancez :
   ```sh
   brew install xcodegen && xcodegen && open TrackMyThings.xcodeproj
   ```
3. Faites ▶︎ Run sur l'iPhone branché.

## Structure

```
project.yml                 Description du projet (XcodeGen)
App/
  TrackMyThingsApp.swift    Point d'entrée, navigation, actions des notifications
  QuickLogView.swift        Écran principal (un bouton par événement)
  LogView.swift             Journal, ajout manuel, export CSV
  SettingsView.swift        Réglages et édition des types d'événements
  AppModel.swift            État de l'app
  Models.swift              Types d'événements, entrées, réglages
  Store.swift               Stockage JSON + action « enregistrer »
  ReminderScheduler.swift   Notifications de retard
```
