'use client';

import { useState } from 'react';
import { Sidebar } from '@/components/Sidebar';
import { VerificationQueue } from '@/components/VerificationQueue';
import { UserDetail } from '@/components/UserDetail';
import { ConfigPanel } from '@/components/ConfigPanel';
import { AuditLog } from '@/components/AuditLog';

type Tab = 'photos' | 'instagram' | 'gender' | 'reports' | 'users' | 'config' | 'audit';

export default function AdminDashboard() {
  const [activeTab, setActiveTab] = useState<Tab>('photos');
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);

  return (
    <div className="flex min-h-screen bg-gray-50">
      <Sidebar activeTab={activeTab} onTabChange={setActiveTab} />

      <main className="flex-1 p-8">
        <div className="max-w-7xl mx-auto">
          {/* Header */}
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-gray-900">
              Noblara Admin
            </h1>
            <p className="text-gray-500 mt-1">
              Manage verifications, users, and platform settings
            </p>
          </div>

          {/* Content */}
          {(activeTab === 'photos' || activeTab === 'instagram' || activeTab === 'gender' || activeTab === 'reports') && (
            <VerificationQueue
              type={activeTab}
              onUserSelect={setSelectedUserId}
            />
          )}

          {activeTab === 'users' && (
            <UserDetail userId={selectedUserId} />
          )}

          {activeTab === 'config' && (
            <ConfigPanel />
          )}

          {activeTab === 'audit' && (
            <AuditLog />
          )}
        </div>
      </main>

      {/* User Detail Sidebar */}
      {selectedUserId && activeTab !== 'users' && (
        <aside className="w-96 bg-white border-l border-gray-200 p-6 overflow-y-auto">
          <UserDetail userId={selectedUserId} onClose={() => setSelectedUserId(null)} />
        </aside>
      )}
    </div>
  );
}
