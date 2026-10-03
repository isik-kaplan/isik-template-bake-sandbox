import authEn from '../locales/en/auth.json'
import notFoundEn from '../locales/en/notFound.json'
import themeToggleEn from '../locales/en/themeToggle.json'
import authTr from '../locales/tr/auth.json'
import notFoundTr from '../locales/tr/notFound.json'
import themeToggleTr from '../locales/tr/themeToggle.json'
import type { InitOptions } from 'i18next'

// Generated at bake time from cookiecutter's own "languages" answer (see
// hooks/post_gen_project.py) - edit the source there, not this file, to change its shape.
// Editing the locale json files themselves (the actual translations) is fine.

export const languages = ['en', 'tr'] as const
export const namespaces = ['auth', 'notFound', 'themeToggle'] as const

export type Language = (typeof languages)[number]
export type Namespace = (typeof namespaces)[number]

const resources = {
  en: {
    auth: authEn,
    notFound: notFoundEn,
    themeToggle: themeToggleEn,
  },
  tr: {
    auth: authTr,
    notFound: notFoundTr,
    themeToggle: themeToggleTr,
  },
} as const

export function getConfig(ns?: Namespace[], lng: Language = 'en'): InitOptions {
  return {
    fallbackLng: 'en',
    lng,
    ns: ns ?? namespaces,
    resources,
    // i18next escapes interpolated values by default, which React then renders literally.
    interpolation: { escapeValue: false },
  }
}
