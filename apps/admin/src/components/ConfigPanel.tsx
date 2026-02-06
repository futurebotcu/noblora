'use client';

import { useState } from 'react';

interface ConfigItem {
  key: string;
  value: boolean | number | string;
  label: string;
  description: string;
  type: 'boolean' | 'number' | 'string';
}

const defaultConfig: ConfigItem[] = [
  {
    key: 'bootstrap_mode_enabled',
    value: true,
    label: 'Bootstrap Mode',
    description: 'Allow users to bypass entry gate during initial launch',
    type: 'boolean',
  },
  {
    key: 'male_counter_proposal_enabled',
    value: false,
    label: 'Male Counter-Proposals',
    description: 'Allow men to counter-propose call times (women still propose first)',
    type: 'boolean',
  },
  {
    key: 'video_call_required',
    value: true,
    label: 'Video Call Required',
    description: 'Require video call before chat unlock',
    type: 'boolean',
  },
  {
    key: 'photo_min_quality',
    value: 60,
    label: 'Min Photo Quality Score',
    description: 'Minimum AI quality score for photo approval (0-100)',
    type: 'number',
  },
  {
    key: 'min_call_duration_sec',
    value: 180,
    label: 'Min Call Duration (sec)',
    description: 'Minimum call duration to unlock chat',
    type: 'number',
  },
  {
    key: 'max_call_duration_sec',
    value: 300,
    label: 'Max Call Duration (sec)',
    description: 'Maximum call duration before auto-end',
    type: 'number',
  },
  {
    key: 'schedule_window_hours',
    value: 12,
    label: 'Schedule Window (hours)',
    description: 'Time window to schedule call after match',
    type: 'number',
  },
  {
    key: 'meetup_deadline_days',
    value: 5,
    label: 'Meetup Deadline (days)',
    description: 'Days to schedule meetup after call',
    type: 'number',
  },
];

export function ConfigPanel() {
  const [config, setConfig] = useState(defaultConfig);
  const [hasChanges, setHasChanges] = useState(false);

  const handleChange = (key: string, value: boolean | number | string) => {
    setConfig(config.map(item =>
      item.key === key ? { ...item, value } : item
    ));
    setHasChanges(true);
  };

  const handleSave = () => {
    // Would call API to save config
    alert('Configuration saved!');
    setHasChanges(false);
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold text-gray-900">Platform Configuration</h2>
        <button
          onClick={handleSave}
          disabled={!hasChanges}
          className={`px-6 py-2 rounded-lg font-medium transition-colors ${
            hasChanges
              ? 'bg-primary-500 text-white hover:bg-primary-600'
              : 'bg-gray-200 text-gray-500 cursor-not-allowed'
          }`}
        >
          Save Changes
        </button>
      </div>

      <div className="bg-white rounded-lg shadow-sm border border-gray-200">
        {config.map((item, index) => (
          <div
            key={item.key}
            className={`p-6 ${index !== config.length - 1 ? 'border-b border-gray-200' : ''}`}
          >
            <div className="flex items-start justify-between">
              <div className="flex-1">
                <h3 className="font-semibold text-gray-900">{item.label}</h3>
                <p className="text-sm text-gray-500 mt-1">{item.description}</p>
                <code className="text-xs text-gray-400 mt-2 block">{item.key}</code>
              </div>

              <div className="ml-6">
                {item.type === 'boolean' && (
                  <button
                    onClick={() => handleChange(item.key, !item.value)}
                    className={`relative w-14 h-8 rounded-full transition-colors ${
                      item.value ? 'bg-primary-500' : 'bg-gray-300'
                    }`}
                  >
                    <span
                      className={`absolute top-1 left-1 w-6 h-6 bg-white rounded-full transition-transform ${
                        item.value ? 'translate-x-6' : ''
                      }`}
                    />
                  </button>
                )}

                {item.type === 'number' && (
                  <input
                    type="number"
                    value={item.value as number}
                    onChange={(e) => handleChange(item.key, parseInt(e.target.value, 10))}
                    className="w-24 px-3 py-2 border border-gray-300 rounded-lg text-right focus:outline-none focus:ring-2 focus:ring-primary-500"
                  />
                )}

                {item.type === 'string' && (
                  <input
                    type="text"
                    value={item.value as string}
                    onChange={(e) => handleChange(item.key, e.target.value)}
                    className="w-48 px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
                  />
                )}
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Warning */}
      <div className="mt-6 bg-yellow-50 border border-yellow-200 rounded-lg p-4">
        <div className="flex">
          <span className="text-yellow-400 mr-3">⚠️</span>
          <div>
            <h4 className="font-medium text-yellow-800">Caution</h4>
            <p className="text-sm text-yellow-700 mt-1">
              Changes to configuration affect all users immediately.
              All changes are logged in the audit trail.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
