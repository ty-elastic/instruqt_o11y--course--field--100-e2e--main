import { v4 as uuidv4 } from 'uuid';

export interface JournalEntry {
  value: string;
  created_on: string;
  created_by: string;
}

export interface Incident {
  sys_id: string;
  number: string;
  short_description: string;
  description: string;
  state: string;
  impact: string;
  urgency: string;
  priority: string;
  severity: string;
  category: string;
  subcategory: string;
  assignment_group: string;
  assigned_to: string;
  caller_id: string;
  opened_by: string;
  correlation_id: string;
  correlation_display: string;
  close_code: string;
  close_notes: string;
  work_notes: string;
  comments: string;
  sys_created_on: string;
  sys_updated_on: string;
  sys_created_by: string;
  sys_updated_by: string;
  active: string;
  [key: string]: string;
}

export interface ActivityEntry {
  id: string;
  timestamp: string;
  method: string;
  path: string;
  status: number;
  body?: unknown;
  response?: unknown;
}

const JOURNAL_FIELDS = new Set(['work_notes', 'comments']);

function nowTimestamp(): string {
  return new Date().toISOString().replace('T', ' ').replace('Z', '');
}

function defaultIncident(): Incident {
  return {
    sys_id: '',
    number: '',
    short_description: '',
    description: '',
    state: '1',
    impact: '3',
    urgency: '3',
    priority: '4',
    severity: '3',
    category: '',
    subcategory: '',
    assignment_group: '',
    assigned_to: '',
    caller_id: '',
    opened_by: '',
    correlation_id: '',
    correlation_display: '',
    close_code: '',
    close_notes: '',
    work_notes: '',
    comments: '',
    sys_created_on: '',
    sys_updated_on: '',
    sys_created_by: 'system',
    sys_updated_by: 'system',
    active: 'true',
  };
}

class IncidentStore {
  private incidents: Map<string, Incident> = new Map();
  private correlationIndex: Map<string, string> = new Map();
  private journalEntries: Map<string, JournalEntry[]> = new Map();
  private nextNumber = 10001;
  private activityLog: ActivityEntry[] = [];
  private maxActivity = 500;

  generateNumber(): string {
    const num = this.nextNumber++;
    return `INC${String(num).padStart(7, '0')}`;
  }

  private journalKey(sysId: string, field: string): string {
    return `${sysId}:${field}`;
  }

  create(fields: Partial<Incident>): Incident {
    const sysId = uuidv4();
    const now = nowTimestamp();
    const incident: Incident = {
      ...defaultIncident(),
      ...fields,
      sys_id: sysId,
      number: this.generateNumber(),
      sys_created_on: now,
      sys_updated_on: now,
      active: 'true',
    };

    // Initialize journal entries for journal fields that have initial values
    for (const field of JOURNAL_FIELDS) {
      if (incident[field]) {
        const key = this.journalKey(sysId, field);
        this.journalEntries.set(key, [{
          value: incident[field],
          created_on: now,
          created_by: incident.sys_created_by || 'system',
        }]);
      }
    }

    this.incidents.set(sysId, incident);
    if (incident.correlation_id) {
      this.correlationIndex.set(incident.correlation_id, sysId);
    }
    return incident;
  }

  update(sysId: string, fields: Partial<Incident>): Incident | null {
    const existing = this.incidents.get(sysId);
    if (!existing) return null;

    const now = nowTimestamp();

    // Handle journal fields: append rather than overwrite
    for (const field of JOURNAL_FIELDS) {
      if (fields[field] && fields[field].trim()) {
        const key = this.journalKey(sysId, field);
        const entries = this.journalEntries.get(key) || [];
        entries.push({
          value: fields[field],
          created_on: now,
          created_by: fields.sys_updated_by || existing.sys_updated_by || 'system',
        });
        this.journalEntries.set(key, entries);
        // Keep the latest value in the flat field (matches SNOW behavior for display)
        fields[field] = fields[field];
      }
    }

    const updated: Incident = {
      ...existing,
      ...fields,
      sys_id: existing.sys_id,
      number: existing.number,
      sys_created_on: existing.sys_created_on,
      sys_updated_on: now,
    };

    if (updated.state === '7') {
      updated.active = 'false';
    }

    this.incidents.set(sysId, updated);
    if (updated.correlation_id && updated.correlation_id !== existing.correlation_id) {
      if (existing.correlation_id) {
        this.correlationIndex.delete(existing.correlation_id);
      }
      this.correlationIndex.set(updated.correlation_id, sysId);
    }
    return updated;
  }

  get(sysId: string): Incident | null {
    return this.incidents.get(sysId) ?? null;
  }

  getJournal(sysId: string, field: string): JournalEntry[] {
    return this.journalEntries.get(this.journalKey(sysId, field)) || [];
  }

  findByCorrelationId(correlationId: string): Incident | null {
    const sysId = this.correlationIndex.get(correlationId);
    if (!sysId) return null;
    return this.incidents.get(sysId) ?? null;
  }

  findByQuery(query: string): Incident[] {
    if (query.includes('correlation_id=')) {
      const match = query.match(/correlation_id=([^&^]+)/);
      if (match) {
        const incident = this.findByCorrelationId(match[1]);
        return incident ? [incident] : [];
      }
    }
    return Array.from(this.incidents.values()).sort(
      (a, b) => b.sys_created_on.localeCompare(a.sys_created_on)
    );
  }

  getAll(): Incident[] {
    return Array.from(this.incidents.values()).sort(
      (a, b) => b.sys_created_on.localeCompare(a.sys_created_on)
    );
  }

  getStats() {
    const all = this.getAll();
    const open = all.filter((i) => i.active === 'true').length;
    const closed = all.filter((i) => i.active === 'false').length;
    return { total: all.length, open, closed };
  }

  logActivity(entry: Omit<ActivityEntry, 'id' | 'timestamp'>) {
    this.activityLog.unshift({
      ...entry,
      id: uuidv4(),
      timestamp: new Date().toISOString(),
    });
    if (this.activityLog.length > this.maxActivity) {
      this.activityLog = this.activityLog.slice(0, this.maxActivity);
    }
  }

  getActivity(limit = 50): ActivityEntry[] {
    return this.activityLog.slice(0, limit);
  }
}

export const store = new IncidentStore();
