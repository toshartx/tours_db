## Список таблиц для БД

- `users` -- пользователи;
- `user_roles` -- роли пользователей (может быть несколько)
- `teams` -- команды;
- `applications` -- заявки на вступление;
- `tickets` -- жалобы; 
- `team_members` -- участники команды (в том числе и бывшие);
- `tournaments` -- турниры;
- `tournament_participants` -- участники турнира;
- `matches` -- матчи; 
- `match_games` -- раунды внутри матча;
- `roles` -- системные роли (организатор, судья, капитан, игрок)
- `audit_log` -- журнал аудита 
- `login_attempts` -- попытки входа (безопасность)

## Описание каждой сущности

### `roles`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| role_id | SERIAL | PK |
| code | VARCHAR(30) | NOT NULL, UNIQUE |
| name | VARCHAR(100) | NOT NULL |


### `users`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| user_id | BIGSERIAL | PK |
| email | VARCHAR(255) | NOT NULL, UNIQUE |
| username | VARCHAR(30) | NOT NULL, UNIQUE, CHECK (length >= 3) |
| password_hash | VARCHAR(255) | NOT NULL |
| role_id | INT | NOT NULL, FK → roles(role_id) |
| is_active | BOOLEAN | NOT NULL, DEFAULT TRUE |
| email_verified | BOOLEAN | NOT NULL, DEFAULT FALSE |
| last_login_at | TIMESTAMPTZ | NULL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |
| deleted_at | TIMESTAMPTZ | NULL |

### `players`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| player_id | BIGSERIAL | PK |
| user_id | BIGINT | UNIQUE, FK → users(user_id) ON DELETE SET NULL |
| nickname | VARCHAR(50) | NOT NULL, UNIQUE |
| real_name | VARCHAR(100) | NULL |
| country | CHAR(2) | NULL |
| birth_date | DATE | NULL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |

### `teams`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| team_id | BIGSERIAL | PK |
| name | VARCHAR(100) | NOT NULL, UNIQUE |
| tag | VARCHAR(10) | UNIQUE |
| logo_url | TEXT | NULL |
| created_by | BIGINT | FK → users(user_id) ON DELETE SET NULL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |
| disbanded_at | TIMESTAMPTZ | NULL |

### `team_members`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| id | BIGSERIAL | PK |
| team_id | BIGINT | NOT NULL, FK → teams(team_id) ON DELETE CASCADE |
| player_id | BIGINT | NOT NULL, FK → players(player_id) ON DELETE CASCADE |
| role | VARCHAR(20) | NULL, CHECK (IN ('captain','player','coach')) |
| joined_at | DATE | NOT NULL, DEFAULT CURRENT_DATE |
| left_at | DATE | NULL |
| — | — | UNIQUE (team_id, player_id, joined_at) |

### `tournaments`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| tournament_id | BIGSERIAL | PK |
| name | VARCHAR(150) | NOT NULL |
| description | TEXT | NULL |
| format | VARCHAR(30) | NOT NULL, CHECK (IN ('single_elim','double_elim','round_robin')) |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'draft', CHECK (IN ('draft','registration','ongoing','finished','cancelled')) |
| prize_pool | NUMERIC(12,2) | NULL, CHECK (>= 0) |
| max_teams | SMALLINT | NULL, CHECK (>= 2) |
| starts_at | TIMESTAMPTZ | NULL |
| ends_at | TIMESTAMPTZ | NULL |
| created_by | BIGINT | FK → users(user_id) ON DELETE SET NULL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |

### `tournament_participants`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| tournament_id | BIGINT | PK (составной), FK → tournaments(tournament_id) ON DELETE CASCADE |
| team_id | BIGINT | PK (составной), FK → teams(team_id) ON DELETE CASCADE |
| seed | INT | NULL |
| registered_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |

## `matches`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| match_id | BIGSERIAL | PK |
| tournament_id | BIGINT | NOT NULL, FK → tournaments(tournament_id) ON DELETE CASCADE |
| round | VARCHAR(30) | NULL |
| round_number | SMALLINT | NULL |
| match_number | SMALLINT | NULL |
| team_a_id | BIGINT | NULL, FK → teams(team_id) |
| team_b_id | BIGINT | NULL, FK → teams(team_id) |
| best_of | SMALLINT | NOT NULL, DEFAULT 1, CHECK (IN (1,3,5)) |
| score_a | SMALLINT | NOT NULL, DEFAULT 0, CHECK (>= 0) |
| score_b | SMALLINT | NOT NULL, DEFAULT 0, CHECK (>= 0) |
| winner_id | BIGINT | NULL, FK → teams(team_id) |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'scheduled', CHECK (IN ('scheduled','live','finished','cancelled')) |
| scheduled_at | TIMESTAMPTZ | NULL |
| finished_at | TIMESTAMPTZ | NULL |
| next_match_id | BIGINT | NULL, FK → matches(match_id) ON DELETE SET NULL |
| next_slot | CHAR(1) | NULL, CHECK (IN ('A','B')) |
| — | — | CHECK (team_a_id <> team_b_id) |


## `match_games`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| id | BIGSERIAL | PK |
| match_id | BIGINT | NOT NULL, FK → matches(match_id) ON DELETE CASCADE |
| game_number | SMALLINT | NOT NULL, CHECK (>= 1) |
| map_name | VARCHAR(50) | NULL |
| score_a | SMALLINT | NOT NULL, DEFAULT 0, CHECK (>= 0) |
| score_b | SMALLINT | NOT NULL, DEFAULT 0, CHECK (>= 0) |
| winner_id | BIGINT | NULL, FK → teams(team_id) |
| — | — | UNIQUE (match_id, game_number) |

## `audit_log`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| id | BIGSERIAL | PK |
| user_id | BIGINT | FK → users(user_id) ON DELETE SET NULL |
| action | VARCHAR(50) | NOT NULL |
| entity_type | VARCHAR(50) | NULL |
| entity_id | BIGINT | NULL |
| old_values | JSONB | NULL |
| new_values | JSONB | NULL |
| ip_address | INET | NULL |
| user_agent | TEXT | NULL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |

## `user_roles`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| user_id | BIGINT | PK (составной), FK → users(user_id) ON DELETE CASCADE |
| role_id | INT | PK (составной), FK → roles(role_id) ON DELETE CASCADE |
| assigned_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |

### `tickets`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| ticket_id | BIGSERIAL | PK |
| author_id | BIGINT | NOT NULL, FK → users(user_id) ON DELETE SET NULL |
| subject | VARCHAR(200) | NOT NULL |
| body | TEXT | NOT NULL |
| category | VARCHAR(30) | NOT NULL, CHECK (IN ('cheating','conduct','bug','other')) |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'open', CHECK (IN ('open','in_progress','resolved','rejected')) |
| priority | VARCHAR(10) | NOT NULL, DEFAULT 'normal', CHECK (IN ('low','normal','high')) |
| entity_type | VARCHAR(30) | NULL, CHECK (IN ('player','team','match','tournament')) |
| entity_id | BIGINT | NULL |
| assigned_to | BIGINT | FK → users(user_id) ON DELETE SET NULL |
| resolved_at | TIMESTAMPTZ | NULL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |

### `login_attempts`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| id | BIGSERIAL | PK |
| username | VARCHAR(30) | NULL |
| success | BOOLEAN | NOT NULL |
| ip_address | INET | NULL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |

### `applications`
| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| application_id | BIGSERIAL | PK |
| team_id | BIGINT | NOT NULL, FK → teams(team_id) ON DELETE CASCADE |
| player_id | BIGINT | NOT NULL, FK → players(player_id) ON DELETE CASCADE |
| message | TEXT | NULL |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'pending', CHECK (IN ('pending','approved','rejected','cancelled')) |
| reviewed_by | BIGINT | FK → users(user_id) ON DELETE SET NULL |
| reviewed_at | TIMESTAMPTZ | NULL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |
| — | — | Частичный UNIQUE (team_id, player_id) WHERE status = 'pending' |