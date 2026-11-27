import brand from '@test-project/brand/brand.json'

import type { ExpoConfig } from 'expo/config'

const config: ExpoConfig = {
  name: brand.name,
  slug: 'test_project',
  scheme: 'test_project',
  version: '0.1.0',
  // The same source image the web app draws its icons from; Expo makes every size it needs.
  icon: '../../packages/brand/icon.png',
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
    // iOS 27 stops at launch any app that hasn't adopted the scene life cycle; Expo's own prebuild doesn't yet.
    './plugins/withSceneLifecycle',
    ['./plugins/withPlainHttp', { origins: [process.env.EXPO_PUBLIC_API_ORIGIN, process.env.EXPO_PUBLIC_AUTH_ORIGIN] }],
  ],
}

export default config
