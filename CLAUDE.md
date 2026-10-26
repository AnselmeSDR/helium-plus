# Helium+

Personal fork of [Helium](https://github.com/imputnet/helium-macos) for macOS: Helium with extras
(tabs, spaces, memory, comfort), inspired by Arc.

## Repositories

- GitLab (main, displayed name "Helium+"): https://gitlab.com/AnselmeSDR/helium-plus
- GitHub (fork of `imputnet/helium-macos`, also used for CI): https://github.com/AnselmeSDR/helium-plus
- `origin`: fetches from GitLab, pushes to GitLab + GitHub (one `git push` sends to both)
- `upstream`: `imputnet/helium-macos`
- Local identity: `Anselme SDR <anselme8@icloud.com>`

## Structure

- This repository = `helium-macos` (macOS build). The shared Helium code is the `helium-chromium`
  submodule (`imputnet/helium`), **not forked**: we don't modify it.
- Our features = Chromium patches in `patches/helium-plus/`, added at the end of `patches/series`
  (applied after all Helium and macOS patches).
- Keep each patch small and focused, building on what Chromium already has (pinned tabs, groups,
  Memory Saver): every modified line is a potential conflict on each update.
- Chromium version: `helium-chromium/chromium_version.txt`.

### Our patches (`patches/helium-plus/`, in order)

The logic lives in our own files (`chrome/browser/ui/helium_plus/`,
`chrome/browser/ui/views/helium_plus/`, namespace `helium_plus`); Chromium files only get one- or
two-line calls.

1. `tab-state.patch`: `helium_plus::TabState`, per-tab state created by `TabFeatures::Init`
   (custom title, anchor URL and title, "closed" state). Saved as session "tab extra data"
   (`helium_plus.*` keys): `SessionService::BuildCommandsForTab` + `AddTabExtraData` on every
   change, `BrowserLiveTabContext::GetExtraDataForTab` for reopening tabs; restored through
   `CreateRestoredTab` (`StashRestoredData`, picked up by the `TabState` constructor).
   `TabUIHelper::GetTitle` returns the custom title.
2. `tab-context-menu.patch`: commands `CommandRenameTab`, `CommandReplaceAnchor`,
   `CommandCloseUngroupedTabs` (end of `components/tabs/public/tab_context_menu_command.h`),
   delegated to `helium_plus/tab_commands.cc`; rename dialog in `views/helium_plus/`.
3. `anchored-tabs.patch`: anchored tab = pinned or grouped. Closing (× through
   `BrowserTabStripModelDelegate::CloseTab`, Cmd+W through `chrome::CloseTab`) goes through
   `MaybeResetAnchoredTab` in two steps, like Arc: if the tab left its anchor
   (`TabState::IsDiverged`, a new page opened, excluding redirects, in-page navigations and
   reloads), the button is a "−" (`TabCloseButton::SetShowsMinus`, through
   `TabData::anchor_diverged`) that brings it back to its anchor; otherwise × hibernates it and the
   profile's home page shows in its place (a tab already on it, else a new tab); links opened from
   a grouped tab land after the group (`TabStripModel::AddTab`); on session restore, the tab
   reopens on its anchor URL, its history kept (`ResetNavigationsToAnchor`). Saved groups
   (`LocalTabGroupListener::MatchLocalTabToSavedTab`) would then navigate back to the last URL
   they kept: `IsAtAnchor` prevents it. Closed ≠ hibernated: only × closes
   (`TabState::SetClosed`, saved in the session, cleared when the tab is activated); a closed tab
   has no × anymore (`IsClosedAnchoredTab`, through `TabData::anchor_closed`, in
   `tab_view_*_layout.cc`). Automatic hibernation doesn't close.
4. `auto-hibernation.patch`: `helium_plus::HibernationService` (started by `TabState`) hibernates
   the tabs of a collapsed group (5 min), of a background profile (30 min) and, under memory
   pressure, one tab per minute; longer Memory Saver delays (`memory_saver_mode_policy.cc`).
5. `right-aligned-tab-groups.patch`: with the vertical tab strip on the right, the group line and
   indent move to the right (`TabGroupViewLayout::CalculateVerticalLayout`); collapsed strip: only
   the line moves, the icons stay centered.
6. `collapsed-groups.patch`: in vertical mode, like Arc, a collapsed group keeps its open tabs
   visible (active or not closed, hibernated included: `TabGroupView::IsOpenTab`); selecting a tab
   no longer expands its group (`RootTabCollectionNode`) and collapsing a group no longer moves the
   active tab out of it (`TabStripCollectionController::ToggleTabGroupCollapsedState`). The group
   line runs along its open tabs; no chevron in the header (null `collapse_icon_`). Drag and drop:
   a vertical collapsed group stays a target (`UnpinnedTabContainerView::GetTabDragTarget`, links
   included) and doesn't expand when a tab is dropped into it (`TabGroupView::AttachChildView`).
   Hovering the header of a collapsed group opens `helium_plus::GroupTabsPopover`
   (`views/helium_plus/`, instead of the hover card): all the group's tabs, closed ones included,
   a click activates the tab; closed by `views::MouseWatcher` when the mouse leaves the header and
   the bubble. Bubble contents need an opaque background (text rendered with subpixel
   antialiasing, otherwise a DCHECK in `Label`).
7. `customize-toolbar.patch`: the "New tab" option of Customize › Toolbar
   (`prefs::kShowDynamicNewTabButton`, reserved by Helium for the dynamic layout) also hides
   "+ New tab" in the vertical tab strip (`VerticalTabStripBottomContainer`). The "Reset to
   Default" button gets another label: on Mac (titlecase) its French translation is shared with
   the zoom one ("Rétablir le niveau de zoom par défaut"), since Chromium translations are keyed by
   the English text.
8. `rounded-extension-popups.patch`: an extension bubble (`ExtensionPopup`) has rounded corners
   only when "Show a rounded frame around web contents" (`prefs::kHeliumRoundedFrame`) is enabled
   (`set_use_round_corners`, originally `false`: always square). Slow opening: the bubble only
   shows once the page is loaded, and the local build (component build) starts its processes
   slowly: judge on the CI build.
9. `profile-switcher.patch`: one profile = one Arc space (separate cookies and accounts).
   `helium_plus::ProfileSwitcherView` (bottom of the vertical tab strip,
   `vertical_tab_strip_region_view.cc`): one icon per profile, in the Local State
   `profile.profiles_order` order, and two-finger swipe in the strip. Icons at the very bottom
   (flexible empty space above, `AddToTabStrip`), shrunk when the strip is narrow. Vector icon
   instead of the avatar when the profile's Local State entry (`profile.info_cache.<dir>`) has
   `helium_plus_icon`: `game`, `computer`, `home`, `work`, `code` (icons from
   `components/vector_icons`). Each profile keeps its window: `profile_switcher.cc` shows the
   target profile's window with the same size, the same width and collapsed state of the vertical
   tab strip, and hides (without closing) the current one (the width is set on
   `VerticalTabStripStateController`; `VerticalTabStripRegionView::OnCollapseStateChanged` copies
   it into its own `target_collapse_state_`, otherwise it keeps the session one); click on the
   Dock icon: `ShowHiddenBrowserWindow` (`app_controller_mac.mm`). "On startup" setting defaults
   to "Continue where you left off" (`session_startup_pref.cc`): a profile window opened by the
   switcher restores its tabs (`--restore-last-session` only applies at launch). On startup, only
   the last used profile reopens (`ProfileManager::GetLastOpenedProfiles`): the others load when
   switched to, so a single window opens and their tabs and extensions use no memory. "Tracked"
   preferences (`session.restore_on_startup`, extensions…) written by hand into `Preferences` are
   wiped by Chromium (signature in `Secure Preferences`): go through the browser (DevTools
   `Extensions.loadUnpacked`, settings).
10. `tab-import.patch`: `helium_plus::TabImport` (started by `TabState`), with
    `--helium-plus-import=<dir>`: creates in the first window of each profile the tabs from
    `<dir>/<profile dir>.json` (pinned, collapsed groups, loose tabs; format in `tab_import.h`),
    unloaded, anchored and closed like Arc's pinned tabs, then renames the file to `.json.done`.
    Used to import Arc spaces (script outside the repository: plans per space, cookies/passwords
    copied and re-encrypted with the target profile's key; Arc stores part of its encrypted cookies
    as TEXT, not BLOB).
11. `shared-settings.patch`: `helium_plus::SharedSettings` (started by `TabState`): like Arc, the
    same settings in every profile. A setting changed in one profile is applied to the other loaded
    profiles and kept in Local State (`helium_plus.shared_settings`, name → value, `null` = default)
    for profiles loaded later. List in `IsSharedSetting()` (prefixes `helium.`, `vertical_tabs.`,
    `browser.theme.`, `intl.`… and explicit names): settings only, not the profile's data
    (history, accounts, site data, extensions, `Web Data` search engines). Adding a setting = adding
    it to the list; a list that is too broad (empty prefixes) also shares the profile's internal
    state.
12. `top-padding.patch`: 3 px gap (`kSplitViewContentInset`) below the toolbar, above the web
    contents (`multi_contents_view.cc`, also in split view in `browser_view_tabbed_layout_impl.cc`)
    and above the vertical tab strip (`kHeliumBasePadding`, `UpdateInteriorMargin`). Don't make the
    toolbar taller: macOS centers the traffic lights on its height.
13. `frame-color.patch`: with vertical tabs, the toolbar (`toolbar_view.cc`), the top container and
    the background around the web contents (`MultiContentsBackgroundView::SetUseFrameTheme`) use the
    "frame" color of the vertical tab strip instead of the "toolbar" color (different with a theme
    like Atom One Dark). The active tab keeps the "toolbar" color, so it stays visible.
14. `closed-tabs.patch`: like Arc, a closed anchored tab uses no memory.
    `helium_plus::ClosedTabsService` (started by `TabState`) turns the closed inactive tabs of a
    container (pinned tabs or a group) into `ClosedTab` entries (URL, title, custom title) kept by a
    neighbor tab (`TabState::closed_before()`/`closed_after()`, tab extra data
    `helium_plus.closed_before`/`closed_after`, split into 32 KB chunks `key.1`, `key.2`… as a
    `SessionCommand` is limited to 64 KB), then deletes their WebContents. A container whose tabs
    are all closed keeps one as a real tab (Chromium deletes empty groups); when a keeper leaves its
    container, its entries go to its former neighbors (`Reconcile`) or to a new carrier tab. The
    vertical strip shows entries in place (`ClosedTabViews` in `TabGroupView` and
    `PinnedTabContainerView`, refreshed through `TabData::closed_tabs_revision`), the group popover
    too; a click reopens the tab in place (`ClosedTabsService::Open`, navigation built without page
    state: a `NavigationEntry` serialized from scratch gets the renderer killed,
    `RFH_INVALID_DOCUMENT_SEQUENCE_NUMBER`). Saved tab groups: once initialized,
    `TabGroupSyncService` matches each restored group with its saved tabs, reopening the missing
    ones (loaded) and closing the extra local ones, so a group is only compacted after
    `OnInitialized` (`AreSavedGroupsConnected`).

UI strings: `helium_plus/strings.cc` (French if the browser is in French, English otherwise), no
`.grd` to avoid large patches and full rebuilds.

## Build

See `docs/building.md`. Machine prerequisites (already done): `brew install python@3.13 wget zstd
coreutils readline quilt`, `requests`/`pillow` in python@3.13, `xcodebuild -runFirstLaunch` then
`xcodebuild -downloadComponent MetalToolchain`.

The default `python3` is 3.15: force 3.13 before any build command.
`dev.sh` must be sourced from **zsh** (not bash or fish): `set_quilt_vars.sh` derives the `patches`
directory from `$0`, which is wrong under bash → quilt "No series file found".

```sh
export PATH="$(brew --prefix python@3.13)/libexec/bin:$PATH"
source dev.sh
he setup   # downloads Chromium and applies the patches (~large disk usage)
he build
he run     # dedicated data directory
```

Patches are managed with `quilt` (`brew install quilt`), from `build/src`, in "merged" state
(`he merge`: full series in `patches/series.merged`):

```sh
source devutils/set_quilt_vars.sh && cd build/src   # then quilt --quiltrc - <command>
quilt new helium-plus/x.patch && quilt add <files>    # before editing
quilt refresh                                         # saves the top patch
```

To fix a patch that isn't on top: `quilt pop` down to it, `quilt refresh`, `quilt push -a`
(`refresh -f` would mix in the changes of the following patches). `he unmerge` before committing:
it puts our patches back into `patches/series`.

Build: ccache is required (`brew install ccache`): without it, precompiled headers fail under
Chromium 156 (`missing 'export module' declaration`). `tools/build-local.sh full` runs the build
with the remaining time in the Ghostty title; to compile a single file:
`autoninja -C out/Default ../../path/file.cc^`.

Official updates: Sparkle is only enabled when `PROD_MACOS_SPARKLE_ED_PUB_KEY` is defined
(`devutils/shared.sh`); never define it in our CI: Helium+ must not update itself to the official
Helium.

## Updating from Helium

GitHub Actions routine, every other Saturday at 3:00 UTC (even ISO week; the build takes about
14 h), can be run by hand:
1. `helium-plus-update.yml` → `.github/helium-plus/update.sh`: if there is a new Helium version,
   branch `update/<version>`, merge of `upstream/main`, Chromium sources, `quilt push -a`. Git
   conflicts or patches that no longer apply: Claude Code (`claude -p`, instructions in
   `.github/helium-plus/resolve-conflicts.md`, secret `CLAUDE_CODE_OAUTH_TOKEN`). Then a PR to
   `main` and the build starts; on failure, an issue.
2. `helium-plus-build.yml`: arm64 build through `building.yml` (Helium's), unsigned
   (`github_prepare_artifacts.sh` skips the certificate and Sparkle deltas without
   `MACOS_CERTIFICATE`), published as a pre-release, comment on the PR (GitHub notification).
3. Local validation, after testing the app: merge the branch into `main` and push
   (`git fetch github update/<version>`, remote `github` = GitHub read-only), which closes the PR.
   To rebuild locally afterwards: `he reset` then `he setup` if Chromium changed version.

By hand:

```sh
git fetch upstream && git merge upstream/main
git submodule update --init --recursive
```

Then reapply and fix our patches (`quilt push -a` in `build/src`), rebuild.

## Roadmap

- Anchored tabs: pinned and grouped tabs keep an original URL and go back to it, "Replace anchored
  URL", restore on startup
- Rename a tab (persistent title)
- Clear ungrouped tabs
- Automatic hibernation: inactivity, full RAM, collapsed group, background profile
- Proper translations (Helium i18n) if the `strings.cc` strings are no longer enough
- Settings (hibernation delays, anchoring on startup) in the settings page

Reference: abandoned PR [imputnet/helium#1578](https://github.com/imputnet/helium/pull/1578)
(anchored tabs, on Chromium 148; the vertical tabs part must be rewritten: Chromium 156 replaced
`views/tabs/vertical/*` with `views/tabs/common/`).
