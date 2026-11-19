-- 01_schema.sql
-- Физическая модель БД + индексы

CREATE TABLE "roles" (
  "role_id" serial PRIMARY KEY,
  "code" varchar(30) UNIQUE NOT NULL,
  "name" varchar(100) NOT NULL
);

CREATE TABLE "users" (
  "user_id" bigserial PRIMARY KEY,
  "email" varchar(255) UNIQUE NOT NULL,
  "username" varchar(30) UNIQUE NOT NULL,
  "password_hash" varchar(255) NOT NULL,
  "is_active" boolean NOT NULL DEFAULT true,
  "email_verified" boolean NOT NULL DEFAULT false,
  "last_login_at" timestamptz,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "updated_at" timestamptz NOT NULL DEFAULT (now()),
  "deleted_at" timestamptz
);

CREATE TABLE "user_roles" (
  "user_id" bigint NOT NULL,
  "role_id" int NOT NULL,
  "assigned_at" timestamptz NOT NULL DEFAULT (now()),
  "assigned_by" bigint,
  PRIMARY KEY ("user_id", "role_id")
);

CREATE TABLE "players" (
  "player_id" bigserial PRIMARY KEY,
  "user_id" bigint UNIQUE,
  "nickname" varchar(50) UNIQUE NOT NULL,
  "real_name" varchar(100),
  "country" char(2),
  "birth_date" date,
  "is_banned" boolean NOT NULL DEFAULT false,
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "teams" (
  "team_id" bigserial PRIMARY KEY,
  "name" varchar(100) UNIQUE NOT NULL,
  "tag" varchar(10) UNIQUE,
  "logo_url" text,
  "created_by" bigint,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  "disbanded_at" timestamptz
);

CREATE TABLE "team_members" (
  "team_id" bigint NOT NULL,
  "player_id" bigint NOT NULL,
  "joined_at" date NOT NULL DEFAULT (CURRENT_DATE),
  "role" varchar(20),
  "left_at" date,
  CHECK (left_at IS NULL OR left_at >= joined_at),
  CHECK (role IS NULL OR role IN ('captain', 'player', 'coach')),
  PRIMARY KEY ("team_id", "player_id", "joined_at")
);

CREATE TABLE "applications" (
  "application_id" bigserial PRIMARY KEY,
  "team_id" bigint NOT NULL,
  "player_id" bigint NOT NULL,
  "message" text,
  "status" varchar(20) NOT NULL DEFAULT 'pending',
  "reviewed_by" bigint,
  "reviewed_at" timestamptz,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  CHECK ((reviewed_by IS NULL AND reviewed_at IS NULL) OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
);

CREATE TABLE "tournaments" (
  "tournament_id" bigserial PRIMARY KEY,
  "name" varchar(150) NOT NULL,
  "description" text,
  "format" varchar(30) NOT NULL,
  "status" varchar(20) NOT NULL DEFAULT 'draft',
  "prize_pool" numeric(12,2),
  "max_teams" smallint,
  "starts_at" timestamptz,
  "ends_at" timestamptz,
  "created_by" bigint,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  CHECK (format IN ('single_elim', 'double_elim', 'round_robin')),
  CHECK (status IN ('draft', 'registration', 'ongoing', 'finished', 'cancelled')),
  CHECK (prize_pool IS NULL OR prize_pool >= 0),
  CHECK (max_teams IS NULL OR max_teams >= 2)
);

CREATE TABLE "tournament_participants" (
  "tournament_id" bigint NOT NULL,
  "team_id" bigint NOT NULL,
  "seed" int,
  "registered_at" timestamptz NOT NULL DEFAULT (now()),
  PRIMARY KEY ("tournament_id", "team_id")
);

CREATE TABLE "matches" (
  "match_id" bigserial PRIMARY KEY,
  "tournament_id" bigint NOT NULL,
  "round_number" smallint,
  "match_number" smallint,
  "team_a_id" bigint,
  "team_b_id" bigint,
  "best_of" smallint NOT NULL DEFAULT 1,
  "score_a" smallint NOT NULL DEFAULT 0,
  "score_b" smallint NOT NULL DEFAULT 0,
  "status" varchar(20) NOT NULL DEFAULT 'scheduled',
  "scheduled_at" timestamptz,
  "finished_at" timestamptz,
  "next_match_id" bigint,
  "next_slot" char(1),
  CHECK (team_a_id IS NULL OR team_b_id IS NULL OR team_a_id <> team_b_id),
  CHECK (best_of IN (1, 3, 5)),
  CHECK (score_a >= 0 AND score_b >= 0),
  CHECK (status IN ('scheduled', 'live', 'pending_review', 'finished', 'cancelled')),
  CHECK (next_slot IN ('A', 'B'))
);

CREATE TABLE "match_games" (
  "match_id" bigint NOT NULL,
  "game_number" smallint NOT NULL,
  "map_name" varchar(50),
  "score_a" smallint NOT NULL DEFAULT 0,
  "score_b" smallint NOT NULL DEFAULT 0,
  "submitted_by" bigint,
  "approved_by" bigint,
  "approved_at" timestamptz,
  CHECK (game_number >= 1),
  CHECK (score_a >= 0 AND score_b >= 0),
  CHECK ((approved_by IS NULL AND approved_at IS NULL) OR (approved_by IS NOT NULL AND approved_at IS NOT NULL)),
  PRIMARY KEY ("match_id", "game_number")
);

CREATE TABLE "tickets" (
  "ticket_id" bigserial PRIMARY KEY,
  "author_id" bigint,
  "subject" varchar(200) NOT NULL,
  "body" text NOT NULL,
  "category" varchar(30) NOT NULL,
  "status" varchar(20) NOT NULL DEFAULT 'open',
  "priority" varchar(10) NOT NULL DEFAULT 'normal',
  "entity_type" varchar(30),
  "entity_id" bigint,
  "assigned_to" bigint,
  "resolved_at" timestamptz,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  CHECK (category IN ('cheating', 'conduct', 'bug', 'other')),
  CHECK (status IN ('open', 'in_progress', 'resolved', 'rejected')),
  CHECK (priority IN ('low', 'normal', 'high')),
  CHECK (entity_type IN ('player', 'team', 'match', 'tournament')),
  CHECK ((entity_type IS NULL AND entity_id IS NULL) OR (entity_type IS NOT NULL AND entity_id IS NOT NULL)),
  CHECK ((status = 'resolved' AND resolved_at IS NOT NULL) OR (status <> 'resolved' AND resolved_at IS NULL))
);

CREATE TABLE "audit_log" (
  "id" bigserial PRIMARY KEY,
  "user_id" bigint,
  "action" varchar(50) NOT NULL,
  "entity_type" varchar(50),
  "entity_id" bigint,
  "old_values" jsonb,
  "new_values" jsonb,
  "ip_address" inet,
  "user_agent" text,
  "created_at" timestamptz NOT NULL DEFAULT (now())
);

CREATE TABLE "login_attempts" (
  "id" bigserial PRIMARY KEY,
  "user_id" bigint,
  "username" varchar(30) NOT NULL,
  "success" boolean NOT NULL,
  "failure_reason" varchar(30),
  "ip_address" inet,
  "user_agent" text,
  "created_at" timestamptz NOT NULL DEFAULT (now()),
  CHECK (failure_reason IN ('user_not_found', 'wrong_password', 'account_disabled', 'rate_limited'))
);

-- ============================================================
-- ИНДЕКСЫ
-- ============================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_matches_unique_round ON "matches" ("tournament_id", "round_number", "match_number");

CREATE INDEX IF NOT EXISTS idx_users_active ON users (is_active) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_deleted_at ON users (deleted_at) WHERE deleted_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_players_country ON players (country);
CREATE INDEX IF NOT EXISTS idx_players_banned ON players (is_banned) WHERE is_banned = TRUE;
CREATE INDEX IF NOT EXISTS idx_players_user_id ON players (user_id) WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_teams_active ON teams (team_id) WHERE disbanded_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_teams_tag_lower ON teams (LOWER(tag));

CREATE INDEX IF NOT EXISTS idx_team_members_active ON team_members (team_id, player_id) WHERE left_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_team_members_player ON team_members (player_id);

CREATE INDEX IF NOT EXISTS idx_applications_pending ON applications (team_id, created_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_applications_player ON applications (player_id);

CREATE INDEX IF NOT EXISTS idx_tournaments_status ON tournaments (status, starts_at);
CREATE INDEX IF NOT EXISTS idx_tournaments_prize ON tournaments (prize_pool DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_tp_tournament_seed ON tournament_participants (tournament_id, seed NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_tp_team ON tournament_participants (team_id);

CREATE INDEX IF NOT EXISTS idx_matches_tournament_round ON matches (tournament_id, round_number, match_number);
CREATE INDEX IF NOT EXISTS idx_matches_status ON matches (status) WHERE status IN ('live', 'pending_review');
CREATE INDEX IF NOT EXISTS idx_matches_team_a ON matches (team_a_id) WHERE team_a_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_matches_team_b ON matches (team_b_id) WHERE team_b_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_matches_scheduled ON matches (scheduled_at) WHERE scheduled_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_matches_next ON matches (next_match_id) WHERE next_match_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_match_games_pending_approval ON match_games (match_id) WHERE approved_by IS NULL;

CREATE INDEX IF NOT EXISTS idx_tickets_open ON tickets (status, priority, created_at) WHERE status IN ('open', 'in_progress');
CREATE INDEX IF NOT EXISTS idx_tickets_assigned ON tickets (assigned_to) WHERE assigned_to IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tickets_entity ON tickets (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_tickets_author ON tickets (author_id);

CREATE INDEX IF NOT EXISTS idx_audit_user_action ON audit_log (user_id, action, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_log (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_log (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_login_attempts_username_time ON login_attempts (username, created_at DESC) WHERE success = FALSE;

CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles (role_id);

-- ============================================================
-- ВНЕШНИЕ КЛЮЧИ (FK)
-- ============================================================
ALTER TABLE "user_roles" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("user_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "user_roles" ADD FOREIGN KEY ("role_id") REFERENCES "roles" ("role_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "user_roles" ADD FOREIGN KEY ("assigned_by") REFERENCES "users" ("user_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "players" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("user_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "teams" ADD FOREIGN KEY ("created_by") REFERENCES "users" ("user_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "team_members" ADD FOREIGN KEY ("team_id") REFERENCES "teams" ("team_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "team_members" ADD FOREIGN KEY ("player_id") REFERENCES "players" ("player_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "applications" ADD FOREIGN KEY ("team_id") REFERENCES "teams" ("team_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "applications" ADD FOREIGN KEY ("player_id") REFERENCES "players" ("player_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "applications" ADD FOREIGN KEY ("reviewed_by") REFERENCES "users" ("user_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "tournaments" ADD FOREIGN KEY ("created_by") REFERENCES "users" ("user_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "tournament_participants" ADD FOREIGN KEY ("tournament_id") REFERENCES "tournaments" ("tournament_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "tournament_participants" ADD FOREIGN KEY ("team_id") REFERENCES "teams" ("team_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "matches" ADD FOREIGN KEY ("tournament_id") REFERENCES "tournaments" ("tournament_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "matches" ADD FOREIGN KEY ("team_a_id") REFERENCES "teams" ("team_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "matches" ADD FOREIGN KEY ("team_b_id") REFERENCES "teams" ("team_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "matches" ADD FOREIGN KEY ("next_match_id") REFERENCES "matches" ("match_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "match_games" ADD FOREIGN KEY ("match_id") REFERENCES "matches" ("match_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "match_games" ADD FOREIGN KEY ("submitted_by") REFERENCES "users" ("user_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "match_games" ADD FOREIGN KEY ("approved_by") REFERENCES "users" ("user_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "tickets" ADD FOREIGN KEY ("author_id") REFERENCES "users" ("user_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "tickets" ADD FOREIGN KEY ("assigned_to") REFERENCES "users" ("user_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "audit_log" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("user_id") DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE "login_attempts" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("user_id") DEFERRABLE INITIALLY IMMEDIATE;