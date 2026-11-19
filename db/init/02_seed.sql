INSERT INTO roles (code, "name") VALUES
('player',    'Игрок'),
('captain',   'Капитан'),
('judge',     'Судья'),
('organizer', 'Организатор'),
('admin',     'Администратор');

INSERT INTO users (email, username, password_hash) VALUES
('admin@esports.by',     'admin',     '$argon2id$v=19$m=65536,t=3,p=4$FAKEHASH_ADMIN'),
('ivan@example.com',     'ivan_petrov','$argon2id$v=19$m=65536,t=3,p=4$FAKEHASH_IVAN'),
('alex@example.com',     'alex_sidor','$argon2id$v=19$m=65536,t=3,p=4$FAKEHASH_ALEX'),
('dmitry@example.com',   'dmitry_k',  '$argon2id$v=19$m=65536,t=3,p=4$FAKEHASH_DMITRY'),
('sergey@example.com',   'sergey_m',  '$argon2id$v=19$m=65536,t=3,p=4$FAKEHASH_SERGEY'),
('olga@example.com',     'olga_judge','$argon2id$v=19$m=65536,t=3,p=4$FAKEHASH_OLGA'),
('pavel@example.com',    'pavel_org', '$argon2id$v=19$m=65536,t=3,p=4$FAKEHASH_PAVEL'),
('maria@example.com',    'maria_k',   '$argon2id$v=19$m=65536,t=3,p=4$FAKEHASH_MARIA'),
('nikita@example.com',   'nikita_v',  '$argon2id$v=19$m=65536,t=3,p=4$FAKEHASH_NIKITA'),
('artem@example.com',    'artem_l',   '$argon2id$v=19$m=65536,t=3,p=4$FAKEHASH_ARTEM');

INSERT INTO user_roles (user_id, role_id, assigned_by) VALUES
(1, 5, 1),   
(2, 1, 1),   
(2, 2, 1),   
(3, 1, 1),  
(4, 1, 1),   
(5, 1, 1),   
(6, 3, 1),  
(7, 4, 1),   
(8, 1, 1),   
(9, 1, 1),   
(10, 1, 1);  

INSERT INTO players (user_id, nickname, real_name, country, birth_date) VALUES
(2,  'ivanTheGreat', 'Иван Петров',    'BY', '2000-03-15'),
(3,  'alexSniper',   'Алексей Сидоров','BY', '1999-07-22'),
(4,  'dmitryAWP',    'Дмитрий Козлов', 'RU', '2001-11-08'),
(5,  'sergeyRifle',  'Сергей Морозов', 'BY', '2002-01-30'),
(8,  'mariaQueen',   'Мария Кузнецова','BY', '2003-05-12'),
(9,  'nikitaFlash',  'Никита Волков',  'RU', '2000-09-19'),
(10, 'artemLurker',  'Артём Лебедев',  'BY', '2001-12-03');

INSERT INTO teams (name, tag, created_by) VALUES
('Minsk Wolves',    'MW',   2),
('Brest Bears',     'BB',   3),
('Grodno Falcons',  'GF',   4),
('Vitebsk Vipers',  'VV',   8);

INSERT INTO team_members (team_id, player_id, joined_at, role, left_at) VALUES
(1, 1, '2024-01-10', 'captain', NULL),
(1, 2, '2024-01-10', 'player',  NULL),
(1, 3, '2024-01-10', 'player',  NULL),
(1, 4, '2024-01-10', 'player',  NULL),
(1, 5, '2024-01-10', 'player',  NULL),

(2, 2, '2024-02-01', 'player',  '2024-06-01'),  
(2, 6, '2024-02-01', 'captain', NULL),
(2, 7, '2024-02-01', 'player',  NULL),

(3, 3, '2024-03-01', 'captain', NULL),
(3, 4, '2024-03-01', 'player',  NULL),

(4, 5, '2024-04-01', 'captain', NULL),
(4, 6, '2024-04-01', 'player',  NULL);

INSERT INTO applications (team_id, player_id, message, status, reviewed_by, reviewed_at) VALUES
(3, 5, 'Хочу играть в Falcons', 'approved', 3, '2024-04-15 10:00:00+03'),
(4, 7, 'Ищу команду',            'pending',  NULL, NULL),
(2, 1, 'Готов вернуться',        'rejected', 6, '2024-07-01 12:00:00+03');

INSERT INTO tournaments (name, description, format, status, prize_pool, max_teams, starts_at, ends_at, created_by) VALUES
('Belarus Cup 2024',      'Главный турнир года',       'single_elim', 'finished',     5000.00, 8,  '2024-08-01 10:00:00+03', '2024-08-15 22:00:00+03', 7),
('Winter League 2025',    'Зимняя лига',               'double_elim', 'ongoing',     10000.00, 16, '2025-01-15 10:00:00+03', '2025-03-01 22:00:00+03', 7),
('Spring Showdown 2025',  'Весенний турнир',           'round_robin', 'registration', 3000.00, 8,  '2025-04-01 10:00:00+03', '2025-04-30 22:00:00+03', 7),
('Summer Cup 2025',       'Летний кубок',              'single_elim', 'draft',          0.00, 8,  NULL, NULL, 7);

INSERT INTO tournament_participants (tournament_id, team_id, seed) VALUES
-- Belarus Cup 2024
(1, 1, 1),
(1, 2, 2),
(1, 3, 3),
(1, 4, 4),

-- Winter League 2025
(2, 1, 1),
(2, 2, 2),
(2, 3, 3),

-- Spring Showdown 2025
(3, 1, 1),
(3, 3, 2);

INSERT INTO matches (tournament_id, round_number, match_number, team_a_id, team_b_id, best_of, score_a, score_b, status, scheduled_at, finished_at, next_match_id, next_slot) VALUES
-- Belarus Cup 2024 (single_elim)
-- Полуфиналы
(1, 2, 1, 1, 4, 3, 2, 0, 'finished', '2024-08-10 18:00:00+03', '2024-08-10 19:30:00+03', 3, 'A'),
(1, 2, 2, 2, 3, 3, 2, 1, 'finished', '2024-08-10 20:00:00+03', '2024-08-10 21:45:00+03', 3, 'B'),
-- Финал
(1, 1, 1, 1, 2, 5, 3, 2, 'finished', '2024-08-15 18:00:00+03', '2024-08-15 20:15:00+03', NULL, NULL),

-- Winter League 2025
(2, 1, 1, 1, 3, 3, 2, 1, 'finished', '2025-01-20 18:00:00+03', '2025-01-20 19:45:00+03', NULL, NULL),
(2, 1, 2, 2, 3, 3, 0, 0, 'live',     '2025-02-15 18:00:00+03', NULL, NULL, NULL),

-- Spring Showdown 2025
(3, 1, 1, 1, 3, 3, 0, 0, 'scheduled', '2025-04-15 18:00:00+03', NULL, NULL, NULL);


INSERT INTO match_games (match_id, game_number, map_name, score_a, score_b, submitted_by, approved_by, approved_at) VALUES
-- Match 1: Minsk Wolves vs Vitebsk Vipers (BO3, 2:0)
(1, 1, 'Mirage',  16, 12, 2, 6, '2024-08-10 19:00:00+03'),
(1, 2, 'Inferno', 16, 14, 2, 6, '2024-08-10 19:30:00+03'),

-- Match 2: Brest Bears vs Grodno Falcons (BO3, 2:1)
(2, 1, 'Dust2',   16, 10, 3, 6, '2024-08-10 21:00:00+03'),
(2, 2, 'Nuke',    12, 16, 3, 6, '2024-08-10 21:20:00+03'),
(2, 3, 'Inferno', 16, 13, 3, 6, '2024-08-10 21:45:00+03'),

-- Match 3: Финал Minsk Wolves vs Brest Bears (BO5, 3:2)
(3, 1, 'Mirage',  16, 14, 2, 6, '2024-08-15 18:30:00+03'),
(3, 2, 'Inferno', 10, 16, 2, 6, '2024-08-15 19:00:00+03'),
(3, 3, 'Dust2',   16, 12, 2, 6, '2024-08-15 19:30:00+03'),
(3, 4, 'Nuke',    14, 16, 2, 6, '2024-08-15 20:00:00+03'),
(3, 5, 'Ancient', 16, 11, 2, 6, '2024-08-15 20:15:00+03'),

-- Winter League, match 4 (BO3, 2:1)
(4, 1, 'Mirage',  16, 13, 2, 6, '2025-01-20 19:00:00+03'),
(4, 2, 'Vertigo', 14, 16, 2, 6, '2025-01-20 19:30:00+03'),
(4, 3, 'Inferno', 16, 9,  2, 6, '2025-01-20 19:45:00+03'),

-- Winter League, match 5 (BO3, live — 1 карта сыграна)
(5, 1, 'Dust2',   16, 10, 6, NULL, NULL);


INSERT INTO tickets (author_id, subject, body, category, status, priority, entity_type, entity_id, assigned_to, resolved_at) VALUES
(2, 'Подозрение на читы',       'Игрок dmitryAWP использует aimbot',          'cheating', 'resolved',    'high',   'player',     3, 6, '2024-09-10 14:00:00+03'),
(3, 'Оскорбления в чате',       'Капитан Minsk Wolves ведёт себя некорректно','conduct',  'in_progress', 'normal', 'team',       1, 6, NULL),
(8, 'Баг в отображении счёта',  'Счёт не обновляется после матча',            'bug',      'open',        'low',    'match',      3, NULL, NULL),
(4, 'Нечестная игра',           'Подозрение на использование макросов',       'cheating', 'resolved',    'high',   'player',     7, 6, '2025-01-25 16:00:00+03'),
(5, 'Ошибка в сетке турнира',   'Неправильный порядок раундов',               'bug',      'open',        'normal', 'tournament', 2, NULL, NULL);


INSERT INTO audit_log (user_id, action, entity_type, entity_id, old_values, new_values, ip_address, user_agent) VALUES
(1, 'LOGIN',         'user',    1,  NULL, NULL, '192.168.1.10', 'Mozilla/5.0'),
(2, 'CREATE',        'team',    1,  NULL, '{"name": "Minsk Wolves", "tag": "MW"}', '192.168.1.20', 'Mozilla/5.0'),
(6, 'RESOLVE_TICKET','ticket',  1,  '{"status": "in_progress"}', '{"status": "resolved"}', '192.168.1.30', 'Mozilla/5.0'),
(6, 'BAN_PLAYER',    'player',  3,  '{"is_banned": false}', '{"is_banned": true}', '192.168.1.30', 'Mozilla/5.0'),
(7, 'CREATE',        'tournament', 1, NULL, '{"name": "Belarus Cup 2024"}', '192.168.1.40', 'Mozilla/5.0'),
(1, 'ASSIGN_ROLE',   'user',    6,  NULL, '{"role": "judge"}', '192.168.1.10', 'Mozilla/5.0'),
(2, 'UPDATE',        'match',   1,  '{"status": "live"}', '{"status": "finished"}', '192.168.1.20', 'Mozilla/5.0'),
(3, 'LOGOUT',        'user',    3,  NULL, NULL, '192.168.1.21', 'Mozilla/5.0');

INSERT INTO login_attempts (user_id, username, success, failure_reason, ip_address, user_agent) VALUES
(1,  'admin',       TRUE,  NULL,              '192.168.1.10', 'Mozilla/5.0'),
(NULL,'hacker123',  FALSE, 'user_not_found',  '45.67.89.10', 'curl/8.0'),
(2,  'ivan_petrov', FALSE, 'wrong_password',  '192.168.1.20', 'Mozilla/5.0'),
(2,  'ivan_petrov', TRUE,  NULL,              '192.168.1.20', 'Mozilla/5.0'),
(3,  'alex_sidor',  TRUE,  NULL,              '192.168.1.21', 'Mozilla/5.0'),
(NULL,'admin',      FALSE, 'wrong_password',  '45.67.89.10', 'curl/8.0'),
(NULL,'admin',      FALSE, 'wrong_password',  '45.67.89.10', 'curl/8.0'),
(NULL,'admin',      FALSE, 'rate_limited',    '45.67.89.10', 'curl/8.0'),
(6,  'olga_judge',  TRUE,  NULL,              '192.168.1.30', 'Mozilla/5.0'),
(7,  'pavel_org',   TRUE,  NULL,              '192.168.1.40', 'Mozilla/5.0');

UPDATE players SET is_banned = TRUE WHERE player_id IN (3, 7);