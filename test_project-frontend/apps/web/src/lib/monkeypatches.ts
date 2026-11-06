import { createApi, createAuthApi } from '@/lib/apiClients'
import { apiOrigin } from '@/lib/apiOrigin'
import { authOrigin } from '@/lib/authOrigin'

import { createConsoleDebugSwitch } from '@isikk/core'

// The window.test_project type is declared in global.d.ts.

// `console` is on `typeof globalThis`, not `Window`.
type WindowLike = Window & typeof globalThis

// The typed clients on window, e.g. window.test_project.api.me() in the console.
export function globalApi(window: WindowLike) {
  const api = createApi(apiOrigin())
  const auth = createAuthApi(authOrigin())
  // The switch adds `debug`, silencing the console until `debug(true)` turns it back on.
  window.test_project = { api, auth } as Window['test_project']
  createConsoleDebugSwitch(window, { namespace: 'test_project' })
  return window.test_project
}
