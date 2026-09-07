// WEB_CATALOGS is generated from the same English/Chinese catalogs used by Godot.
function normalizeWebLocale(value) {
  const locale = String(value || '').replaceAll('_', '-').toLowerCase();
  if (locale === 'zh' || /^zh-(cn|sg|hans)/.test(locale)) return 'zh-CN';
  if (locale.startsWith('en')) return 'en';
  return null;
}
function selectWebLocale(search, storage, language) {
  const explicit = normalizeWebLocale(new URLSearchParams(search).get('locale'));
  if (explicit) return explicit;
  try {
    const saved = normalizeWebLocale(storage?.getItem('proto-scroller.locale'));
    if (saved) return saved;
  } catch { /* Browser storage may be disabled. */ }
  return normalizeWebLocale(language) || 'en';
}
let webLocale = selectWebLocale(window.location.search, {
  getItem: key => window.localStorage.getItem(key)
}, window.navigator.language);
window.protoScrollerLocale = webLocale;
document.documentElement.lang = webLocale;
window.protoScrollerSetLocale = function(locale, automatic = false) {
  webLocale = normalizeWebLocale(locale) || 'en';
  window.protoScrollerLocale = webLocale;
  document.documentElement.lang = webLocale;
  try {
    if (automatic) window.localStorage.removeItem('proto-scroller.locale');
    else window.localStorage.setItem('proto-scroller.locale', webLocale);
  } catch { /* Gameplay and localization work without writable storage. */ }
};
function webT(key, values = {}) {
  const text = WEB_CATALOGS[webLocale]?.[key] ?? WEB_CATALOGS.en[key] ?? key;
  return text.replace(/\{(\w+)\}/g, (match, name) => String(values[name] ?? match));
}
