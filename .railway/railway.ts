// Railway project definition. Applied to production by .github/workflows/railway-config.yml
// after merge; preview locally with `railway config plan`. Secrets never go here: set them in
// Railway as sealed variables and reference them with preserve().
// Fields marked "SDK" come from the `railway` package types rather than the IaC docs page.
import { defineRailway, github, postgres, project, service } from "railway/iac";

const REPO = "afframe/afframe";
const EU_WEST = "europe-west4-drams3a";

export default defineRailway(() => {
  const db = postgres("postgres", { region: EU_WEST });

  // TEMPORARY pipeline fixture. Remove this block and apps/placeholder/ in one PR when the real
  // web app lands; the apply then needs the "confirm destructive" manual run (docs/railway.md).
  const placeholder = service("placeholder", {
    source: github(REPO, {
      branch: "main",
      rootDirectory: "apps/placeholder",
      checkSuites: true, // SDK: Railway "Wait for CI"
    }),
    build: {
      builder: "DOCKERFILE", // SDK
      watchPatterns: ["apps/placeholder/**"], // SDK: only rebuild when this service changes
    },
    deploy: {
      sleepApplication: true, // SDK: serverless, sleeps after ~10 min without outbound traffic
      restartPolicyType: "ON_FAILURE", // SDK
    },
    healthcheck: "/health",
    healthcheckTimeout: 60,
    replicas: { [EU_WEST]: 1 },
  });

  return project("afframe", { resources: [db, placeholder] });
});
