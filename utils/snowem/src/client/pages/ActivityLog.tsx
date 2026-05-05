import { useEffect, useState } from 'react';

interface Activity {
  id: string;
  timestamp: string;
  method: string;
  path: string;
  status: number;
  body?: unknown;
}

export default function ActivityLog() {
  const [activity, setActivity] = useState<Activity[]>([]);
  const [selected, setSelected] = useState<Activity | null>(null);

  useEffect(() => {
    const fetchData = () => {
      fetch('/_internal/activity?limit=100').then((r) => r.json()).then(setActivity).catch(() => {});
    };
    fetchData();
    const interval = setInterval(fetchData, 2000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Activity Log</h1>
      <p className="text-sm text-gray-500 mb-4">
        Live feed of API requests received from the Elastic ServiceNow connector. Auto-refreshes every 2 seconds.
      </p>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="bg-white rounded-lg shadow border border-snow-border overflow-hidden">
          <div className="divide-y divide-snow-border max-h-[600px] overflow-y-auto">
            {activity.length === 0 ? (
              <div className="px-4 py-8 text-center text-gray-500 text-sm">
                No API activity yet
              </div>
            ) : (
              activity.map((entry) => (
                <button
                  key={entry.id}
                  onClick={() => setSelected(entry)}
                  className={`w-full px-4 py-2.5 flex items-center gap-3 text-sm text-left hover:bg-gray-50 transition-colors ${
                    selected?.id === entry.id ? 'bg-blue-50' : ''
                  }`}
                >
                  <MethodBadge method={entry.method} />
                  <span className="font-mono text-xs text-gray-700 truncate flex-1">{entry.path}</span>
                  <span className={`text-xs font-medium ${entry.status < 400 ? 'text-green-600' : 'text-red-600'}`}>
                    {entry.status}
                  </span>
                  <span className="text-xs text-gray-400 whitespace-nowrap">
                    {new Date(entry.timestamp).toLocaleTimeString()}
                  </span>
                </button>
              ))
            )}
          </div>
        </div>

        <div className="bg-white rounded-lg shadow border border-snow-border p-4">
          <h3 className="font-semibold text-gray-800 mb-3 text-sm">Request Details</h3>
          {selected ? (
            <div className="space-y-3">
              <div className="text-sm">
                <span className="text-gray-500">Method:</span>{' '}
                <MethodBadge method={selected.method} />
              </div>
              <div className="text-sm">
                <span className="text-gray-500">Path:</span>{' '}
                <code className="text-xs bg-gray-100 px-1.5 py-0.5 rounded">{selected.path}</code>
              </div>
              <div className="text-sm">
                <span className="text-gray-500">Status:</span>{' '}
                <span className={selected.status < 400 ? 'text-green-600' : 'text-red-600'}>{selected.status}</span>
              </div>
              <div className="text-sm">
                <span className="text-gray-500">Time:</span>{' '}
                {new Date(selected.timestamp).toLocaleString()}
              </div>
              {selected.body != null && (
                <div>
                  <span className="text-sm text-gray-500">Request Body:</span>
                  <pre className="mt-1 text-xs bg-gray-900 text-green-400 p-3 rounded overflow-auto max-h-64">
                    {JSON.stringify(selected.body as Record<string, unknown>, null, 2)}
                  </pre>
                </div>
              )}
            </div>
          ) : (
            <p className="text-sm text-gray-400">Select a request to view details</p>
          )}
        </div>
      </div>
    </div>
  );
}

function MethodBadge({ method }: { method: string }) {
  const colors: Record<string, string> = {
    GET: 'bg-blue-100 text-blue-700',
    POST: 'bg-green-100 text-green-700',
    PATCH: 'bg-yellow-100 text-yellow-700',
    DELETE: 'bg-red-100 text-red-700',
  };
  return (
    <span className={`px-1.5 py-0.5 rounded text-xs font-mono font-bold ${colors[method] || 'bg-gray-100 text-gray-700'}`}>
      {method}
    </span>
  );
}
