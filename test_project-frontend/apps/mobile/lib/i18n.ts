import translationEn from './locales/en.json'
import translationTr from './locales/tr.json'
import * as Localization from 'expo-localization'
import i18next from 'i18next'
import { initReactI18next, useTranslation } from 'react-i18next'

// Generated at bake time from cookiecutter's own "languages" answer (see
// hooks/post_gen_project.py) - edit the source there, not this file, to change its shape.
// Editing the locale json files themselves (the actual translations) is fine.

export const SUPPORTED_LANGUAGES = ['en', 'tr'] as const
type Language = (typeof SUPPORTED_LANGUAGES)[number]

function isSupported(code: string): code is Language {
  return (SUPPORTED_LANGUAGES as readonly string[]).includes(code)
}

// The device's own language, restricted to what this app actually ships - overridden once
// a signed-in user's own saved preference loads (see useAuthenticated.ts).
function deviceLanguage(): Language {
  for (const locale of Localization.getLocales()) {
    if (locale.languageCode && isSupported(locale.languageCode)) return locale.languageCode
  }
  return 'en'
}

i18next.use(initReactI18next).init({
  lng: deviceLanguage(),
  fallbackLng: 'en',
  resources: {
    en: { translation: translationEn },
    tr: { translation: translationTr },
  },
  interpolation: { escapeValue: false },
})

export function setLanguage(language: string): void {
  if (isSupported(language) && language !== i18next.language) void i18next.changeLanguage(language)
}

export { useTranslation }
export default i18next
