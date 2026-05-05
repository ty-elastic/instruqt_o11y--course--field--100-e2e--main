import { useEffect, useState } from 'react';
import IncidentTable from '../components/IncidentTable';

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

export default function IncidentList() {
  const [incidents, setIncidents] = useState<Incident[]>([]);

  useEffect(() => {
    const fetchData = () => {
      fetch('/_internal/incidents').then((r) => r.json()).then(setIncidents).catch(() => {});
    };
    fetchData();
    const interval = setInterval(fetchData, 3000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Incidents</h1>
        <span className="text-sm text-gray-500">{incidents.length} total</span>
      </div>
      <div className="bg-white rounded-lg shadow border border-snow-border">
        <IncidentTable incidents={incidents} />
      </div>
    </div>
  );
}
