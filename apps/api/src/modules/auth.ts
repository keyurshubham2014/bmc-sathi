import bcrypt from "bcryptjs";
import { Router } from "express";
import { z } from "zod";
import { db } from "../lib/db";
import { AppError, parse } from "../lib/errors";
import { requireAuth, signToken, type User } from "../middleware/auth";

export const auth = Router();

auth.post("/login", async (req, res) => {
  const { username, password } = parse(z.object({ username: z.string().min(1), password: z.string().min(1) }), req.body);
  const row = await db.app_user.findUnique({ where: { username } });
  // Same message for unknown user and wrong password.
  if (!row || !(await bcrypt.compare(password, row.password_hash)))
    throw new AppError("not_signed_in", "Username or password is not correct.");
  const user: User = {
    user_id: row.user_id, username: row.username, display_name: row.display_name,
    role: row.role as User["role"], ward_code: row.ward_code,
  };
  res.json({ token: signToken(user), user });
});

auth.get("/me", requireAuth, (req, res) => res.json({ user: req.user }));
