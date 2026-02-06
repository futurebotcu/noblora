'use client';

import { useState } from 'react';

interface AuditEntry {
  id: string;
  actor: string | null;
  action: string;
  target_user: string | null;
  payload: Record<string, unknown>;
  created_at: string;
}

const mockEntries: AuditEntry[] = [
  {
    id: '1',
    actor: 'admin@noblara.app',
    action: 'verification_approved',
    target_user: 'sofia@example.com',
    payload: { type: 'photo', photos_approved: 3 },
    created_at: '2024-01-15T10:30:00Z',
  },
  {
    id: '2',
    actor: null,
    action: 'user_banned',
    target_user: 'spam@example.com',
    payload: { reason: 'Score below threshold', quality_score: 1.2 },
    created_at: '2024-01-15T09:15:00Z',
  },
  {
    id: '3',
    actor: 'admin@noblara.app',
    action: 'config_updated',
    target_user: null,
    payload: { key: 'bootstrap_mode_enabled', old_value: false, new_value: true },
    created_at: '2024-01-15T08:00:00Z',
  },
  {
    id: '4',
    actor: 'admin@noblara.app',
    action: 'entry_override',
    target_user: 'john@example.com',
    payload: { reason: 'Early adopter' },
    created_at: '2024-01-14T16:45:00Z',
  },
  {
    id: '5',
    actor: null,
    action: 'referral_verified',
    target_user: 'emma@example.com',
    payload: { referred_user: 'mike@example.com' },
    created_at: '2024-01-14T14:20:00Z',
  },
];

export function AuditLog() {
  const [entries] = useState(mockEntries);
  const [filter, setFilter] = useState('all');

  const filteredEntries = filter === 'all'
    ? entries
    : entries.filter(e => e.action.includes(filter));

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    return date.toLocaleString();
  };

  const getActionColor = (action: string) => {
    if (action.includes('banned') || action.includes('rejected')) return 'text-red-600 bg-red-50';
    if (action.includes('approved') || action.includes('verified')) return 'text-green-600 bg-green-50';
    if (action.includes('config') || action.includes('override')) return 'text-blue-600 bg-blue-50';
    return 'text-gray-600 bg-gray-50';
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold text-gray-900">Audit Log</h2>
        <div className="flex gap-2">
          <select
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
          >
            <option value="all">All Actions</option>
            <option value="verification">Verifications</option>
            <option value="ban">Bans</option>
            <option value="config">Config Changes</option>
            <option value="entry">Entry Gates</option>
          </select>
          <button className="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200">
            Export CSV
          </button>
        </div>
      </div>

      <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <table className="w-full">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Timestamp
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actor
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Action
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Target
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Details
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {filteredEntries.map((entry) => (
              <tr key={entry.id} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {formatDate(entry.created_at)}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  {entry.actor ? (
                    <span className="font-medium text-gray-900">{entry.actor}</span>
                  ) : (
                    <span className="text-gray-400 italic">System</span>
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`px-2 py-1 text-xs font-medium rounded ${getActionColor(entry.action)}`}>
                    {entry.action.replace(/_/g, ' ')}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {entry.target_user || '-'}
                </td>
                <td className="px-6 py-4 text-sm text-gray-500 max-w-xs truncate">
                  <code className="text-xs bg-gray-100 px-2 py-1 rounded">
                    {JSON.stringify(entry.payload)}
                  </code>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      <div className="mt-4 flex justify-between items-center">
        <p className="text-sm text-gray-500">
          Showing {filteredEntries.length} entries
        </p>
        <div className="flex gap-2">
          <button className="px-4 py-2 border border-gray-300 rounded-lg text-sm hover:bg-gray-50 disabled:opacity-50" disabled>
            Previous
          </button>
          <button className="px-4 py-2 border border-gray-300 rounded-lg text-sm hover:bg-gray-50">
            Next
          </button>
        </div>
      </div>
    </div>
  );
}
