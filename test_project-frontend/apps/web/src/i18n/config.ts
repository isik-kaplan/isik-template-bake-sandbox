import authEn from '../locales/en/auth.json'
import commonEn from '../locales/en/common.json'
import legalEn from '../locales/en/legal.json'
import notFoundEn from '../locales/en/notFound.json'
import themeToggleEn from '../locales/en/themeToggle.json'
import authTr from '../locales/tr/auth.json'
import commonTr from '../locales/tr/common.json'
import legalTr from '../locales/tr/legal.json'
import notFoundTr from '../locales/tr/notFound.json'
import themeToggleTr from '../locales/tr/themeToggle.json'
import type { InitOptions, TFunction } from 'i18next'

// Generated at bake time from cookiecutter's own "languages" answer (see
// hooks/post_gen_project.py) - edit the source there, not this file, to change its shape.
// Editing the locale json files themselves (the actual translations) is fine.

export const languages = ['en', 'tr'] as const
export const namespaces = ['auth', 'common', 'legal', 'notFound', 'themeToggle'] as const

export type Language = (typeof languages)[number]
export type Namespace = (typeof namespaces)[number]

export const resources = {
  en: {
    auth: authEn,
    common: commonEn,
    legal: legalEn,
    notFound: notFoundEn,
    themeToggle: themeToggleEn,
  },
  tr: {
    auth: authTr,
    common: commonTr,
    legal: legalTr,
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

// What a function handed `t` should take - see i18next.d.ts for what makes its keys checked.
export type Translate = TFunction<Namespace[]>
