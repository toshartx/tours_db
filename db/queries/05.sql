-- 03.sql

-- 'Забаненные игроки' (исправлено: entity_type в ON, LEFT JOIN, группировка)
SELECT
    p.nickname,
    STRING_AGG(DISTINCT tk.category, ', ') AS categories
FROM players p
LEFT JOIN tickets tk ON tk.entity_id = p.player_id AND tk.entity_type = 'player'
WHERE p.is_banned = true
GROUP BY p.player_id, p.nickname;

-- 'Выборка активных команд'
SELECT name, tag 
FROM teams
WHERE disbanded_at IS NULL;

-- 'Выборка команд по тегу' (исправлено: убран $)
SELECT name, tag
FROM teams
WHERE tag ILIKE 'M%';

-- 'Активный состав'
SELECT p.nickname 
FROM team_members tm
JOIN players p ON p.player_id = tm.player_id
WHERE tm.team_id = 1 AND tm.left_at IS NULL;

-- 'История команд игрока'
SELECT t.name, tm.joined_at, tm.left_at 
FROM team_members tm
JOIN teams t ON t.team_id = tm.team_id
WHERE tm.player_id = 1
ORDER BY tm.joined_at DESC;

-- 'Заявки на вступление в команду' (исправлено: без SELECT *)
SELECT application_id, team_id, player_id, message, created_at
FROM applications
WHERE status = 'pending';

-- 'Текущие турниры'
SELECT name, format, prize_pool  
FROM tournaments
WHERE status = 'ongoing';

-- 'Отсортированные по призовому фонду турниры'
SELECT name, format, prize_pool
FROM tournaments
ORDER BY prize_pool DESC NULLS LAST;

-- 'Участники турнира и их посев'
SELECT tp.seed, tm.name
FROM tournament_participants tp
JOIN teams tm ON tm.team_id = tp.team_id
WHERE tp.tournament_id = 1
ORDER BY tp.seed NULLS LAST;

-- 'Выборка матчей по раунду (стадии) турнира' (исправлено: LEFT JOIN + COALESCE)
SELECT
    m.match_id,
    COALESCE(ta.name, 'TBD') AS team_a_name,
    COALESCE(tb.name, 'TBD') AS team_b_name,
    m.status
FROM matches m
LEFT JOIN teams ta ON ta.team_id = m.team_a_id
LEFT JOIN teams tb ON tb.team_id = m.team_b_id
WHERE m.tournament_id = 1 AND m.round_number = 1
ORDER BY m.match_number;

-- 'Выборка матчей в статусе live'
SELECT 
    m.match_id,
    ta.name AS team_a_name,
    tb.name AS team_b_name
FROM matches m
JOIN teams ta ON ta.team_id = m.team_a_id
JOIN teams tb ON tb.team_id = m.team_b_id
WHERE m.status = 'live';

-- 'Выборка матчей конкретной команды (история)' (исправлено: NULLS LAST + CASE)
SELECT 
    t.name AS tournament_name,
    CASE WHEN m.team_a_id = 1 THEN ta.name ELSE tb.name END AS own_team,
    CASE WHEN m.team_a_id = 1 THEN tb.name ELSE ta.name END AS opponent,
    m.score_a,
    m.score_b,
    CASE
        WHEN m.status <> 'finished' THEN '—'
        WHEN (m.team_a_id = 1 AND m.score_a > m.score_b)
          OR (m.team_b_id = 1 AND m.score_b > m.score_a) THEN 'WIN'
        ELSE 'LOSS'
    END AS result
FROM matches m
JOIN teams ta ON ta.team_id = m.team_a_id
JOIN teams tb ON tb.team_id = m.team_b_id
JOIN tournaments t ON t.tournament_id = m.tournament_id
WHERE (ta.team_id = 1 OR tb.team_id = 1)
ORDER BY m.finished_at DESC NULLS LAST;

-- 'Подробная информация о матче'
SELECT game_number, map_name, score_a, score_b
FROM match_games
WHERE match_id = 1
ORDER BY game_number;

-- 'Все открытые тикеты'
SELECT ticket_id, subject, category, priority, created_at
FROM tickets
WHERE status IN ('open', 'in_progress');