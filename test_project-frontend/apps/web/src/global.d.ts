import type { Api } from '@test-project/api'
import type { AuthApi } from '@test-project/auth-api'

export {}

declare global {
  interface Window {
    test_project: { api: Api; auth: AuthApi; debug: (flag: boolean) => void }
  }
}
