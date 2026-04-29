import { create } from "zustand";
import { persist } from "zustand/middleware";
import { en, zh } from "@snapotter/shared";

export type Locale = "en" | "zh";

const translations = { en, zh } as const;

const USER_LOCALE_KEY = "snapotter-locale-user-set";

interface LocaleStore {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  resolvedLocale: Locale;
  applyServerDefault: (locale: Locale) => void;
}

export const useLocaleStore = create<LocaleStore>()(
  persist(
    (set) => ({
      locale: "en" as Locale,
      resolvedLocale: "en" as Locale,
      setLocale: (locale) => {
        localStorage.setItem(USER_LOCALE_KEY, "1");
        set({ locale, resolvedLocale: locale });
      },
      applyServerDefault: (locale) => {
        if (localStorage.getItem(USER_LOCALE_KEY)) return;
        set({ locale, resolvedLocale: locale });
      },
    }),
    { name: "snapotter-locale" },
  ),
);

export function useTranslation() {
  const locale = useLocaleStore((s) => s.resolvedLocale);
  return translations[locale];
}