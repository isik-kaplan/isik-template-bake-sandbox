import type { ExpoConfig } from 'expo/config'

// A plain object, not app.json: this project's identifiers are derived from the cookiecutter
// answers, which app.json's static JSON can't express.
const config: ExpoConfig = {
  name: 'Test Project',
  slug: 'test_project',
  scheme: 'test_project',
  version: '0.1.0',
  orientation: 'portrait',
  userInterfaceStyle: 'automatic',
  ios: {
    // Reverse-DNS of the project's own domain, same convention a real bundle ID follows -
    // testproject.test becomes test.testproject.
    bundleIdentifier: 'test.testproject.mobile',
    supportsTablet: true,
  },
  android: {
    package: 'test.testproject.mobile',
  },
  plugins: ['expo-router', 'expo-secure-store'],
}

export default config
