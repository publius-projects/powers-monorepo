'use client'

import React from 'react'
import { ProtocolListingLayout } from '../protocol/ProtocolListingLayout'
import { TitleText } from '@/components/StandardFonts'

export default function ForumPage() {
  return (
    <ProtocolListingLayout>
      <div className="w-full flex-1 flex flex-col items-center p-4 pt-20">
        <div className="max-w-4xl w-full">
          <TitleText 
            title="Forum"
            subtitle="The community discussion space is currently under construction. Please check back soon!"
            size={2}
          />
          
          <div className="mt-12 p-12 border border-dashed border-slate-300 rounded-lg flex flex-col items-center justify-center bg-white shadow-sm">
            <div className="text-slate-400 text-center">
              <svg className="w-16 h-16 mx-auto mb-4 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
              </svg>
              <p className="text-lg font-medium text-slate-600">Coming Soon</p>
              <p className="text-sm">A dedicated space for Powers Protocol governance discussions and community proposals.</p>
            </div>
          </div>
        </div>
      </div>
    </ProtocolListingLayout>
  )
}
