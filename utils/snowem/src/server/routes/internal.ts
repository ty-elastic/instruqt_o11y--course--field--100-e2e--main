import { Router } from 'express';
import { store } from '../store.js';

const router = Router();

router.get('/_internal/incidents', (_req, res) => {
  res.json(store.getAll());
});

router.get('/_internal/incidents/:sysId', (req, res) => {
  const incident = store.get(req.params.sysId);
  if (!incident) {
    res.status(404).json({ error: 'Not found' });
    return;
  }
  res.json(incident);
});

router.get('/_internal/incidents/:sysId/journal/:field', (req, res) => {
  const { sysId, field } = req.params;
  const incident = store.get(sysId);
  if (!incident) {
    res.status(404).json({ error: 'Not found' });
    return;
  }
  res.json(store.getJournal(sysId, field));
});

router.get('/_internal/stats', (_req, res) => {
  res.json(store.getStats());
});

router.get('/_internal/activity', (req, res) => {
  const limit = parseInt(req.query.limit as string) || 50;
  res.json(store.getActivity(limit));
});

export default router;
