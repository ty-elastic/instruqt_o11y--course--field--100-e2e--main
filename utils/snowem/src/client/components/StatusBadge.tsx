const stateMap: Record<string, { label: string; color: string }> = {
  '1': { label: 'New', color: 'bg-blue-100 text-blue-800' },
  '2': { label: 'In Progress', color: 'bg-yellow-100 text-yellow-800' },
  '3': { label: 'On Hold', color: 'bg-orange-100 text-orange-800' },
  '6': { label: 'Resolved', color: 'bg-green-100 text-green-800' },
  '7': { label: 'Closed', color: 'bg-gray-100 text-gray-800' },
};

const priorityMap: Record<string, { label: string; color: string }> = {
  '1': { label: 'Critical', color: 'bg-red-100 text-red-800' },
  '2': { label: 'High', color: 'bg-orange-100 text-orange-800' },
  '3': { label: 'Moderate', color: 'bg-yellow-100 text-yellow-800' },
  '4': { label: 'Low', color: 'bg-blue-100 text-blue-800' },
  '5': { label: 'Planning', color: 'bg-gray-100 text-gray-600' },
};

export function StateBadge({ state }: { state: string }) {
  const info = stateMap[state] || { label: `State ${state}`, color: 'bg-gray-100 text-gray-600' };
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${info.color}`}>
      {info.label}
    </span>
  );
}

export function PriorityBadge({ priority }: { priority: string }) {
  const info = priorityMap[priority] || { label: `P${priority}`, color: 'bg-gray-100 text-gray-600' };
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${info.color}`}>
      {info.label}
    </span>
  );
}
