import { SOCIAL_PROVIDERS } from '@/lib/socialProviders'

import { describe, expect, it } from 'vitest'

// Rebuilt from the same social_login_providers/social_login_provider_icons cookiecutter answers
// socialProviders.ts itself was generated from - both are frozen at bake time, so this is a real
// independent expected value, not a tautology against the module under test.
describe('SOCIAL_PROVIDERS', () => {
  it('lists exactly the providers this project was generated with', () => {
    expect(SOCIAL_PROVIDERS).toEqual([
      { id: 'google', name: 'Google', icon: '' },
      { id: 'github', name: 'Github', icon: '' },
      { id: 'openid_connect', name: 'Openid Connect', icon: '' },
    ])
  })
})
