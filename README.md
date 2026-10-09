# TrackMyThings

App iPhone minimaliste pour noter en deux touches qu'une tâche récurrente a été faite
(prise de statine, charge de la voiture…) et recevoir une alerte si elle ne l'a pas été
à temps.

## Fonctionnement

### Widget de l'écran d'accueil (usage principal)

Le widget interactif (iOS 17 ou plus) affiche un bouton par type d'événement, plus une case **📒 Journal**.

1. Touchez un événement (ex. 💊 Statine). Le widget affiche « Enregistrer maintenant ? ».
2. Touchez ✓. L'événement est enregistré à la date et à l'heure actuelles, puis le widget affiche « ✓ enregistré à 08:12 ».

**L'app ne s'ouvre pas, il n'y a rien à fermer.** Toucher ✗, ou attendre 30 secondes, annule la sélection.
Toucher **📒 Journal** ouvre l'app directement sur le journal.

Chaque case indique depuis combien de temps l'événement a été fait. Elle passe **en rouge** si l'événement est en retard.

Les tailles du widget :

| Taille | Événements affichés |
|--------|---------------------|
| Petit  | 3 |
| Moyen  | 7 |
| Grand  | 11 |

### L'app

- **Écran principal** : un gros bouton par événement. Après un appui, une confirmation s'affiche. Une fois l'événement enregistré, l'app se ferme toute seule (réglable).
- **Journal** :
  - tous les événements de tous les types, regroupés par jour, avec un filtre par type ;
  - l'état de chaque type (dernière fois, nombre de fois sur 30 jours, retard) ;
  - ajout manuel d'une entrée oubliée (bouton +) et suppression par glissement ;
  - export CSV (bouton partager).
- **Réglages** (⚙️) :
  - ajouter, modifier, réordonner ou supprimer des types d'événements (nom, emoji, fréquence en heures, jours ou semaines) ;
  - activer ou désactiver la confirmation et la fermeture automatique.

### Alertes

Pour chaque type dont l'alerte est activée, une notification locale est programmée à l'échéance (dernière fois + fréquence).
Elle est relancée à +2 h, +6 h, +1 j, +2 j et +3 j. Le bouton **« ✓ Fait maintenant »** de la notification enregistre l'événement sans ouvrir l'app.
Tout fonctionne en local, sans serveur ni compte.

> Pour une prise quotidienne dont l'heure varie un peu, une fréquence de 26 heures évite les alertes inutiles.

## Installation sans l'App Store

### 1. Récupérer l'IPA (le fichier d'installation)

À chaque modification du code, GitHub compile l'app sur un Mac.

1. Sur GitHub, ouvrez l'onglet **Actions**, puis le dernier run **Build** marqué ✓.
2. En bas de la page, téléchargez l'artefact **TrackMyThings-ipa**.
3. Dézippez-le pour obtenir `TrackMyThings.ipa`.

L'IPA est pré-signée avec l'App Group, qui permet le partage des données entre l'app et le widget. L'outil d'installation re-signe l'app avec votre Apple ID.

### 2. L'installer avec un Apple ID gratuit, sans Mac

Deux outils au choix.

**Sideloadly (PC Windows, le plus simple)**

1. Installez [Sideloadly](https://sideloadly.io) et iTunes, la version téléchargée depuis le site d'Apple, pas celle du Microsoft Store.
2. Branchez l'iPhone en USB, puis glissez `TrackMyThings.ipa` dans Sideloadly.
3. Entrez votre Apple ID et cliquez sur **Start**.
   - Dans les options avancées, ne cochez **pas** « Remove app extensions » : cela supprimerait le widget.
4. **Tous les 7 jours**, recommencez l'étape 3, sinon l'app ne s'ouvre plus. Vos données sont conservées.

**SideStore (renouvellement depuis l'iPhone, sans ordinateur après l'installation)**

1. Suivez le guide d'installation de [SideStore](https://docs.sidestore.io). Il faut un ordinateur (Windows, Linux ou Mac) une seule fois, pour créer le fichier d'appairage.
2. Copiez `TrackMyThings.ipa` dans l'app Fichiers de l'iPhone. Dans SideStore, ouvrez **My Apps**, touchez **+** et choisissez le fichier.
3. Les 7 jours se renouvellent depuis SideStore, sur l'iPhone, sans ordinateur.

AltStore Classic (avec AltServer sur PC) fonctionne aussi.

### 3. Sur l'iPhone

1. Faites confiance au certificat : Réglages › Général › VPN et gestion de l'appareil › votre Apple ID › Faire confiance.
2. Activez le Mode développeur si iOS le demande : Réglages › Confidentialité et sécurité.
3. Lancez l'app une fois et acceptez les notifications.
4. Ouvrez ⚙️ Réglages › **Partage app ↔ widget**. La ligne doit indiquer **OK**.
5. Ajoutez le widget : appui long sur l'écran d'accueil › **Modifier** › **Ajouter un widget** › TrackMyThings.

### Limites d'un Apple ID gratuit

- Il faut renouveler l'app **tous les 7 jours**.
- 3 apps installées ainsi au maximum, SideStore compris.
- 10 identifiants d'app par semaine. TrackMyThings en utilise 2 : l'app et le widget.

Les outils de sideload renomment l'App Group, par exemple en `group.biz.besnard.trackmythings.ABCDE12345`. L'app retrouve automatiquement le nom réel, via `ALTAppGroups` ou via le profil de provisioning embarqué.

Si **Partage app ↔ widget** indique « Indisponible », l'app fonctionne, mais le widget ne verra pas les enregistrements.

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
Shared/                     Code commun à l'app et au widget
  Models.swift              Types d'événements, entrées, réglages
  Store.swift               Stockage JSON dans l'App Group + action « enregistrer »
  ReminderScheduler.swift   Notifications de retard
  WidgetIntents.swift       Actions des boutons du widget (choisir / confirmer / annuler)
App/                        L'app (écran principal, journal, réglages)
Widget/                     Le widget interactif
```
