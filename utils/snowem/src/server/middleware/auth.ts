import { Request, Response, NextFunction } from 'express';

export function basicAuth(req: Request, _res: Response, next: NextFunction) {
  // For demo purposes, accept all requests regardless of auth header.
  // The connector sends Basic or OAuth — we don't care which.
  // Just log if auth is present for debugging.
  if (req.path.startsWith('/api') && !req.headers.authorization) {
    console.log(`[auth] No authorization header on ${req.method} ${req.path}`);
  }
  next();
}
