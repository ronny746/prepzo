/**
 * Minimal, dependency-free i18n helper.
 *
 * Why: project rule — no user-facing text is hardcoded in components. Every
 * string is looked up by a dot-namespaced key from `src/locales/<lang>.json`.
 * Kept intentionally tiny; swap for a full library (e.g. next-intl) only when
 * a second locale or pluralisation rules are actually required.
 */
import en from "@/locales/en.json";

/** Locales shipped with the app. Add a JSON file and register it here. */
const dictionaries = { en } as const;

export type Locale = keyof typeof dictionaries;
export const DEFAULT_LOCALE: Locale = "en";

/** Walks a nested dictionary by a dot path, returning a string or undefined. */
function lookup(dict: unknown, path: string): string | undefined {
  const value = path.split(".").reduce<unknown>(
    (node, segment) =>
      node && typeof node === "object" ? (node as Record<string, unknown>)[segment] : undefined,
    dict,
  );
  return typeof value === "string" ? value : undefined;
}

/**
 * Translates a key, interpolating `{name}` placeholders from `params`.
 *
 * Falls back to the default locale, then to the key itself, so a missing
 * string is visible in the UI (and in review) instead of rendering blank.
 *
 * @param key    Dot-namespaced key, e.g. `"common.actions.save"`.
 * @param params Values for `{placeholder}` tokens in the string.
 * @param locale Locale to use; defaults to {@link DEFAULT_LOCALE}.
 */
export function t(
  key: string,
  params: Record<string, string | number> = {},
  locale: Locale = DEFAULT_LOCALE,
): string {
  const template =
    lookup(dictionaries[locale], key) ?? lookup(dictionaries[DEFAULT_LOCALE], key) ?? key;
  return template.replace(/\{(\w+)\}/g, (match, name: string) =>
    name in params ? String(params[name]) : match,
  );
}
