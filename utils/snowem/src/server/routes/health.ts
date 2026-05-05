import { Router } from 'express';

const router = Router();

router.get('/api/x_elas2_inc_int/elastic_api/health', (_req, res) => {
  res.json({
    result: {
      version: '2.3.0',
      scope: 'x_elas2_inc_int',
      name: 'Elastic for ITSM',
    },
  });
});

router.get('/api/x_elas2_sir_int/elastic_api/health', (_req, res) => {
  res.json({
    result: {
      version: '2.3.0',
      scope: 'x_elas2_sir_int',
      name: 'Elastic for Security Operations',
    },
  });
});

export default router;
