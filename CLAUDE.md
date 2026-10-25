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
   (titre personnalisé, URL et titre d'ancrage, état « fermé »). Sauvé comme « tab extra data » de session
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
   d'accueil du profil s'affiche à sa place (onglet déjà dessus, sinon nouvel onglet) ; les liens
   ouverts depuis un onglet groupé arrivent après le groupe (`TabStripModel::AddTab`) ; à la restauration de session, l'onglet rouvre sur son URL
   d'ancrage, son historique conservé (`ResetNavigationsToAnchor`). Les groupes enregistrés
   (`LocalTabGroupListener::MatchLocalTabToSavedTab`) renavigueraient ensuite vers la dernière URL
   qu'ils ont gardée : `IsAtAnchor` les en empêche. Un onglet en veille sur son ancre est déjà
   Fermé ≠ en veille : seule la × ferme (`TabState::SetClosed`, enregistré dans la session,
   effacé quand l'onglet est activé) ; un onglet fermé n'a plus de × (`IsClosedAnchoredTab`, via
   `TabData::anchor_closed`, dans `tab_view_*_layout.cc`). La veille automatique ne ferme pas.
4. `auto-hibernation.patch` : `helium_plus::HibernationService` (démarré par `TabState`) met en
   veille les onglets d'un groupe replié (5 min), d'un profil en arrière-plan (30 min) et, sous
   pression mémoire, un onglet par minute ; délais de Memory Saver allongés
   (`memory_saver_mode_policy.cc`).
5. `right-aligned-tab-groups.patch` : barre verticale à droite, le trait et le retrait des groupes
   passent à droite (`TabGroupViewLayout::CalculateVerticalLayout`) ; barre réduite : seul le trait
   bouge, les icônes restent centrées.
6. `collapsed-groups.patch` : en vertical, comme Arc, un groupe replié garde visibles ses onglets
   ouverts (actif ou non fermés, en veille compris : `TabGroupView::IsOpenTab`) ; sélectionner un onglet ne déplie plus son
   groupe (`RootTabCollectionNode`) et replier un groupe n'en fait plus sortir l'onglet actif
   (`TabStripCollectionController::ToggleTabGroupCollapsedState`). Le trait du groupe longe ses
   onglets ouverts ; pas de chevron dans l'en-tête (`collapse_icon_` nul). Survoler l'en-tête
   d'un groupe replié ouvre `helium_plus::GroupTabsPopover` (`views/helium_plus/`, à la place de
   la carte de survol) : tous les onglets du groupe, fermés compris, un clic active l'onglet ;
   fermé par `views::MouseWatcher` quand la souris quitte l'en-tête et la bulle. Le contenu d'une
   bulle doit avoir un fond opaque (texte en rendu sous-pixel, sinon DCHECK dans `Label`).
7. `customize-toolbar.patch` : l'option « Nouvel onglet » de Personnaliser › Barre d'outils
   (`prefs::kShowDynamicNewTabButton`, réservée par Helium à la disposition dynamique) masque aussi
   « + Nouvel onglet » de la barre verticale (`VerticalTabStripBottomContainer`). Le bouton
   « Reset to Default » prend un autre libellé : sur Mac (titlecase) sa traduction est partagée
   avec le zoom (« Rétablir le niveau de zoom par défaut »), les traductions Chromium étant
   indexées par le texte anglais.
8. `rounded-extension-popups.patch` : la bulle d'une extension (`ExtensionPopup`) n'a des coins
   arrondis que si l'option « Show a rounded frame around web contents »
   (`prefs::kHeliumRoundedFrame`) est activée (`set_use_round_corners`, à `false` d'origine :
   bulle toujours carrée). Lenteur d'ouverture : la bulle n'apparaît qu'une fois la page chargée, et le
   build local (component build) démarre ses processus lentement : juger sur le build CI.
9. `profile-switcher.patch` : un profil = un espace Arc (cookies et comptes séparés).
   `helium_plus::ProfileSwitcherView` (bas de la barre verticale, `vertical_tab_strip_region_view.cc`) :
   une icône par profil, dans l'ordre `profile.profiles_order` de Local State, et balayage à deux
   doigts dans la barre. Icônes tout en bas (espace vide extensible au-dessus, `AddToTabStrip`),
   rétrécies si la barre est étroite. Icône vectorielle à la place de l'avatar si l'entrée du
   profil dans Local State (`profile.info_cache.<dossier>`) a `helium_plus_icon` : `game`,
   `computer`, `home`, `work`, `code` (icônes de `components/vector_icons`). Chaque profil garde sa
   fenêtre : `profile_switcher.cc` affiche celle du profil cible aux mêmes dimensions, même largeur
   et état replié de la barre verticale, et masque (sans fermer) l'actuelle (la largeur est posée
   sur `VerticalTabStripStateController` ; `VerticalTabStripRegionView::OnCollapseStateChanged`
   la recopie dans sa propre `target_collapse_state_`, sinon elle garde celle de la session) ; clic sur l'icône du
   Dock : `ShowHiddenBrowserWindow` (`app_controller_mac.mm`). Réglage « Au démarrage » par défaut
   sur « Reprendre » (`session_startup_pref.cc`) : une fenêtre de profil ouverte par la bascule
   restaure ses onglets (`--restore-last-session` ne vaut que pour le lancement). Les préférences
   « suivies » (`session.restore_on_startup`, extensions…) écrites à la main dans `Preferences`
   sont effacées par Chromium (signature dans `Secure Preferences`) : passer par le navigateur
   (DevTools `Extensions.loadUnpacked`, réglages).
10. `tab-import.patch` : `helium_plus::TabImport` (démarré par `TabState`), avec
    `--helium-plus-import=<dossier>` : crée dans la première fenêtre de chaque profil les onglets de
    `<dossier>/<dossier du profil>.json` (épinglés, groupes repliés, onglets libres ; format dans
    `tab_import.h`), non chargés, ancrés et fermés comme les onglets épinglés d'Arc, puis renomme le
    fichier en `.json.done`. Sert à l'import des espaces Arc (script hors dépôt : plans par espace,
    copie des cookies/mots de passe rechiffrés avec la clé du profil cible ; Arc stocke une partie de
    ses cookies chiffrés en TEXT et non en BLOB).
11. `shared-settings.patch` : `helium_plus::SharedSettings` (démarré par `TabState`) : comme Arc,
    mêmes réglages dans tous les profils. Un réglage modifié dans un profil est appliqué aux autres
    profils chargés et gardé dans Local State (`helium_plus.shared_settings`, nom → valeur, `null` =
    défaut) pour les profils chargés plus tard. Liste dans `IsSharedSetting()` (préfixes `helium.`,
    `vertical_tabs.`, `browser.theme.`, `intl.`… et noms explicites) : réglages seulement, pas les
    données du profil (historique, comptes, données de sites, extensions, moteurs de recherche de
    `Web Data`). Ajouter un réglage = l'ajouter à la liste ; une liste trop large (préfixes vides)
    partage aussi l'état interne du profil.

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
(`devutils/shared.sh`) ; ne jamais le définir dans notre CI : Helium+ ne doit pas se mettre à jour
tout seul vers le Helium officiel.

## Mise à jour depuis Helium

Routine GitHub Actions, un samedi sur deux à 3 h UTC (semaine ISO paire ; build d'environ 14 h), lançable à la main :
1. `helium-plus-update.yml` → `.github/helium-plus/update.sh` : s'il y a une nouvelle version de
   Helium, branche `update/<version>`, fusion de `upstream/main`, sources Chromium, `quilt push -a`.
   Conflits git ou patches qui ne s'appliquent plus : Claude Code (`claude -p`, consignes dans
   `.github/helium-plus/resolve-conflicts.md`, secret `CLAUDE_CODE_OAUTH_TOKEN`). Puis PR vers
   `main` et lancement du build ; en cas d'échec, une issue.
2. `helium-plus-build.yml` : build arm64 via `building.yml` (celui de Helium), non signé
   (`github_prepare_artifacts.sh` saute certificat et deltas Sparkle sans `MACOS_CERTIFICATE`),
   publié en pré-release, commentaire sur la PR (notification GitHub).
3. Validation en local, après test de l'app : fusionner la branche dans `main` et pousser
   (`git fetch github update/<version>`, remote `github` = GitHub en lecture), ce qui ferme la PR.
   Pour recompiler en local ensuite : `he reset` puis `he setup` si Chromium a changé de version.

À la main :

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

Référence : PR abandonnée [imputnet/helium#1578](https://github.com/imputnet/helium/pull/1578)
(anchored tabs, sur Chromium 148 ; la partie onglets verticaux est à réécrire : Chromium 156 a
remplacé `views/tabs/vertical/*` par `views/tabs/common/`).
