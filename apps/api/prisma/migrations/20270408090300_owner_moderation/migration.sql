-- v1.99-social (D311, CONVENTIONS §10.117; owner: «يمكنه حذف او حظر او تحذير اي شخص»): «إجراءات المؤسس» — the app owner's
-- moderation actions from any profile or person card, keyed by the request's clientId (a retry returns the first
-- result). No GRANT: the runtime role gets DML through the default privileges (20261016120000_runtime_role_grants).
CREATE TABLE "owner_moderation_actions" (
    "id" UUID NOT NULL,
    "actor_id" UUID NOT NULL,
    "target_id" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "action" VARCHAR(20) NOT NULL,
    "reason" VARCHAR(500) NOT NULL,
    "days" INTEGER,
    "ends_at" TIMESTAMPTZ(3),
    "purge_after" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "owner_moderation_actions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "owner_moderation_actions_shape" CHECK (
        "action" IN ('WARN', 'SUSPEND', 'BAN', 'DELETE_ACCOUNT')
        AND "actor_id" <> "target_id"
        AND length(btrim("reason")) BETWEEN 1 AND 500
        AND ("action" = 'SUSPEND') = ("days" IS NOT NULL AND "ends_at" IS NOT NULL)
        AND ("days" IS NULL OR "days" BETWEEN 1 AND 365)
        AND ("action" = 'DELETE_ACCOUNT') = ("purge_after" IS NOT NULL))
);
CREATE UNIQUE INDEX "owner_moderation_actions_client_once" ON "owner_moderation_actions" ("actor_id", "client_id");
CREATE INDEX "owner_moderation_actions_target_idx" ON "owner_moderation_actions" ("target_id", "created_at" DESC);
CREATE INDEX "owner_moderation_actions_actor_idx" ON "owner_moderation_actions" ("actor_id", "created_at" DESC);
ALTER TABLE "owner_moderation_actions" ADD CONSTRAINT "owner_moderation_actions_actor_id_fkey" FOREIGN KEY ("actor_id")
    REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "owner_moderation_actions" ADD CONSTRAINT "owner_moderation_actions_target_id_fkey" FOREIGN KEY ("target_id")
    REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE;
