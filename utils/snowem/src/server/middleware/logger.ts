import { Request, Response, NextFunction } from 'express';
import { store } from '../store.js';

export function activityLogger(req: Request, res: Response, next: NextFunction) {
  if (!req.path.startsWith('/api')) {
    next();
    return;
  }

  const originalJson = res.json.bind(res);
  res.json = (body: unknown) => {
    store.logActivity({
      method: req.method,
      path: req.path,
      status: res.statusCode,
      body: req.method !== 'GET' ? req.body : undefined,
      response: body,
    });
    return originalJson(body);
  };

  next();
}
