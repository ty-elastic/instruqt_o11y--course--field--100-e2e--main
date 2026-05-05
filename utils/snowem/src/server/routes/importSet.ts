import { Router, Request, Response } from 'express';
import { store } from '../store.js';

const router = Router();

function stripUPrefix(fields: Record<string, unknown>): Record<string, string> {
  const result: Record<string, string> = {};
  for (const [key, value] of Object.entries(fields)) {
    if (key === 'elastic_incident_id') continue;
    const cleanKey = key.startsWith('u_') ? key.slice(2) : key;
    result[cleanKey] = String(value ?? '');
  }
  return result;
}

router.post('/api/now/import/:table', (req: Request, res: Response) => {
  const body = req.body as Record<string, unknown>;
  const elasticIncidentId = body.elastic_incident_id as string | undefined;
  const fields = stripUPrefix(body);

  if (elasticIncidentId) {
    const updated = store.update(elasticIncidentId, fields);
    if (updated) {
      res.status(200).json({
        result: [
          {
            transform_map: 'Elastic Incident',
            table: 'incident',
            display_name: 'number',
            display_value: updated.number,
            record_link: `/api/now/v2/table/incident/${updated.sys_id}`,
            status: 'updated',
            sys_id: updated.sys_id,
          },
        ],
      });
      return;
    }
  }

  const incident = store.create(fields);
  res.status(201).json({
    result: [
      {
        transform_map: 'Elastic Incident',
        table: 'incident',
        display_name: 'number',
        display_value: incident.number,
        record_link: `/api/now/v2/table/incident/${incident.sys_id}`,
        status: 'inserted',
        sys_id: incident.sys_id,
      },
    ],
  });
});

export default router;
