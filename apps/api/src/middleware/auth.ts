import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { config } from "../config";
import { AppError } from "../lib/errors";

export type Role = "ward_officer" | "auditor" | "citizen";
export type User = { user_id: number; username: string; display_name: string; role: Role; ward_code: string | null };

declare global {
  namespace Express { interface Request { user: User } }
}

export function signToken(user: User): string {
  return jwt.sign(user, config.jwtSecret, { expiresIn: "12h" });
}

export function requireAuth(req: Request, _res: Response, next: NextFunction) {
  const token = req.headers.authorization?.replace(/^Bearer /, "");
  if (!token) throw new AppError("not_signed_in", "Please sign in.");
  try {
    const { user_id, username, display_name, role, ward_code } = jwt.verify(token, config.jwtSecret) as User;
    req.user = { user_id, username, display_name, role, ward_code };
  } catch {
    throw new AppError("not_signed_in", "Your session has ended. Please sign in again.");
  }
  next();
}

export function requireRole(...roles: Role[]) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!roles.includes(req.user.role)) throw new AppError("not_allowed", "Your role cannot do this.");
    next();
  };
}

/** A ward officer may act only on their own ward. Returns the ward the request is limited to, if any. */
export function wardScope(user: User, requested?: string): string | undefined {
  if (user.role !== "ward_officer") return requested;
  if (requested && requested !== user.ward_code) throw new AppError("not_allowed", "This is outside your ward.");
  return user.ward_code ?? undefined;
}
