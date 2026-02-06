'use client';

interface UserDetailProps {
  userId: string | null;
  onClose?: () => void;
}

// Mock user data
const mockUser = {
  id: 'u1',
  email: 'sofia@example.com',
  profile: {
    mode: 'dating',
    gender_claim: 'female',
    birth_year: 1998,
    city: 'Istanbul',
    bio: 'Coffee lover',
  },
  verification: {
    status: 'pending',
    photos_approved: 2,
    instagram_verified: false,
    gender_verified: false,
  },
  entry_status: {
    status: 'pending',
    verified_opposite_gender_count: 0,
    required_opposite_gender: 1,
  },
  score: {
    quality_score: 3.5,
    reliability_score: 4.0,
    status: 'ok',
  },
  referrals_made: 2,
  reports_received: 0,
  created_at: '2024-01-15',
};

export function UserDetail({ userId, onClose }: UserDetailProps) {
  if (!userId) {
    return (
      <div className="bg-white rounded-lg p-12 text-center">
        <span className="text-4xl mb-4 block">👤</span>
        <p className="text-gray-500">Select a user to view details</p>
      </div>
    );
  }

  const user = mockUser;

  const handleAction = (action: string) => {
    // Would call API for admin action
    alert(`Action: ${action} for user ${userId}`);
  };

  return (
    <div>
      {onClose && (
        <button
          onClick={onClose}
          className="mb-4 text-gray-500 hover:text-gray-700"
        >
          ← Back
        </button>
      )}

      <div className="bg-white rounded-lg p-6 shadow-sm border border-gray-200 mb-6">
        <div className="flex items-center mb-4">
          <div className="w-16 h-16 bg-primary-100 rounded-full flex items-center justify-center">
            <span className="text-2xl">👤</span>
          </div>
          <div className="ml-4">
            <h3 className="text-xl font-bold text-gray-900">{user.email}</h3>
            <p className="text-gray-500">ID: {userId}</p>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span className="text-gray-500">Mode:</span>
            <span className="ml-2 font-medium capitalize">{user.profile.mode}</span>
          </div>
          <div>
            <span className="text-gray-500">Gender:</span>
            <span className="ml-2 font-medium capitalize">{user.profile.gender_claim}</span>
          </div>
          <div>
            <span className="text-gray-500">Age:</span>
            <span className="ml-2 font-medium">{new Date().getFullYear() - user.profile.birth_year}</span>
          </div>
          <div>
            <span className="text-gray-500">City:</span>
            <span className="ml-2 font-medium">{user.profile.city}</span>
          </div>
        </div>
      </div>

      {/* Verification Status */}
      <div className="bg-white rounded-lg p-6 shadow-sm border border-gray-200 mb-6">
        <h4 className="font-semibold text-gray-900 mb-4">Verification Status</h4>
        <div className="space-y-3">
          <StatusRow
            label="Photos"
            value={`${user.verification.photos_approved}/3 approved`}
            status={user.verification.photos_approved >= 3 ? 'success' : 'pending'}
          />
          <StatusRow
            label="Instagram"
            value={user.verification.instagram_verified ? 'Verified' : 'Pending'}
            status={user.verification.instagram_verified ? 'success' : 'pending'}
          />
          <StatusRow
            label="Gender"
            value={user.verification.gender_verified ? 'Verified' : 'Pending'}
            status={user.verification.gender_verified ? 'success' : 'pending'}
          />
          <StatusRow
            label="Overall"
            value={user.verification.status}
            status={user.verification.status === 'approved' ? 'success' : 'pending'}
          />
        </div>
      </div>

      {/* Entry Status */}
      <div className="bg-white rounded-lg p-6 shadow-sm border border-gray-200 mb-6">
        <h4 className="font-semibold text-gray-900 mb-4">Entry Status</h4>
        <div className="space-y-3">
          <StatusRow
            label="Status"
            value={user.entry_status.status}
            status={user.entry_status.status === 'approved' ? 'success' : 'pending'}
          />
          <StatusRow
            label="Referrals"
            value={`${user.entry_status.verified_opposite_gender_count}/${user.entry_status.required_opposite_gender}`}
            status={user.entry_status.verified_opposite_gender_count >= user.entry_status.required_opposite_gender ? 'success' : 'pending'}
          />
        </div>
      </div>

      {/* Scores */}
      <div className="bg-white rounded-lg p-6 shadow-sm border border-gray-200 mb-6">
        <h4 className="font-semibold text-gray-900 mb-4">User Scores</h4>
        <div className="space-y-3">
          <ScoreRow label="Quality Score" value={user.score.quality_score} max={5} />
          <ScoreRow label="Reliability Score" value={user.score.reliability_score} max={5} />
          <StatusRow
            label="Status"
            value={user.score.status}
            status={user.score.status === 'ok' ? 'success' : user.score.status === 'limited' ? 'warning' : 'error'}
          />
        </div>
      </div>

      {/* Actions */}
      <div className="bg-white rounded-lg p-6 shadow-sm border border-gray-200">
        <h4 className="font-semibold text-gray-900 mb-4">Admin Actions</h4>
        <div className="grid grid-cols-2 gap-2">
          <button
            onClick={() => handleAction('approve_verification')}
            className="px-4 py-2 bg-green-500 text-white rounded-lg text-sm hover:bg-green-600"
          >
            Approve Verification
          </button>
          <button
            onClick={() => handleAction('reject_verification')}
            className="px-4 py-2 bg-red-500 text-white rounded-lg text-sm hover:bg-red-600"
          >
            Reject Verification
          </button>
          <button
            onClick={() => handleAction('override_entry')}
            className="px-4 py-2 bg-blue-500 text-white rounded-lg text-sm hover:bg-blue-600"
          >
            Override Entry Gate
          </button>
          <button
            onClick={() => handleAction('limit_user')}
            className="px-4 py-2 bg-yellow-500 text-white rounded-lg text-sm hover:bg-yellow-600"
          >
            Limit Visibility
          </button>
          <button
            onClick={() => handleAction('ban_user')}
            className="px-4 py-2 bg-red-700 text-white rounded-lg text-sm hover:bg-red-800"
          >
            Ban User
          </button>
          <button
            onClick={() => handleAction('view_audit')}
            className="px-4 py-2 bg-gray-500 text-white rounded-lg text-sm hover:bg-gray-600"
          >
            View Audit Log
          </button>
        </div>
      </div>
    </div>
  );
}

function StatusRow({ label, value, status }: { label: string; value: string; status: 'success' | 'pending' | 'warning' | 'error' }) {
  const colors = {
    success: 'bg-green-100 text-green-800',
    pending: 'bg-yellow-100 text-yellow-800',
    warning: 'bg-orange-100 text-orange-800',
    error: 'bg-red-100 text-red-800',
  };

  return (
    <div className="flex justify-between items-center">
      <span className="text-gray-600">{label}</span>
      <span className={`px-2 py-1 rounded text-sm capitalize ${colors[status]}`}>
        {value}
      </span>
    </div>
  );
}

function ScoreRow({ label, value, max }: { label: string; value: number; max: number }) {
  const percentage = (value / max) * 100;

  return (
    <div>
      <div className="flex justify-between text-sm mb-1">
        <span className="text-gray-600">{label}</span>
        <span className="font-medium">{value.toFixed(1)} / {max}</span>
      </div>
      <div className="w-full bg-gray-200 rounded-full h-2">
        <div
          className={`h-2 rounded-full ${percentage >= 60 ? 'bg-green-500' : percentage >= 40 ? 'bg-yellow-500' : 'bg-red-500'}`}
          style={{ width: `${percentage}%` }}
        />
      </div>
    </div>
  );
}
