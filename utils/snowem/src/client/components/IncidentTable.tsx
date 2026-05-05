import { Link } from 'react-router-dom';
import { StateBadge, PriorityBadge } from './StatusBadge';

interface Incident {
  sys_id: string;
  number: string;
  short_description: string;
  state: string;
  priority: string;
  urgency: string;
  sys_created_on: string;
  correlation_id: string;
}

export default function IncidentTable({ incidents }: { incidents: Incident[] }) {
  if (incidents.length === 0) {
    return (
      <div className="text-center py-12 text-gray-500">
        <p className="text-lg">No incidents yet</p>
        <p className="text-sm mt-1">Incidents will appear here when the Elastic connector pushes them</p>
      </div>
    );
  }

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-snow-border">
        <thead className="bg-gray-50">
          <tr>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Number</th>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Short Description</th>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">State</th>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Priority</th>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Created</th>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Correlation ID</th>
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-snow-border">
          {incidents.map((inc) => (
            <tr key={inc.sys_id} className="hover:bg-gray-50 transition-colors">
              <td className="px-4 py-3 text-sm">
                <Link to={`/incidents/${inc.sys_id}`} className="text-blue-600 hover:text-blue-800 font-medium">
                  {inc.number}
                </Link>
              </td>
              <td className="px-4 py-3 text-sm text-gray-900 max-w-md truncate">{inc.short_description}</td>
              <td className="px-4 py-3 text-sm"><StateBadge state={inc.state} /></td>
              <td className="px-4 py-3 text-sm"><PriorityBadge priority={inc.priority} /></td>
              <td className="px-4 py-3 text-sm text-gray-500 whitespace-nowrap">{inc.sys_created_on}</td>
              <td className="px-4 py-3 text-sm text-gray-500 font-mono text-xs truncate max-w-[200px]">{inc.correlation_id || '—'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
