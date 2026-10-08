# Нормализованная модель БД

## Список таблиц

- `roles` — системные роли (организатор, судья, капитан, игрок);
- `users` — пользователи;
- `user_roles` — роли пользователей (может быть несколько);
- `players` — игровые профили;
- `teams` — команды;
- `team_members` — участники команды (в том числе бывшие);
- `applications` — заявки на вступление;
- `tournaments` — турниры;
- `tournament_participants` — участники турнира;
- `matches` — матчи;
- `match_games` — раунды внутри матча;
- `tickets` — жалобы;
- `audit_log` — журнал аудита;
- `login_attempts` — попытки входа (безопасность).

---

## Описание каждой сущности

### `roles`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| role_id | SERIAL | PK |
| code | VARCHAR(30) | NOT NULL, UNIQUE |
| name | VARCHAR(100) | NOT NULL |

---

### `users`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| user_id | BIGSERIAL | PK |
| email | VARCHAR(255) | NOT NULL, UNIQUE |
| username | VARCHAR(30) | NOT NULL, UNIQUE, CHECK (length >= 3) |
| password_hash | VARCHAR(255) | NOT NULL |
| is_active | BOOLEAN | NOT NULL, DEFAULT TRUE |
| email_verified | BOOLEAN | NOT NULL, DEFAULT FALSE |
| last_login_at | TIMESTAMPTZ | NULL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |
| deleted_at | TIMESTAMPTZ | NULL |

---

### `user_roles`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| user_id | BIGINT | PK (составной), FK → users(user_id) ON DELETE CASCADE |
| role_id | INT | PK (составной), FK → roles(role_id) ON DELETE CASCADE |
| assigned_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |
| assigned_by | BIGINT | FK → users(user_id) ON DELETE SET NULL |

---

### `players`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| player_id | BIGSERIAL | PK |
| user_id | BIGINT | UNIQUE, FK → users(user_id) ON DELETE SET NULL |
| nickname | VARCHAR(50) | NOT NULL, UNIQUE |
| real_name | VARCHAR(100) | NULL |
| country | CHAR(2) | NULL |
| birth_date | DATE | NULL |
| is_banned | BOOLEAN | NOT NULL, DEFAULT FALSE |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |

---

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

---

### `team_members`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| team_id | BIGINT | PK (составной), FK → teams(team_id) ON DELETE CASCADE |
| player_id | BIGINT | PK (составной), FK → players(player_id) ON DELETE CASCADE |
| joined_at | DATE | PK (составной), NOT NULL, DEFAULT CURRENT_DATE |
| role | VARCHAR(20) | NULL, CHECK (IN ('captain','player','coach')) |
| left_at | DATE | NULL, CHECK (left_at IS NULL OR left_at >= joined_at) |

---

### `applications`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| application_id | BIGSERIAL | PK |
| team_id | BIGINT | NOT NULL, FK → teams(team_id) ON DELETE CASCADE |
| player_id | BIGINT | NOT NULL, FK → players(player_id) ON DELETE CASCADE |
| message | TEXT | NULL |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'pending', CHECK (IN ('pending','approved','rejected','cancelled')) |
| reviewed_by | BIGINT | FK → users(user_id) ON DELETE SET NULL |
| reviewed_at | TIMESTAMPTZ | NULL, CHECK согласован с reviewed_by |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |

---

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

---

### `tournament_participants`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| tournament_id | BIGINT | PK (составной), FK → tournaments(tournament_id) ON DELETE CASCADE |
| team_id | BIGINT | PK (составной), FK → teams(team_id) ON DELETE CASCADE |
| seed | INT | NULL |
| registered_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |

---

### `matches`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| match_id | BIGSERIAL | PK |
| tournament_id | BIGINT | NOT NULL, FK → tournaments(tournament_id) ON DELETE CASCADE |
| round_number | SMALLINT | NULL |
| match_number | SMALLINT | NULL |
| team_a_id | BIGINT | NULL, FK → teams(team_id) ON DELETE SET NULL |
| team_b_id | BIGINT | NULL, FK → teams(team_id) ON DELETE SET NULL |
| best_of | SMALLINT | NOT NULL, DEFAULT 1, CHECK (IN (1,3,5)) |
| score_a | SMALLINT | NOT NULL, DEFAULT 0, CHECK (>= 0) |
| score_b | SMALLINT | NOT NULL, DEFAULT 0, CHECK (>= 0) |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'scheduled', CHECK (IN ('scheduled','live','pending_review','finished','cancelled')) |
| scheduled_at | TIMESTAMPTZ | NULL |
| finished_at | TIMESTAMPTZ | NULL |
| next_match_id | BIGINT | NULL, FK → matches(match_id) ON DELETE SET NULL |
| next_slot | CHAR(1) | NULL, CHECK (IN ('A','B')) |
| — | — | UNIQUE (tournament_id, round_number, match_number) |
| — | — | CHECK (team_a_id IS NULL OR team_b_id IS NULL OR team_a_id <> team_b_id) |

**Удалено:** `round`, `winner_id`.  
**`winner_id` вычисляется** из `score_a`, `score_b`, `team_a_id`, `team_b_id`.

---

### `match_games`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| match_id | BIGINT | PK (составной), FK → matches(match_id) ON DELETE CASCADE |
| game_number | SMALLINT | PK (составной), NOT NULL, CHECK (>= 1) |
| map_name | VARCHAR(50) | NULL |
| score_a | SMALLINT | NOT NULL, DEFAULT 0, CHECK (>= 0) |
| score_b | SMALLINT | NOT NULL, DEFAULT 0, CHECK (>= 0) |
| submitted_by | BIGINT | FK → users(user_id) ON DELETE SET NULL |
| approved_by | BIGINT | FK → users(user_id) ON DELETE SET NULL |
| approved_at | TIMESTAMPTZ | NULL, CHECK согласован с approved_by |

**Удалено:** `id` (суррогатный PK), `winner_id`.  
**`winner_id` вычисляется** из `score_a`, `score_b` и команд матча.

---

### `tickets`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| ticket_id | BIGSERIAL | PK |
| author_id | BIGINT | FK → users(user_id) ON DELETE SET NULL |
| subject | VARCHAR(200) | NOT NULL |
| body | TEXT | NOT NULL |
| category | VARCHAR(30) | NOT NULL, CHECK (IN ('cheating','conduct','bug','other')) |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'open', CHECK (IN ('open','in_progress','resolved','rejected')) |
| priority | VARCHAR(10) | NOT NULL, DEFAULT 'normal', CHECK (IN ('low','normal','high')) |
| entity_type | VARCHAR(30) | NULL, CHECK (IN ('player','team','match','tournament')) |
| entity_id | BIGINT | NULL, CHECK согласован с entity_type |
| assigned_to | BIGINT | FK → users(user_id) ON DELETE SET NULL |
| resolved_at | TIMESTAMPTZ | NULL, CHECK согласован с status |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |

---

### `audit_log`

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

---

### `login_attempts`

| название атрибута | тип данных | ограничения |
| :--- | :--- | :--- |
| id | BIGSERIAL | PK |
| user_id | BIGINT | FK → users(user_id) ON DELETE SET NULL |
| username | VARCHAR(30) | NOT NULL |
| success | BOOLEAN | NOT NULL |
| failure_reason | VARCHAR(30) | NULL, CHECK (IN ('user_not_found','wrong_password','account_disabled','rate_limited')) |
| ip_address | INET | NULL |
| user_agent | TEXT | NULL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() |

---

## Изменения относительно исходной модели

| Таблица | Что изменилось | Причина |
| :--- | :--- | :--- |
| `user_roles` | добавлено `assigned_by` | аудит назначения роли |
| `team_members` | `id` заменён на составной PK `(team_id, player_id, joined_at)` | естественный ключ |
| `matches` | удалён `round` | зависел от `round_number` |
| `matches` | удалён `winner_id` | вычислим из счёта и команд |
| `matches` | добавлен CHECK на `finished_at` / `status` | условная зависимость |
| `matches` | добавлено `UNIQUE (tournament_id, round_number, match_number)` | естественный ключ |
| `match_games` | `id` заменён на составной PK `(match_id, game_number)` | естественный ключ |
| `match_games` | удалён `winner_id` | вычислим из счёта |
| `match_games` | добавлены `submitted_by`, `approved_by`, `approved_at` | судейство матча |
| `tickets` | добавлены `entity_type`, `entity_id` | полиморфная связь с сущностями |
| `tickets` | добавлено CHECK на `resolved_at` / `status` | условная зависимость |
| `login_attempts` | `username` стал `NOT NULL` | обязателен для контекста |
| `login_attempts` | добавлен `failure_reason` | диагностика |
| `login_attempts` | добавлен `user_agent` | безопасность |
| `players` | добавлен `is_banned` | блокировка по решению судьи |