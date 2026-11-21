import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import cors from "cors";
import express, { type NextFunction, type Request, type Response } from "express";
import { config } from "./config";
import { AppError } from "./lib/errors";
import { requireAuth } from "./middleware/auth";
import { auth } from "./modules/auth";
import { flags } from "./modules/flags";
import { ask } from "./modules/ask";
import { contractors } from "./modules/contractors";
import { intake } from "./modules/intake";
import { settings } from "./modules/settings";
import { trail } from "./modules/trail";
import { wards } from "./modules/wards";

export const app = express();
// Postgres bigint and numeric arrive as BigInt and Decimal; send both as plain numbers.
app.set("json replacer", (_k: string, v: unknown) =>
  typeof v === "bigint" ? Number(v) : v && typeof v === "object" && (v as any).constructor?.name === "Decimal" ? Number(v) : v);
app.use(cors({ origin: config.webOrigin }));
app.use(express.json({ limit: "100kb" }));

// One line per request. Never logs bodies or tokens.
app.use((req, res, next) => {
  const start = Date.now();
  res.on("finish", () => {
    if (process.env.NODE_ENV !== "test")
      console.log(`${req.method} ${req.baseUrl}${req.route?.path ?? req.path} ${res.statusCode} ${Date.now() - start}ms user=${req.user?.user_id ?? "-"}`);
  });
  next();
});

const api = express.Router();
api.use("/auth", auth);
api.use(requireAuth);
api.use("/wards", wards);
api.use("/flags", flags);
api.use("/contractors", contractors);
api.use("/settings", settings);
api.use("/intake", intake);
api.use("/ask", ask);
api.use("/trail", trail);
app.use("/api/v1", api);

// Production: serve the Flutter web build (copied to apps/api/public) from the same origin.
const web = fileURLToPath(new URL("../public", import.meta.url));
app.use(express.static(web));
app.get(/^(?!\/api\/).*/, (_req, res) => res.sendFile("index.html", { root: web }));

app.use((_req, _res, next) => next(new AppError("not_found", "No such route.")));

app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
  if (err instanceof AppError) return void res.status(err.status).json({ code: err.code, message: err.message, fields: err.fields });
  if ((err as any)?.type === "entity.parse.failed") return void res.status(400).json({ code: "validation_failed", message: "The request body is not valid JSON." });
  const request_id = randomUUID();
  console.error(request_id, err);
  res.status(500).json({ code: "server_error", message: "Something went wrong on the server.", request_id });
});
