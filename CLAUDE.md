# Helium+

Fork perso de [Helium](https://github.com/imputnet/helium-macos) pour macOS : Helium enrichi
(onglets, espaces, mémoire, confort), inspiré d'Arc.

## Dépôts

- GitLab (principal, nom affiché « Helium+ ») : https://gitlab.com/AnselmeSDR/helium-plus
- GitHub (fork de `imputnet/helium-macos`, sert aussi à la CI) : https://github.com/AnselmeSDR/helium-plus
- `origin` : fetch GitLab, push GitLab + GitHub (un `git push` envoie aux deux)
- `upstream` : `imputnet/helium-macos`
- Identité locale : `Anselme SDR <anselme8@icloud.com>`

## Structure

- Ce dépôt = `helium-macos` (build macOS). Le Helium commun est le sous-module `helium-chromium`
  (`imputnet/helium`), **non forké** : on ne le modifie pas.
- Nos fonctionnalités = patches Chromium dans `patches/helium-plus/`, ajoutés en fin de
  `patches/series` (appliqués après tous les patches Helium et macOS).
- Garder chaque patch petit et ciblé, en s'appuyant sur l'existant de Chromium (onglets épinglés,
  groupes, Memory Saver) : chaque ligne modifiée est un conflit potentiel à chaque mise à jour.
- Version Chromium : `helium-chromium/chromium_version.txt`.

## Build

Voir `docs/building.md`. Développement :

```sh
source dev.sh
he setup   # télécharge Chromium et applique les patches (~gros volume disque)
he build
he run     # dossier de données dédié
```

Patches gérés avec `quilt` (`brew install quilt`), depuis `build/src`.

## Mise à jour depuis Helium

```sh
git fetch upstream && git merge upstream/main
git submodule update --init --recursive
```

Puis réappliquer et corriger nos patches (`quilt push -a` dans `build/src`), recompiler.

## Feuille de route

- Anchored tabs : les onglets épinglés et groupés gardent une URL d'origine et y reviennent,
  « Remplacer l'URL ancrée », restauration au démarrage
- Renommer un onglet (titre persistant)
- Vider les onglets non groupés
- Mise en veille automatique : inactivité, RAM saturée, groupe replié, profil en arrière-plan
- Désactiver la mise à jour officielle (Sparkle, `patches/helium/macos/updater/`) pour ne pas être
  remplacé par Helium officiel

Référence : PR abandonnée [imputnet/helium#1578](https://github.com/imputnet/helium/pull/1578)
(anchored tabs, sur Chromium 148 ; la partie onglets verticaux est à réécrire : Chromium 156 a
remplacé `views/tabs/vertical/*` par `views/tabs/common/`).
