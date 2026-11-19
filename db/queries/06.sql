-- 04.sql

-- Турниры с призовым фондом выше среднего и с лимитом команд ≤ 8
SELECT tournament_id, name, format, prize_pool, max_teams
FROM tournaments
WHERE prize_pool > (SELECT AVG(prize_pool) FROM tournaments WHERE prize_pool IS NOT NULL)
  AND max_teams <= 8
  AND ends_at IS NOT NULL
ORDER BY prize_pool DESC;

-- Игроки, чей ник встречается в заявках со статусом rejected (IN-подзапрос)
SELECT player_id, nickname, country
FROM players
WHERE player_id IN (
    SELECT player_id FROM applications WHERE status = 'rejected'
)
ORDER BY nickname;

-- Для каждой команды: сколько у неё заявок в статусе pending
SELECT
    t.team_id,
    t.name,
    (SELECT COUNT(*) FROM applications a
     WHERE a.team_id = t.team_id AND a.status = 'pending') AS pending_apps
FROM teams t
WHERE t.disbanded_at IS NULL
ORDER BY pending_apps DESC, t.name;

-- Матчи с расшифровкой стадии и результата
SELECT
    m.match_id,
    t.name AS tournament,
    m.round_number,
    m.match_number,
    ta.tag AS team_a,
    tb.tag AS team_b,
    m.score_a || ':' || m.score_b AS score,
    CASE
        WHEN m.status <> 'finished' THEN 'не завершён'
        WHEN m.score_a > m.score_b THEN ta.tag || ' победила'
        WHEN m.score_b > m.score_a THEN tb.tag || ' победила'
        ELSE 'ничья'
    END AS outcome
FROM matches m
JOIN tournaments t ON t.tournament_id = m.tournament_id
JOIN teams ta      ON ta.team_id      = m.team_a_id
JOIN teams tb      ON tb.team_id      = m.team_b_id
WHERE m.best_of >= 3
ORDER BY m.tournament_id, m.round_number DESC, m.match_number;

-- демонстрация видов join
-- Все турниры и число зарегистрированных в них команд (включая турниры без участников)
SELECT t.tournament_id, t.name, COUNT(tp.team_id) AS registered_teams
FROM tournaments t
LEFT JOIN tournament_participants tp ON tp.tournament_id = t.tournament_id
GROUP BY t.tournament_id, t.name
ORDER BY registered_teams DESC, t.name;

-- Все роли и пользователи, которым они назначены (включая роли без носителей)
SELECT r.code AS role_code, u.username
FROM user_roles ur
RIGHT JOIN roles r ON r.role_id = ur.role_id
LEFT JOIN users u  ON u.user_id = ur.user_id
ORDER BY r.code, u.username NULLS LAST;

-- Сопоставление игроков и их учётных записей (на случай рассинхрона)
SELECT p.nickname, u.username, u.email
FROM players p
FULL OUTER JOIN users u ON u.user_id = p.user_id
WHERE p.user_id IS NULL OR u.user_id IS NULL
   OR p.nickname IS NOT NULL
ORDER BY p.nickname NULLS LAST;

-- Матрица «судья × категория тикета»: сколько тикетов каждой категории у каждого судьи (включая нули)
SELECT u.username AS judge, c.category, COUNT(tk.ticket_id) AS cnt
FROM users u
JOIN user_roles ur ON ur.user_id = u.user_id
JOIN roles r       ON r.role_id  = ur.role_id AND r.code = 'judge'
CROSS JOIN (VALUES ('cheating'), ('conduct'), ('bug'), ('other')) AS c(category)
LEFT JOIN tickets tk ON tk.assigned_to = u.user_id AND tk.category = c.category
GROUP BY u.username, c.category
ORDER BY u.username, c.category;

-- 3
-- По каждой стране: сколько игроков, из них забанено, средний возраст
SELECT
    country,
    COUNT(*) AS players_cnt,
    COUNT(*) FILTER (WHERE is_banned) AS banned_cnt,
    ROUND(AVG(date_part('year', age(birth_date)))) AS avg_age
FROM players
WHERE country IS NOT NULL
GROUP BY country
ORDER BY players_cnt DESC, country;

-- Команды, у которых суммарный счёт в завершённых матчах больше 10
SELECT t.name, SUM(CASE WHEN m.team_a_id = t.team_id THEN m.score_a ELSE m.score_b END) AS total_score
FROM teams t
JOIN matches m ON (m.team_a_id = t.team_id OR m.team_b_id = t.team_id)
WHERE m.status = 'finished'
GROUP BY t.name
HAVING SUM(CASE WHEN m.team_a_id = t.team_id THEN m.score_a ELSE m.score_b END) > 10
ORDER BY total_score DESC;

-- Внутри каждого турнира: номер матча по времени и разница очков с предыдущим матчем той же команды A
SELECT
    m.tournament_id,
    m.match_id,
    m.scheduled_at,
    ROW_NUMBER() OVER (PARTITION BY m.tournament_id ORDER BY m.scheduled_at) AS rn_in_tournament,
    m.score_a,
    LAG(m.score_a) OVER (PARTITION BY m.team_a_id ORDER BY m.scheduled_at) AS prev_score_a,
    m.score_a - COALESCE(LAG(m.score_a) OVER (PARTITION BY m.team_a_id ORDER BY m.scheduled_at), m.score_a) AS delta
FROM matches m
WHERE m.scheduled_at IS NOT NULL
ORDER BY m.tournament_id, rn_in_tournament;

-- Единый список «сущностей под модерацией»: тикеты по игрокам и тикеты по командам, с пометкой типа
SELECT 'player' AS entity_kind, tk.ticket_id, tk.subject, p.nickname AS target_name
FROM tickets tk
JOIN players p ON p.player_id = tk.entity_id
WHERE tk.entity_type = 'player'
UNION
SELECT 'team', tk.ticket_id, tk.subject, t.name
FROM tickets tk
JOIN teams t ON t.team_id = tk.entity_id
WHERE tk.entity_type = 'team'
ORDER BY ticket_id;

-- 4
-- Команды, которые участвовали хотя бы в одном турнире, но не имеют ни одного завершённого матча
SELECT t.team_id, t.name
FROM teams t
WHERE EXISTS (
    SELECT 1 FROM tournament_participants tp WHERE tp.team_id = t.team_id
)
AND NOT EXISTS (
    SELECT 1 FROM matches m
    WHERE (m.team_a_id = t.team_id OR m.team_b_id = t.team_id)
      AND m.status = 'finished'
);

-- Пользователи, которые заходили успешно, но ни разу не были назначены на тикет
SELECT u.user_id, u.username
FROM users u
WHERE EXISTS (
    SELECT 1 FROM login_attempts la WHERE la.user_id = u.user_id AND la.success
)
AND NOT EXISTS (
    SELECT 1 FROM tickets tk WHERE tk.assigned_to = u.user_id
);

-- «Просроченные» тикеты: открыты > 7 дней или in_progress > 3 дней
SELECT
    ticket_id,
    subject,
    status,
    created_at,
    CASE
        WHEN status = 'open'        AND now() - created_at > interval '7 days'  THEN 'просрочен (open)'
        WHEN status = 'in_progress' AND now() - created_at > interval '3 days'  THEN 'просрочен (in_progress)'
        WHEN status IN ('resolved','rejected')                                   THEN 'закрыт'
        ELSE 'в норме'
    END AS sla_state
FROM tickets
ORDER BY created_at;

-- Начислить роль player всем, у кого есть профиль игрока, но нет роли
INSERT INTO user_roles (user_id, role_id, assigned_by)
SELECT
    p.user_id,
    r.role_id,
    1
FROM players p
CROSS JOIN roles r
WHERE r.code = 'player'
  AND p.user_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.user_id = p.user_id
        AND ur.role_id = r.role_id
  );

SELECT ur.user_id, u.username, r.code, ur.assigned_at
FROM user_roles ur
JOIN users u ON u.user_id = ur.user_id
JOIN roles r ON r.role_id = ur.role_id
WHERE r.code = 'player'
ORDER BY ur.user_id;

-- Анализ плана агрегатного запроса по тикетам
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT category, status, COUNT(*)
FROM tickets
GROUP BY category, status;