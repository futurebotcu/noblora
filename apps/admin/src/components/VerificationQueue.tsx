'use client';

import { useState } from 'react';

interface VerificationQueueProps {
  type: 'photos' | 'instagram' | 'gender' | 'reports';
  onUserSelect: (userId: string) => void;
}

// Mock data
const mockItems = [
  { id: '1', userId: 'u1', userName: 'Sofia K.', submittedAt: '2 hours ago', status: 'pending' },
  { id: '2', userId: 'u2', userName: 'Emma L.', submittedAt: '3 hours ago', status: 'pending' },
  { id: '3', userId: 'u3', userName: 'Ayşe M.', submittedAt: '5 hours ago', status: 'pending' },
  { id: '4', userId: 'u4', userName: 'John D.', submittedAt: '6 hours ago', status: 'pending' },
  { id: '5', userId: 'u5', userName: 'Mike R.', submittedAt: '8 hours ago', status: 'pending' },
];

export function VerificationQueue({ type, onUserSelect }: VerificationQueueProps) {
  const [items, setItems] = useState(mockItems);

  const handleApprove = (id: string) => {
    setItems(items.filter(item => item.id !== id));
    // Would call API to approve
  };

  const handleReject = (id: string) => {
    setItems(items.filter(item => item.id !== id));
    // Would call API to reject
  };

  const getTitle = () => {
    switch (type) {
      case 'photos': return 'Photo Verification Queue';
      case 'instagram': return 'Instagram Verification Queue';
      case 'gender': return 'Gender Verification Queue';
      case 'reports': return 'User Reports Queue';
    }
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold text-gray-900">{getTitle()}</h2>
        <span className="bg-yellow-100 text-yellow-800 px-3 py-1 rounded-full text-sm font-medium">
          {items.length} pending
        </span>
      </div>

      {items.length === 0 ? (
        <div className="bg-white rounded-lg p-12 text-center">
          <span className="text-4xl mb-4 block">✅</span>
          <p className="text-gray-500">No pending items in this queue</p>
        </div>
      ) : (
        <div className="space-y-4">
          {items.map((item) => (
            <div
              key={item.id}
              className="bg-white rounded-lg p-6 shadow-sm border border-gray-200"
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center">
                  <div className="w-12 h-12 bg-gray-200 rounded-full flex items-center justify-center">
                    <span className="text-gray-500">👤</span>
                  </div>
                  <div className="ml-4">
                    <button
                      onClick={() => onUserSelect(item.userId)}
                      className="font-semibold text-gray-900 hover:text-primary-600"
                    >
                      {item.userName}
                    </button>
                    <p className="text-sm text-gray-500">
                      Submitted {item.submittedAt}
                    </p>
                  </div>
                </div>

                {type === 'photos' && (
                  <div className="flex gap-2">
                    {/* Photo thumbnails placeholder */}
                    {[1, 2, 3].map((i) => (
                      <div key={i} className="w-16 h-16 bg-gray-100 rounded" />
                    ))}
                  </div>
                )}

                {type === 'instagram' && (
                  <div className="text-sm text-gray-500">
                    Screenshot proof uploaded
                  </div>
                )}

                {type === 'gender' && (
                  <div className="text-sm text-gray-500">
                    ID verification uploaded
                  </div>
                )}

                {type === 'reports' && (
                  <div className="text-sm text-red-500">
                    Reported for: Inappropriate behavior
                  </div>
                )}

                <div className="flex gap-2">
                  <button
                    onClick={() => handleApprove(item.id)}
                    className="px-4 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 transition-colors"
                  >
                    {type === 'reports' ? 'Take Action' : 'Approve'}
                  </button>
                  <button
                    onClick={() => handleReject(item.id)}
                    className="px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600 transition-colors"
                  >
                    {type === 'reports' ? 'Dismiss' : 'Reject'}
                  </button>
                  <button
                    onClick={() => onUserSelect(item.userId)}
                    className="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                  >
                    View Details
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
