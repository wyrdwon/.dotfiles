// user.js — LibreWolf profile configuration
// Generated from prefs.js diff against vanilla baseline.
// Intentional overrides only; ephemeral state stripped.
// Deploy to: $LIBREWOLF_PROFILE/user.js
// These take effect on next browser launch and override prefs.js at runtime.

// =============================================================================
// UI / APPEARANCE
// =============================================================================

// Vertical tabs enabled; sidebar expands on hover
user_pref('sidebar.verticalTabs', true)
user_pref('sidebar.revamp', true)
user_pref('sidebar.visibility', 'expand-on-hover')
user_pref('sidebar.animation.enabled', false)
user_pref('sidebar.verticalTabs.dragToPinPromo.dismissed', true)

// Bookmarks toolbar never shown (relying on sidebar/vertical tab setup)
user_pref('browser.toolbars.bookmarks.visibility', 'never')

// Fullscreen: don't autohide toolbars
user_pref('browser.fullscreen.autohide', false)

// Tab hover preview thumbnails off
user_pref('browser.tabs.hoverPreview.showThumbnails', false)

// Title bar integrated (no separate title bar)
user_pref('browser.tabs.inTitlebar', 1)

// Linux rounded corners
user_pref('widget.gtk.rounded-bottom-corners.enabled', true)

// Find bar: don't flash the bar on typeahead find
user_pref('accessibility.typeaheadfind.flashBar', 0)

// Spellcheck off
user_pref('layout.spellcheckDefault', 0)

// SVG context properties (required by some themes/extensions)
user_pref('svg.context-properties.content.enabled', true)

// Enable userChrome.css / userContent.css
user_pref('toolkit.legacyUserProfileCustomizations.stylesheets', true)

// =============================================================================
// PRIVACY / FINGERPRINTING
// =============================================================================

// Letterboxing (RFP): pad viewport to standard sizes to resist fingerprinting
user_pref('privacy.resistFingerprinting.letterboxing', true)

// Disable timer precision jitter (explicit choice alongside RFP)
user_pref('privacy.resistFingerprinting.reduceTimerPrecision.jitter', false)

// Spoof English language to resist language-based fingerprinting
user_pref('privacy.spoof_english', 2)

// =============================================================================
// PRIVACY / HISTORY & CLEARING
// =============================================================================

// Clear cache and cookies/storage on shutdown
// (encoded as sanitize.pending; also set explicitly via UI)
user_pref(
	'privacy.sanitize.pending',
	'[{"id":"shutdown","itemsToClear":["cache","cookiesAndStorage"],"options":{}},{"id":"newtab-container","itemsToClear":[],"options":{}}]'
)

// Clear form data in history and site data dialogs
user_pref('privacy.clearHistory.formdata', true)
user_pref('privacy.clearSiteData.formdata', true)
user_pref('privacy.clearSiteData.siteSettings', true)

// =============================================================================
// NETWORK
// =============================================================================

// Disable DNS prefetching / network predictor
user_pref('network.predictor.enabled', false)

// DNS-over-HTTPS mode: 0 = off (using system resolver / VPN resolver)
user_pref('network.trr.mode', 0)

// =============================================================================
// PERFORMANCE / GRAPHICS
// =============================================================================

// Disable hardware video decoding (workaround, likely AMD driver issue on WSL2)
// Review when migrating to native Arch.
user_pref('layers.acceleration.disabled', true)

// =============================================================================
// BROWSER ML / AI FEATURES
// =============================================================================

// Disable ML link preview (Nightly/experimental feature)
user_pref('browser.ml.linkPreview.enabled', false)

// =============================================================================
// GEOLOCATION
// =============================================================================

// Deny geolocation by default (2 = block)
user_pref('permissions.default.geo', 2)

// =============================================================================
// LOCALE
// =============================================================================

user_pref('intl.accept_languages', 'en-US, en')
user_pref('intl.locale.requested', 'en-US')

// =============================================================================
// AUTO-TRANSLATION
// =============================================================================

// Languages to always auto-translate
user_pref('browser.translations.alwaysTranslateLanguages', 'ru,ja,nl,fi')
user_pref('browser.translations.mostRecentTargetLanguages', 'en')

// =============================================================================
// CONTAINERS
// =============================================================================

// Multi-Account Containers: bind container management to Tree Style Tab
user_pref('privacy.userContext.extension', 'treestyletab@piro.sakura.ne.jp')

// =============================================================================
// EXTENSIONS / SIDEBAR TOOLS
// =============================================================================

// Sidebar extension integrations (Tree Style Tab, Simple Tab Groups)
user_pref(
	'sidebar.installed.extensions',
	'{446900e4-71c2-419f-a6a7-df9c091e268b},simple-tab-groups@drive4ik,treestyletab@piro.sakura.ne.jp'
)
user_pref(
	'sidebar.main.tools',
	'history,simple-tab-groups@drive4ik,bookmarks,treestyletab@piro.sakura.ne.jp'
)
