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

Il faut un **Mac avec Xcode 16 ou plus** et un **compte Apple**.

1. Installez Xcode depuis le Mac App Store, puis XcodeGen :
   ```sh
   brew install xcodegen
   ```
2. Clonez ce dépôt, puis éditez `project.yml` :
   - `DEVELOPMENT_TEAM` : votre Team ID (Xcode › Settings › Accounts, ajoutez votre Apple ID ; l'identifiant est affiché sur l'équipe) ;
   - si Xcode refuse les identifiants (« not available »), changez `BASE_BUNDLE_ID` et `APP_GROUP_ID` (ex. `fr.pierre.trackmythings` et `group.fr.pierre.trackmythings`).
3. Générez le projet et ouvrez-le :
   ```sh
   xcodegen
   open TrackMyThings.xcodeproj
   ```
4. Branchez l'iPhone, sélectionnez-le comme destination, puis faites **▶︎ Run**.
5. Sur l'iPhone :
   - activez le **Mode développeur** (Réglages › Confidentialité et sécurité), puis faites confiance au profil (Réglages › Général › VPN et gestion de l'appareil) ;
   - lancez l'app une fois et acceptez les notifications ;
   - ajoutez le widget : appui long sur l'écran d'accueil › **Modifier** › **Ajouter un widget** › TrackMyThings.

### Compte gratuit ou payant ?

| | Apple ID gratuit | Apple Developer Program (99 €/an) |
|---|---|---|
| Durée de validité de l'app | **7 jours**, puis il faut refaire ▶︎ Run depuis le Mac (les données sont conservées) | 1 an |
| App Group (partage des données app ↔ widget) | Ça marche souvent, mais Apple ne le garantit pas | Oui |

Si l'App Group n'est pas disponible, l'app fonctionne quand même, mais le widget ne voit pas ses données. Un avertissement s'affiche alors dans Réglages.

### Sans Mac (expérimental)

GitHub Actions compile l'app à chaque push. L'IPA non signée, signée en *ad-hoc* avec l'App Group, est disponible dans l'artefact `TrackMyThings-ipa` du workflow **Build**.
On peut l'installer avec [Sideloadly](https://sideloadly.io) ou AltStore, avec un Apple ID.
Ces outils peuvent renommer l'App Group : dans ce cas, le widget ne verra pas les données. Le chemin Xcode est plus fiable.

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
