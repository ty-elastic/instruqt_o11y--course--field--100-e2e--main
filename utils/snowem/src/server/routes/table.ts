import { Router, Request, Response } from 'express';
import { store } from '../store.js';

const router = Router();

router.get('/api/now/v2/table/incident/:sysId', (req: Request, res: Response) => {
  const incident = store.get(req.params.sysId);
  if (!incident) {
    res.status(404).json({ error: { message: 'Record not found' } });
    return;
  }
  res.json({ result: incident });
});

router.get('/api/now/v2/table/incident', (req: Request, res: Response) => {
  const query = (req.query.sysparm_query as string) || '';
  const results = store.findByQuery(query);
  res.json({ result: results });
});

router.patch('/api/now/v2/table/incident/:sysId', (req: Request, res: Response) => {
  const fields = req.body as Record<string, string>;
  const updated = store.update(req.params.sysId, fields);
  if (!updated) {
    res.status(404).json({ error: { message: 'Record not found' } });
    return;
  }
  res.json({ result: updated });
});

router.get('/api/now/table/sys_dictionary', (_req: Request, res: Response) => {
  res.json({
    result: [
      { element: 'short_description', column_label: 'Short description', max_length: '160', mandatory: 'true' },
      { element: 'description', column_label: 'Description', max_length: '4000', mandatory: 'false' },
      { element: 'category', column_label: 'Category', max_length: '40', mandatory: 'false' },
      { element: 'subcategory', column_label: 'Subcategory', max_length: '40', mandatory: 'false' },
      { element: 'assignment_group', column_label: 'Assignment group', max_length: '32', mandatory: 'false' },
      { element: 'assigned_to', column_label: 'Assigned to', max_length: '32', mandatory: 'false' },
      { element: 'caller_id', column_label: 'Caller', max_length: '32', mandatory: 'false' },
      { element: 'opened_by', column_label: 'Opened by', max_length: '32', mandatory: 'false' },
      { element: 'close_code', column_label: 'Close code', max_length: '40', mandatory: 'false' },
      { element: 'close_notes', column_label: 'Close notes', max_length: '4000', mandatory: 'false' },
      { element: 'work_notes', column_label: 'Work notes', max_length: '4000', mandatory: 'false' },
      { element: 'comments', column_label: 'Additional comments', max_length: '4000', mandatory: 'false' },
      { element: 'correlation_id', column_label: 'Correlation ID', max_length: '100', mandatory: 'false' },
      { element: 'correlation_display', column_label: 'Correlation display', max_length: '100', mandatory: 'false' },
    ],
  });
});

const ALL_CHOICES: Array<{ label: string; value: string; dependent_value: string; element: string }> = [
  { label: '1 - High', value: '1', dependent_value: '', element: 'urgency' },
  { label: '2 - Medium', value: '2', dependent_value: '', element: 'urgency' },
  { label: '3 - Low', value: '3', dependent_value: '', element: 'urgency' },
  { label: '1 - High', value: '1', dependent_value: '', element: 'severity' },
  { label: '2 - Medium', value: '2', dependent_value: '', element: 'severity' },
  { label: '3 - Low', value: '3', dependent_value: '', element: 'severity' },
  { label: '1 - High', value: '1', dependent_value: '', element: 'impact' },
  { label: '2 - Medium', value: '2', dependent_value: '', element: 'impact' },
  { label: '3 - Low', value: '3', dependent_value: '', element: 'impact' },
  { label: '1 - Critical', value: '1', dependent_value: '', element: 'priority' },
  { label: '2 - High', value: '2', dependent_value: '', element: 'priority' },
  { label: '3 - Moderate', value: '3', dependent_value: '', element: 'priority' },
  { label: '4 - Low', value: '4', dependent_value: '', element: 'priority' },
  { label: '5 - Planning', value: '5', dependent_value: '', element: 'priority' },
  { label: 'New', value: '1', dependent_value: '', element: 'state' },
  { label: 'In Progress', value: '2', dependent_value: '', element: 'state' },
  { label: 'On Hold', value: '3', dependent_value: '', element: 'state' },
  { label: 'Resolved', value: '6', dependent_value: '', element: 'state' },
  { label: 'Closed', value: '7', dependent_value: '', element: 'state' },
  { label: 'Inquiry / Help', value: 'inquiry', dependent_value: '', element: 'category' },
  { label: 'Software', value: 'software', dependent_value: '', element: 'category' },
  { label: 'Hardware', value: 'hardware', dependent_value: '', element: 'category' },
  { label: 'Network', value: 'network', dependent_value: '', element: 'category' },
  { label: 'Database', value: 'database', dependent_value: '', element: 'category' },
  { label: 'Inquiry / Help', value: 'inquiry', dependent_value: 'inquiry', element: 'subcategory' },
  { label: 'Email', value: 'email', dependent_value: 'software', element: 'subcategory' },
  { label: 'Internal Application', value: 'internal_application', dependent_value: 'software', element: 'subcategory' },
  { label: 'Wireless', value: 'wireless', dependent_value: 'network', element: 'subcategory' },
  { label: 'VPN', value: 'vpn', dependent_value: 'network', element: 'subcategory' },
  { label: 'DB2', value: 'db2', dependent_value: 'database', element: 'subcategory' },
  { label: 'Oracle', value: 'oracle', dependent_value: 'database', element: 'subcategory' },
];

function extractRequestedElements(query: string): Set<string> | null {
  // Parse ServiceNow-style query to extract which elements are requested
  // e.g. "name=task^ORname=incident^element=urgency^ORelement=severity^language=en"
  const elements = new Set<string>();
  const matches = query.matchAll(/(?:^|OR)?element=([a-z_]+)/gi);
  for (const match of matches) {
    elements.add(match[1]);
  }
  return elements.size > 0 ? elements : null;
}

router.get('/api/now/table/sys_choice', (req: Request, res: Response) => {
  const query = (req.query.sysparm_query as string) || '';

  const requestedElements = extractRequestedElements(query);

  let choices: typeof ALL_CHOICES;
  if (requestedElements) {
    choices = ALL_CHOICES.filter((c) => requestedElements.has(c.element));
  } else {
    // No specific elements requested — return all choices
    choices = ALL_CHOICES;
  }

  res.json({ result: choices });
});

export default router;
