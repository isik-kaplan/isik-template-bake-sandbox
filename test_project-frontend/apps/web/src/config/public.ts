import { publicConfig, string } from '@isikk/core/next/config'

// Resolved per-request, not baked at build time - one image serves every environment.
export const { CONFIG, PublicConfigScript } = publicConfig(
  {
    DOMAIN: string(),
  },
  { prefix: 'TEST_PROJECT', globalKey: '__TEST_PROJECT_CONFIG__' }
)
