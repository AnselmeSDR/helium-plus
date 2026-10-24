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

### Nos patches (`patches/helium-plus/`, dans l'ordre)

La logique vit dans nos propres fichiers (`chrome/browser/ui/helium_plus/`,
`chrome/browser/ui/views/helium_plus/`, namespace `helium_plus`) ; les fichiers Chromium ne
reçoivent que des appels d'une ou deux lignes.

1. `tab-state.patch` : `helium_plus::TabState`, état par onglet créé par `TabFeatures::Init`
   (titre personnalisé, URL et titre d'ancrage). Sauvé comme « tab extra data » de session
   (clés `helium_plus.*`) : `SessionService::BuildCommandsForTab` + `AddTabExtraData` à chaque
   changement, `BrowserLiveTabContext::GetExtraDataForTab` pour la réouverture d'onglets ;
   restauré via `CreateRestoredTab` (`StashRestoredData`, repris par le constructeur de
   `TabState`). `TabUIHelper::GetTitle` renvoie le titre personnalisé.
2. `tab-context-menu.patch` : commandes `CommandRenameTab`, `CommandReplaceAnchor`,
   `CommandCloseUngroupedTabs` (fin de `components/tabs/public/tab_context_menu_command.h`),
   déléguées à `helium_plus/tab_commands.cc` ; boîte de renommage dans `views/helium_plus/`.
3. `anchored-tabs.patch` : onglet ancré = épinglé ou groupé. Fermer (× via
   `BrowserTabStripModelDelegate::CloseTab`, Cmd+W via `chrome::CloseTab`) passe par
   `MaybeResetAnchoredTab` en deux temps, comme Arc : s'il a quitté son ancre
   (`TabState::IsDiverged`, nouvelle page ouverte hors redirections, navigations internes et
   rechargements), le bouton est un « − » (`TabCloseButton::SetShowsMinus`, via
   `TabData::anchor_diverged`) qui le ramène à son ancre ; sinon le × le met en veille et la page
   d'accueil du profil s'affiche à sa place (onglet déjà dessus, sinon nouvel onglet) ; les liens ouverts depuis un onglet groupé arrivent après le groupe
   (`TabStripModel::AddTab`) ; à la restauration de session, l'onglet rouvre sur son URL
   d'ancrage, son historique conservé (`ResetNavigationsToAnchor`). Les groupes enregistrés
   (`LocalTabGroupListener::MatchLocalTabToSavedTab`) renavigueraient ensuite vers la dernière URL
   qu'ils ont gardée : `IsAtAnchor` les en empêche. Un onglet en veille sur son ancre est déjà
   « fermé » : sa × est masquée (`IsClosedAnchoredTab`, dans `tab_view_*_layout.cc`).

Textes d'interface : `helium_plus/strings.cc` (français si le navigateur est en français, anglais
sinon), pas de `.grd` pour éviter les gros patches et les recompilations complètes.

## Build

Voir `docs/building.md`. Prérequis machine (déjà faits) : `brew install python@3.13 wget zstd
coreutils readline quilt`, `requests`/`pillow` dans python@3.13, `xcodebuild -runFirstLaunch`
puis `xcodebuild -downloadComponent MetalToolchain`.

Le `python3` par défaut est en 3.15 : forcer la 3.13 avant toute commande de build.
`dev.sh` se source depuis **zsh** (pas bash ni fish) : `set_quilt_vars.sh` déduit le dossier
`patches` de `$0`, faux sous bash → quilt « No series file found ».

```sh
export PATH="$(brew --prefix python@3.13)/libexec/bin:$PATH"
source dev.sh
he setup   # télécharge Chromium et applique les patches (~gros volume disque)
he build
he run     # dossier de données dédié
```

Patches gérés avec `quilt` (`brew install quilt`), depuis `build/src`, en état « merged »
(`he merge` : série complète dans `patches/series.merged`) :

```sh
source devutils/set_quilt_vars.sh && cd build/src   # puis quilt --quiltrc - <commande>
quilt new helium-plus/x.patch && quilt add <fichiers>   # avant de modifier
quilt refresh                                          # enregistre le patch du dessus
```

Pour corriger un patch qui n'est pas au-dessus : `quilt pop` jusqu'à lui, `quilt refresh`,
`quilt push -a` (`refresh -f` mélangerait les changements des patches suivants). `he unmerge`
avant de committer : il range nos patches dans `patches/series`.

Build : ccache obligatoire (`brew install ccache`) : sans lui les en-têtes précompilés plantent
sous Chromium 156 (`missing 'export module' declaration`). `tools/build-local.sh full` lance le
build avec temps restant dans le titre Ghostty ; compiler un seul fichier :
`autoninja -C out/Default ../../chemin/fichier.cc^`.

Mise à jour officielle : Sparkle n'est activé que si `PROD_MACOS_SPARKLE_ED_PUB_KEY` est défini
(`devutils/shared.sh`) ; ne jamais le définir dans notre CI.

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
- Traductions propres (i18n Helium) si les textes de `strings.cc` ne suffisent plus
- Réglages (délais de mise en veille, ancrage au démarrage) dans les paramètres
- CI GitHub pour les builds de release (sans clé Sparkle)

Référence : PR abandonnée [imputnet/helium#1578](https://github.com/imputnet/helium/pull/1578)
(anchored tabs, sur Chromium 148 ; la partie onglets verticaux est à réécrire : Chromium 156 a
remplacé `views/tabs/vertical/*` par `views/tabs/common/`).
