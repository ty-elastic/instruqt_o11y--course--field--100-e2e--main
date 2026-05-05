import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { StateBadge, PriorityBadge } from '../components/StatusBadge';

interface Incident {
  [key: string]: string;
}

interface JournalEntry {
  value: string;
  created_on: string;
  created_by: string;
}

const displayFields = [
  'number', 'short_description', 'description', 'state', 'impact', 'urgency',
  'priority', 'severity', 'category', 'subcategory', 'assignment_group',
  'assigned_to', 'caller_id', 'opened_by', 'correlation_id', 'correlation_display',
  'close_code', 'close_notes',
  'sys_created_on', 'sys_updated_on', 'sys_created_by', 'sys_updated_by', 'active',
];

export default function IncidentDetail() {
  const { sysId } = useParams<{ sysId: string }>();
  const [incident, setIncident] = useState<Incident | null>(null);
  const [workNotes, setWorkNotes] = useState<JournalEntry[]>([]);
  const [comments, setComments] = useState<JournalEntry[]>([]);
  const [notFound, setNotFound] = useState(false);

  useEffect(() => {
    if (!sysId) return;
    fetch(`/_internal/incidents/${sysId}`)
      .then((r) => {
        if (!r.ok) { setNotFound(true); return null; }
        return r.json();
      })
      .then((data) => { if (data) setIncident(data); })
      .catch(() => setNotFound(true));

    fetch(`/_internal/incidents/${sysId}/journal/work_notes`)
      .then((r) => r.ok ? r.json() : [])
      .then(setWorkNotes)
      .catch(() => {});

    fetch(`/_internal/incidents/${sysId}/journal/comments`)
      .then((r) => r.ok ? r.json() : [])
      .then(setComments)
      .catch(() => {});
  }, [sysId]);

  if (notFound) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-500 text-lg">Incident not found</p>
        <Link to="/incidents" className="text-blue-600 hover:text-blue-800 text-sm mt-2 inline-block">
          Back to incidents
        </Link>
      </div>
    );
  }

  if (!incident) {
    return <div className="text-center py-12 text-gray-500">Loading...</div>;
  }

  return (
    <div>
      <div className="flex items-center gap-3 mb-6">
        <Link to="/incidents" className="text-blue-600 hover:text-blue-800 text-sm">&larr; Back</Link>
        <h1 className="text-2xl font-bold text-gray-900">{incident.number}</h1>
        <StateBadge state={incident.state} />
        <PriorityBadge priority={incident.priority} />
      </div>

      <div className="bg-white rounded-lg shadow border border-snow-border">
        <div className="px-4 py-3 border-b border-snow-border">
          <h2 className="font-semibold text-gray-800">{incident.short_description || 'No description'}</h2>
        </div>
        <div className="divide-y divide-snow-border">
          {displayFields.map((field) => {
            const value = incident[field];
            if (!value && field !== 'state' && field !== 'active') return null;
            return (
              <div key={field} className="px-4 py-2 grid grid-cols-3 gap-4 text-sm">
                <span className="text-gray-500 font-medium">{formatFieldName(field)}</span>
                <span className="col-span-2 text-gray-900 break-words">
                  {field === 'state' ? <StateBadge state={value} /> :
                   field === 'priority' ? <PriorityBadge priority={value} /> :
                   value || '—'}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      {(workNotes.length > 0 || comments.length > 0) && (
        <div className="mt-4 grid grid-cols-1 lg:grid-cols-2 gap-4">
          <JournalSection title="Work Notes" entries={workNotes} />
          <JournalSection title="Additional Comments" entries={comments} />
        </div>
      )}

      <div className="mt-4 bg-white rounded-lg shadow border border-snow-border p-4">
        <h3 className="font-semibold text-gray-800 mb-2 text-sm">sys_id</h3>
        <code className="text-xs bg-gray-100 px-2 py-1 rounded break-all">{incident.sys_id}</code>
      </div>
    </div>
  );
}

function JournalSection({ title, entries }: { title: string; entries: JournalEntry[] }) {
  if (entries.length === 0) return null;

  return (
    <div className="bg-white rounded-lg shadow border border-snow-border">
      <div className="px-4 py-3 border-b border-snow-border">
        <h3 className="font-semibold text-gray-800 text-sm">{title} ({entries.length})</h3>
      </div>
      <div className="divide-y divide-snow-border max-h-80 overflow-y-auto">
        {entries.map((entry, i) => (
          <div key={i} className="px-4 py-3">
            <div className="flex items-center justify-between mb-1">
              <span className="text-xs font-medium text-gray-500">{entry.created_by}</span>
              <span className="text-xs text-gray-400">{entry.created_on}</span>
            </div>
            <p className="text-sm text-gray-900 whitespace-pre-wrap">{entry.value}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

function formatFieldName(field: string): string {
  return field
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase())
    .replace(/^Sys /, 'Sys ');
}
