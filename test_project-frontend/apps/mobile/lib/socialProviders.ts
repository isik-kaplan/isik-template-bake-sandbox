// Whether this project's backend actually has each provider configured (cookiecutter's own
// social_login_providers answer) - not just whether the native SDK dependency is installed, since
// both packages are always in package.json regardless (there's no include_mobile-style flag for
// individual providers, and neither button renders when its own flag here is off anyway).
export const GOOGLE_SIGN_IN_ENABLED = true
export const APPLE_SIGN_IN_ENABLED = false
