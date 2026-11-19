'use client'

import { useEffect } from 'react'

import { globalApi } from '@/lib/monkeypatches'

export default function MonkeyPatches() {
  useEffect(() => {
    const test_project = globalApi(window)
    // Primes the CSRF cookie at load, so the console client is ready before its first call.
    void test_project.auth.session()
  }, [])

  return null
}
