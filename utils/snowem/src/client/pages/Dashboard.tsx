import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

interface Stats {
  total: number;
  open: number;
  closed: number;
}

interface Activity {
  id: string;
  timestamp: string;
  method: string;
  path: string;
  status: number;
}

export default function Dashboard() {
  const [stats, setStats] = useState<Stats>({ total: 0, open: 0, closed: 0 });
  const [activity, setActivity] = useState<Activity[]>([]);

  useEffect(() => {
    const fetchData = () => {
      fetch('/_internal/stats').then((r) => r.json()).then(setStats).catch(() => {});
      fetch('/_internal/activity?limit=10').then((r) => r.json()).then(setActivity).catch(() => {});
    };
    fetchData();
    const interval = setInterval(fetchData, 3000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Dashboard</h1>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        <StatCard label="Total Incidents" value={stats.total} color="border-blue-500" />
        <StatCard label="Open" value={stats.open} color="border-green-500" />
        <StatCard label="Closed" value={stats.closed} color="border-gray-400" />
      </div>

      <div className="bg-white rounded-lg shadow border border-snow-border">
        <div className="px-4 py-3 border-b border-snow-border flex items-center justify-between">
          <h2 className="font-semibold text-gray-800">Recent API Activity</h2>
          <Link to="/activity" className="text-sm text-blue-600 hover:text-blue-800">
            View all
          </Link>
        </div>
        <div className="divide-y divide-snow-border">
          {activity.length === 0 ? (
            <div className="px-4 py-8 text-center text-gray-500 text-sm">
              No API calls received yet. Configure the Elastic connector to point here.
            </div>
          ) : (
            activity.map((entry) => (
              <div key={entry.id} className="px-4 py-2 flex items-center gap-3 text-sm">
                <MethodBadge method={entry.method} />
                <span className="font-mono text-xs text-gray-700 truncate flex-1">{entry.path}</span>
                <span className={`text-xs font-medium ${entry.status < 400 ? 'text-green-600' : 'text-red-600'}`}>
                  {entry.status}
                </span>
                <span className="text-xs text-gray-400 whitespace-nowrap">
                  {new Date(entry.timestamp).toLocaleTimeString()}
                </span>
              </div>
            ))
          )}
        </div>
      </div>

      <div className="mt-8 bg-white rounded-lg shadow border border-snow-border p-4">
        <h2 className="font-semibold text-gray-800 mb-3">Connector Configuration</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
          <ConfigItem label="ServiceNow Instance URL" value="https://localhost:3000" />
          <ConfigItem label="Username" value="any value (auth is permissive)" />
          <ConfigItem label="Password" value="any value" />
          <ConfigItem label="Uses Table API" value="false (use Import Set API)" />
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className={`bg-white rounded-lg shadow border-l-4 ${color} p-4`}>
      <p className="text-sm text-gray-500">{label}</p>
      <p className="text-3xl font-bold text-gray-900 mt-1">{value}</p>
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

function ConfigItem({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <span className="text-gray-500">{label}:</span>{' '}
      <code className="bg-gray-100 px-1.5 py-0.5 rounded text-xs">{value}</code>
    </div>
  );
}
