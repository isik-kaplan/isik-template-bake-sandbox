import type { ExpoConfig } from 'expo/config'

const config: ExpoConfig = {
  name: 'Test Project',
  slug: 'test_project',
  scheme: 'test_project',
  version: '0.1.0',
  orientation: 'portrait',
  userInterfaceStyle: 'automatic',
  ios: {
    // Reverse-DNS: testproject.test becomes test.testproject.
    bundleIdentifier: 'test.testproject.mobile',
    supportsTablet: true,
  },
  android: {
    package: 'test.testproject.mobile',
    // Firebase's google-services.json, which an Android build needs for a push token.
    googleServicesFile: process.env.GOOGLE_SERVICES_FILE,
  },
  plugins: [
    'expo-router',
    'expo-secure-store',
    'expo-apple-authentication',
    'expo-notifications',
    // iOS needs iosUrlScheme (from a real Google iOS client ID) added once credentials exist.
    '@react-native-google-signin/google-signin',
  ],
}

export default config
