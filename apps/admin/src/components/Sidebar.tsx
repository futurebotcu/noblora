'use client';

type Tab = 'photos' | 'instagram' | 'gender' | 'reports' | 'users' | 'config' | 'audit';

interface SidebarProps {
  activeTab: Tab;
  onTabChange: (tab: Tab) => void;
}

const tabs: { id: Tab; label: string; icon: string; badge?: number }[] = [
  { id: 'photos', label: 'Photo Verification', icon: '📷', badge: 12 },
  { id: 'instagram', label: 'Instagram Verification', icon: '📸', badge: 5 },
  { id: 'gender', label: 'Gender Verification', icon: '🆔', badge: 8 },
  { id: 'reports', label: 'Reports', icon: '⚠️', badge: 3 },
  { id: 'users', label: 'Users', icon: '👥' },
  { id: 'config', label: 'Configuration', icon: '⚙️' },
  { id: 'audit', label: 'Audit Log', icon: '📋' },
];

export function Sidebar({ activeTab, onTabChange }: SidebarProps) {
  return (
    <aside className="w-64 bg-white border-r border-gray-200 min-h-screen">
      <div className="p-6">
        <h2 className="text-xl font-bold text-primary-600">Noblara</h2>
        <p className="text-sm text-gray-500">Admin Panel</p>
      </div>

      <nav className="px-3">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => onTabChange(tab.id)}
            className={`w-full flex items-center justify-between px-4 py-3 rounded-lg mb-1 text-left transition-colors ${
              activeTab === tab.id
                ? 'bg-primary-50 text-primary-700'
                : 'text-gray-600 hover:bg-gray-100'
            }`}
          >
            <div className="flex items-center">
              <span className="mr-3">{tab.icon}</span>
              <span className="font-medium">{tab.label}</span>
            </div>
            {tab.badge && (
              <span className="bg-red-500 text-white text-xs px-2 py-0.5 rounded-full">
                {tab.badge}
              </span>
            )}
          </button>
        ))}
      </nav>

      <div className="absolute bottom-0 left-0 w-64 p-4 border-t border-gray-200">
        <div className="flex items-center">
          <div className="w-8 h-8 bg-primary-500 rounded-full flex items-center justify-center">
            <span className="text-white text-sm font-bold">A</span>
          </div>
          <div className="ml-3">
            <p className="text-sm font-medium text-gray-700">Admin User</p>
            <p className="text-xs text-gray-500">admin@noblara.app</p>
          </div>
        </div>
      </div>
    </aside>
  );
}
