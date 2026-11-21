import { app } from "./app";
import { config } from "./config";
import { db } from "./lib/db";

// Refuse to start without a database and the audit views.
try {
  await db.$queryRaw`SELECT 1 FROM v_flag LIMIT 1`;
} catch (e) {
  console.error("Cannot start: the database is unreachable or the views are missing. Run `npm run db:setup`.\n", e);
  process.exit(1);
}

const server = app.listen(config.port, () => console.log(`BMC Sathi API on http://localhost:${config.port}/api/v1`));
for (const sig of ["SIGINT", "SIGTERM"] as const)
  process.on(sig, () => server.close(() => db.$disconnect().then(() => process.exit(0))));
