import './globals.css'

import type { Metadata } from 'next'

import type React from 'react'

import { Toaster } from '@/components/base/sonner'
import { TooltipProvider } from '@/components/base/tooltip'

import MonkeyPatches from '@/app/monkeypatches'
import { PublicConfigScript } from '@/config/public'
import { LanguageProvider } from '@/lib/LanguageContext'
import { SessionProvider } from '@/lib/SessionContext'
import { getLanguage, getSession } from '@/lib/getSession'

import { ThemeProvider } from 'next-themes'

export const metadata: Metadata = {
  title: 'Test Project',
  description: 'A test project generated for template validation.',
}

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const session = await getSession()
  const language = await getLanguage()

  return (
    <html lang={language} suppressHydrationWarning>
      <head>
        <MonkeyPatches />
      </head>
      <body>
        <PublicConfigScript />
        <ThemeProvider attribute="data-theme" defaultTheme="system" enableSystem>
          <SessionProvider session={session}>
            <LanguageProvider language={language}>
              <TooltipProvider>
                {children}
                <Toaster />
              </TooltipProvider>
            </LanguageProvider>
          </SessionProvider>
        </ThemeProvider>
      </body>
    </html>
  )
}
