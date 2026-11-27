import { describe, expect, it, vi } from 'vitest'

// PublicConfigScript, unused here, awaits next/server's connection().
vi.mock('next/server', () => ({ connection: vi.fn() }))

describe('CONFIG (public)', () => {
  it('reads DOMAIN from its own env var', async () => {
    vi.stubEnv('TEST_PROJECT__DOMAIN', 'example.test')
    vi.resetModules()

    const { CONFIG, PublicConfigScript } = await import('@/config/public')

    expect(CONFIG.DOMAIN).toBe('example.test')
    expect(typeof PublicConfigScript).toBe('function')

    vi.unstubAllEnvs()
    vi.resetModules()
  })

  it('leaves the OAuth provider off and names no social provider when neither is set', async () => {
    vi.stubEnv('TEST_PROJECT__DOMAIN', 'example.test')
    vi.resetModules()

    const { CONFIG } = await import('@/config/public')

    expect(CONFIG.OAUTH_PROVIDER.MODE).toBe('off')
    expect(CONFIG.SOCIAL_LOGIN.PROVIDERS).toEqual([])

    vi.unstubAllEnvs()
    vi.resetModules()
  })

  it.each([
    ['true', true],
    ['false', false],
    [undefined, false],
  ])('reads SOCIAL_LOGIN__ONLY=%s, defaulting to the answer given at generation', async (value, only) => {
    vi.stubEnv('TEST_PROJECT__DOMAIN', 'example.test')
    vi.stubEnv('TEST_PROJECT__SOCIAL_LOGIN__ONLY', value)
    vi.resetModules()

    const { CONFIG } = await import('@/config/public')

    expect(CONFIG.SOCIAL_LOGIN.ONLY).toBe(only)

    vi.unstubAllEnvs()
    vi.resetModules()
  })

  it.each([
    ['full_only', 'full_only'],
    [undefined, 'username_with_optional_full'],
  ])(
    'reads ACCOUNTS__NAME_REQUIREMENT=%s, defaulting to the answer given at generation',
    async (value, requirement) => {
      vi.stubEnv('TEST_PROJECT__DOMAIN', 'example.test')
      vi.stubEnv('TEST_PROJECT__ACCOUNTS__NAME_REQUIREMENT', value)
      vi.resetModules()

      const { CONFIG } = await import('@/config/public')

      expect(CONFIG.ACCOUNTS.NAME_REQUIREMENT).toBe(requirement)

      vi.unstubAllEnvs()
      vi.resetModules()
    }
  )

  it('refuses a name requirement that is not one, naming the five', async () => {
    vi.stubEnv('TEST_PROJECT__DOMAIN', 'example.test')
    vi.stubEnv('TEST_PROJECT__ACCOUNTS__NAME_REQUIREMENT', 'nickname')
    vi.resetModules()

    const { CONFIG } = await import('@/config/public')

    expect(() => CONFIG.ACCOUNTS.NAME_REQUIREMENT).toThrow(
      'ACCOUNTS__NAME_REQUIREMENT is "nickname"; it is one of username_with_optional_full, full_only, ' +
        'full_and_username, full_with_optional_username, username_only'
    )

    vi.unstubAllEnvs()
    vi.resetModules()
  })

  it('reads the OAuth provider mode from its own variable', async () => {
    vi.stubEnv('TEST_PROJECT__DOMAIN', 'example.test')
    vi.stubEnv('TEST_PROJECT__OAUTH_PROVIDER__MODE', 'auto')
    vi.resetModules()

    const { CONFIG } = await import('@/config/public')

    expect(CONFIG.OAUTH_PROVIDER.MODE).toBe('auto')

    vi.unstubAllEnvs()
    vi.resetModules()
  })

  it('reads the social login providers, icons and admin-only ones as lists, empty when unset', async () => {
    vi.stubEnv('TEST_PROJECT__DOMAIN', 'example.test')
    vi.stubEnv('TEST_PROJECT__SOCIAL_LOGIN__PROVIDERS', 'github,openid_connect:corp')
    vi.resetModules()

    const { CONFIG } = await import('@/config/public')

    expect(CONFIG.SOCIAL_LOGIN.PROVIDERS).toEqual(['github', 'openid_connect:corp'])
    expect(CONFIG.SOCIAL_LOGIN.ICONS).toEqual([])
    expect(CONFIG.SOCIAL_LOGIN.ADMIN_ONLY).toEqual([])

    vi.stubEnv('TEST_PROJECT__SOCIAL_LOGIN__ADMIN_ONLY', 'openid_connect:corp')
    vi.resetModules()
    expect((await import('@/config/public')).CONFIG.SOCIAL_LOGIN.ADMIN_ONLY).toEqual(['openid_connect:corp'])

    vi.unstubAllEnvs()
    vi.resetModules()
  })
})
