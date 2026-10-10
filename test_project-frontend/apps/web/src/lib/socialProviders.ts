// Static, not fetched from the backend - social login is settings-based (see the backend's
// SOCIALACCOUNT_PROVIDERS), not a DB-backed SocialApp list, so there's nothing to query at
// request time. Resolved once at generation time from the same social_login_providers answer.
// "all" isn't expanded here the way it is in settings.py - a login page with ~90 buttons isn't
// good UX regardless; list the providers you actually want a button for explicitly instead.

// icon: a static URL or local path (from social_login_provider_icons), used only when
// ProviderIcon has no bundled brand icon for this id - see components/app-auth/icons/brands.tsx.
// "" means no icon at all.
export type SocialProvider = { id: string; name: string; icon: string }

// Picks Prettier's own single- vs multi-line array layout at generation time (mirroring its
// printWidth rule) rather than always emitting one entry per line - a short provider list left
// multi-line in the raw output still fails `prettier --check` because Prettier would collapse it.
export const SOCIAL_PROVIDERS: SocialProvider[] = [
  { id: 'google', name: 'Google', icon: '' },
  { id: 'github', name: 'Github', icon: '' },
  { id: 'openid_connect', name: 'Openid Connect', icon: '' },
]
