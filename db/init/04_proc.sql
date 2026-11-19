-- 06_procedures.sql

-- ============================================================
-- 1. ФУНКЦИИ И ПРОЦЕДУРЫ ДЛЯ ПОЛЬЗОВАТЕЛЕЙ И РОЛЕЙ (ТЗ п.1, п.2, п.3)
-- ============================================================

CREATE OR REPLACE PROCEDURE sp_register_user(
    p_email    varchar,
    p_username varchar,
    p_password_hash varchar,
    p_as_player boolean DEFAULT TRUE
)
LANGUAGE plpgsql AS $$
DECLARE
    v_user_id bigint;
    v_role_id int;
BEGIN
    INSERT INTO users (email, username, password_hash)
    VALUES (p_email, p_username, p_password_hash)
    RETURNING user_id INTO v_user_id;

    IF p_as_player THEN
        INSERT INTO players (user_id, nickname) VALUES (v_user_id, p_username);
        SELECT role_id INTO v_role_id FROM roles WHERE code = 'player';
        INSERT INTO user_roles (user_id, role_id) VALUES (v_user_id, v_role_id);
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_assign_role(
    p_user_id bigint, p_role_code varchar, p_by bigint DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_role_id int;
BEGIN
    SELECT role_id INTO v_role_id FROM roles WHERE code = p_role_code;
    IF v_role_id IS NULL THEN RAISE EXCEPTION 'Роль % не найдена', p_role_code; END IF;

    INSERT INTO user_roles (user_id, role_id, assigned_by)
    VALUES (p_user_id, v_role_id, p_by) ON CONFLICT DO NOTHING;

    INSERT INTO audit_log (user_id, action, entity_type, entity_id, new_values)
    VALUES (p_by, 'ASSIGN_ROLE', 'user', p_user_id, jsonb_build_object('role', p_role_code));
END;
$$;

CREATE OR REPLACE PROCEDURE sp_revoke_role(
    p_user_id bigint, p_role_code varchar, p_by bigint DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_role_id int;
BEGIN
    SELECT role_id INTO v_role_id FROM roles WHERE code = p_role_code;
    IF v_role_id IS NULL THEN RAISE EXCEPTION 'Роль % не найдена', p_role_code; END IF;

    DELETE FROM user_roles WHERE user_id = p_user_id AND role_id = v_role_id;

    INSERT INTO audit_log (user_id, action, entity_type, entity_id, new_values)
    VALUES (p_by, 'REVOKE_ROLE', 'user', p_user_id, jsonb_build_object('role', p_role_code));
END;
$$;

-- ============================================================
-- 2. ПРОЦЕДУРЫ ДЛЯ КОМАНД И ЗАЯВОК (ТЗ п.4, п.5, п.8)
-- ============================================================

CREATE OR REPLACE PROCEDURE sp_create_team(
    p_creator_user_id bigint, p_name varchar, p_tag varchar DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_player_id bigint;
    v_team_id   bigint;
BEGIN
    SELECT player_id INTO v_player_id FROM players WHERE user_id = p_creator_user_id;
    IF v_player_id IS NULL THEN RAISE EXCEPTION 'У пользователя % нет профиля игрока', p_creator_user_id; END IF;

    IF EXISTS (SELECT 1 FROM team_members WHERE player_id = v_player_id AND left_at IS NULL) THEN
        RAISE EXCEPTION 'Игрок % уже состоит в активной команде', v_player_id;
    END IF;

    INSERT INTO teams (name, tag, created_by) VALUES (p_name, p_tag, p_creator_user_id) RETURNING team_id INTO v_team_id;
    INSERT INTO team_members (team_id, player_id, joined_at, role) VALUES (v_team_id, v_player_id, CURRENT_DATE, 'captain');
    INSERT INTO user_roles (user_id, role_id, assigned_by) SELECT p_creator_user_id, r.role_id, NULL FROM roles r WHERE r.code = 'captain' ON CONFLICT DO NOTHING;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_submit_application(
    p_team_id bigint, p_player_id bigint, p_message text DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    IF (SELECT disbanded_at FROM teams WHERE team_id = p_team_id) IS NOT NULL THEN RAISE EXCEPTION 'Команда расформирована'; END IF;
    IF (SELECT is_banned FROM players WHERE player_id = p_player_id) THEN RAISE EXCEPTION 'Игрок забанен'; END IF;
    IF EXISTS (SELECT 1 FROM team_members WHERE team_id = p_team_id AND player_id = p_player_id AND left_at IS NULL) THEN RAISE EXCEPTION 'Уже в команде'; END IF;
    IF EXISTS (SELECT 1 FROM applications WHERE team_id = p_team_id AND player_id = p_player_id AND status = 'pending') THEN RAISE EXCEPTION 'Заявка уже отправлена'; END IF;

    INSERT INTO applications (team_id, player_id, message) VALUES (p_team_id, p_player_id, p_message);
END;
$$;

CREATE OR REPLACE PROCEDURE sp_approve_application(
    p_application_id bigint, p_reviewer_id bigint
)
LANGUAGE plpgsql AS $$
DECLARE
    v_app applications%ROWTYPE;
BEGIN
    SELECT * INTO v_app FROM applications WHERE application_id = p_application_id FOR UPDATE;
    IF NOT FOUND OR v_app.status <> 'pending' THEN RAISE EXCEPTION 'Заявка не найдена или уже обработана'; END IF;
    IF (SELECT is_banned FROM players WHERE player_id = v_app.player_id) THEN RAISE EXCEPTION 'Игрок забанен'; END IF;

    UPDATE applications SET status = 'approved', reviewed_by = p_reviewer_id, reviewed_at = now() WHERE application_id = p_application_id;
    INSERT INTO team_members (team_id, player_id, joined_at, role) VALUES (v_app.team_id, v_app.player_id, CURRENT_DATE, 'player');
END;
$$;

CREATE OR REPLACE PROCEDURE sp_reject_application(
    p_application_id bigint, p_reviewer_id bigint
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE applications SET status = 'rejected', reviewed_by = p_reviewer_id, reviewed_at = now() WHERE application_id = p_application_id AND status = 'pending';
    IF NOT FOUND THEN RAISE EXCEPTION 'Заявка не найдена или уже обработана'; END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_leave_team(
    p_team_id bigint, p_player_id bigint
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE team_members SET left_at = CURRENT_DATE WHERE team_id = p_team_id AND player_id = p_player_id AND left_at IS NULL;
    IF NOT FOUND THEN RAISE EXCEPTION 'Игрок не в активном составе'; END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_kick_player(
    p_team_id bigint, p_player_id bigint, p_by_user_id bigint
)
LANGUAGE plpgsql AS $$
DECLARE
    v_is_captain boolean;
BEGIN
    SELECT EXISTS (SELECT 1 FROM team_members tm JOIN players p ON p.player_id = tm.player_id WHERE tm.team_id = p_team_id AND p.user_id = p_by_user_id AND tm.role = 'captain' AND tm.left_at IS NULL) INTO v_is_captain;
    IF NOT v_is_captain THEN RAISE EXCEPTION 'Пользователь не капитан'; END IF;
    IF p_player_id = (SELECT player_id FROM players WHERE user_id = p_by_user_id) THEN RAISE EXCEPTION 'Нельзя кикнуть себя'; END IF;

    UPDATE team_members SET left_at = CURRENT_DATE WHERE team_id = p_team_id AND player_id = p_player_id AND left_at IS NULL;
    IF NOT FOUND THEN RAISE EXCEPTION 'Игрок не в составе'; END IF;
END;
$$;

-- ============================================================
-- 3. ПРОЦЕДУРЫ ДЛЯ ТИКЕТОВ (ТЗ п.11)
-- ============================================================

CREATE OR REPLACE PROCEDURE sp_create_ticket(
    p_author_id bigint, p_subject varchar, p_body text, p_category varchar,
    p_entity_type varchar DEFAULT NULL, p_entity_id bigint DEFAULT NULL, p_priority varchar DEFAULT 'normal'
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO tickets (author_id, subject, body, category, priority, entity_type, entity_id)
    VALUES (p_author_id, p_subject, p_body, p_category, p_priority, p_entity_type, p_entity_id);
END;
$$;

CREATE OR REPLACE PROCEDURE sp_assign_ticket(
    p_ticket_id bigint, p_judge_id bigint
)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_roles ur JOIN roles r ON r.role_id = ur.role_id WHERE ur.user_id = p_judge_id AND r.code = 'judge') THEN RAISE EXCEPTION 'Пользователь не судья'; END IF;
    UPDATE tickets SET assigned_to = p_judge_id WHERE ticket_id = p_ticket_id AND status IN ('open', 'in_progress');
    IF NOT FOUND THEN RAISE EXCEPTION 'Тикет не найден или закрыт'; END IF;
END;
$$;

-- ============================================================
-- 4. ПРОЦЕДУРЫ ДЛЯ ТУРНИРОВ И МАТЧЕЙ (ТЗ п.9, п.10)
-- ============================================================

CREATE OR REPLACE PROCEDURE sp_create_tournament(
    p_name varchar, p_format varchar, p_created_by bigint,
    p_description text DEFAULT NULL, p_prize_pool numeric DEFAULT NULL, p_max_teams smallint DEFAULT NULL,
    p_starts_at timestamptz DEFAULT NULL, p_ends_at timestamptz DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_format NOT IN ('single_elim', 'double_elim', 'round_robin') THEN RAISE EXCEPTION 'Недопустимый формат'; END IF;
    INSERT INTO tournaments (name, description, format, status, prize_pool, max_teams, starts_at, ends_at, created_by)
    VALUES (p_name, p_description, p_format, 'draft', p_prize_pool, p_max_teams, p_starts_at, p_ends_at, p_created_by);
END;
$$;

CREATE OR REPLACE PROCEDURE sp_change_tournament_status(
    p_tournament_id bigint, p_new_status varchar, p_by bigint DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_old varchar(20);
BEGIN
    SELECT status INTO v_old FROM tournaments WHERE tournament_id = p_tournament_id FOR UPDATE;
    IF v_old IS NULL THEN RAISE EXCEPTION 'Турнир не найден'; END IF;
    IF NOT ((v_old = 'draft' AND p_new_status IN ('registration', 'cancelled')) OR (v_old = 'registration' AND p_new_status IN ('ongoing', 'cancelled')) OR (v_old = 'ongoing' AND p_new_status IN ('finished', 'cancelled')) OR (v_old = p_new_status)) THEN
        RAISE EXCEPTION 'Недопустимый переход % → %', v_old, p_new_status;
    END IF;
    UPDATE tournaments SET status = p_new_status WHERE tournament_id = p_tournament_id;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_register_team(
    p_tournament_id bigint, p_team_id bigint, p_seed int DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_status varchar(20); v_max smallint; v_current int;
BEGIN
    SELECT status, max_teams INTO v_status, v_max FROM tournaments WHERE tournament_id = p_tournament_id FOR UPDATE;
    IF v_status IS NULL THEN RAISE EXCEPTION 'Турнир не найден'; END IF;
    IF v_status NOT IN ('registration', 'draft') THEN RAISE EXCEPTION 'Регистрация закрыта (статус %)', v_status; END IF;
    SELECT COUNT(*) INTO v_current FROM tournament_participants WHERE tournament_id = p_tournament_id;
    IF v_max IS NOT NULL AND v_current >= v_max THEN RAISE EXCEPTION 'Турнир заполнен (%/%)', v_current, v_max; END IF;
    INSERT INTO tournament_participants (tournament_id, team_id, seed) VALUES (p_tournament_id, p_team_id, p_seed);
END;
$$;

CREATE OR REPLACE PROCEDURE sp_finish_match(
    p_match_id bigint, p_score_a smallint, p_score_b smallint
)
LANGUAGE plpgsql AS $$
DECLARE
    v_match matches%ROWTYPE; v_winner bigint; v_unfinished int;
BEGIN
    SELECT * INTO v_match FROM matches WHERE match_id = p_match_id FOR UPDATE;
    IF NOT FOUND OR v_match.status = 'finished' THEN RAISE EXCEPTION 'Матч не найден или уже завершён'; END IF;
    IF v_match.status NOT IN ('live', 'pending_review') THEN RAISE EXCEPTION 'Нельзя завершить матч в статусе %', v_match.status; END IF;

    UPDATE matches SET score_a = p_score_a, score_b = p_score_b, status = 'finished', finished_at = now() WHERE match_id = p_match_id;
    v_winner := CASE WHEN p_score_a > p_score_b THEN v_match.team_a_id WHEN p_score_b > p_score_a THEN v_match.team_b_id END;

    IF v_winner IS NOT NULL AND v_match.next_match_id IS NOT NULL THEN
        IF v_match.next_slot = 'A' THEN UPDATE matches SET team_a_id = v_winner WHERE match_id = v_match.next_match_id;
        ELSIF v_match.next_slot = 'B' THEN UPDATE matches SET team_b_id = v_winner WHERE match_id = v_match.next_match_id; END IF;
    END IF;

    SELECT COUNT(*) INTO v_unfinished FROM matches WHERE tournament_id = v_match.tournament_id AND status NOT IN ('finished', 'cancelled');
    IF v_unfinished = 0 THEN UPDATE tournaments SET status = 'finished' WHERE tournament_id = v_match.tournament_id; END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_cancel_match(
    p_match_id bigint, p_reason text, p_by bigint DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE matches SET status = 'cancelled' WHERE match_id = p_match_id AND status NOT IN ('finished', 'cancelled');
    IF NOT FOUND THEN RAISE EXCEPTION 'Матч не найден или уже завершён/отменён'; END IF;
    INSERT INTO audit_log (user_id, action, entity_type, entity_id, new_values) VALUES (p_by, 'CANCEL_MATCH', 'match', p_match_id, jsonb_build_object('reason', p_reason));
END;
$$;

CREATE OR REPLACE PROCEDURE sp_submit_game_score(
    p_match_id bigint, p_game_number smallint, p_map_name varchar, p_score_a smallint, p_score_b smallint, p_submitted_by bigint
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO match_games (match_id, game_number, map_name, score_a, score_b, submitted_by)
    VALUES (p_match_id, p_game_number, p_map_name, p_score_a, p_score_b, p_submitted_by)
    ON CONFLICT (match_id, game_number) DO UPDATE
        SET map_name = EXCLUDED.map_name, score_a = EXCLUDED.score_a, score_b = EXCLUDED.score_b, submitted_by = EXCLUDED.submitted_by
        WHERE match_games.approved_by IS NULL;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_ban_player(
    p_player_id bigint, p_reason text DEFAULT 'manual ban'
)
LANGUAGE plpgsql AS $$
DECLARE
    v_nickname varchar(50); v_tickets int;
BEGIN
    SELECT nickname INTO v_nickname FROM players WHERE player_id = p_player_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Игрок не найден'; END IF;
    UPDATE players SET is_banned = TRUE WHERE player_id = p_player_id;
    WITH closed AS (UPDATE tickets SET status = 'resolved', resolved_at = now() WHERE entity_type = 'player' AND entity_id = p_player_id AND status IN ('open', 'in_progress') RETURNING ticket_id)
    SELECT COUNT(*) INTO v_tickets FROM closed;
    INSERT INTO audit_log (user_id, action, entity_type, entity_id, old_values, new_values, user_agent)
    VALUES (NULL, 'BAN_PLAYER', 'player', p_player_id, jsonb_build_object('is_banned', FALSE), jsonb_build_object('is_banned', TRUE, 'reason', p_reason), 'procedure:sp_ban_player');
END;
$$;

-- ============================================================
-- 5. ГЕНЕРАЦИЯ СЕТОК
-- ============================================================

CREATE OR REPLACE PROCEDURE sp_generate_bracket(p_tournament_id bigint)
LANGUAGE plpgsql AS $$
DECLARE v_format varchar(30);
BEGIN
    SELECT format INTO v_format FROM tournaments WHERE tournament_id = p_tournament_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Турнир не найден'; END IF;
    IF EXISTS (SELECT 1 FROM matches WHERE tournament_id = p_tournament_id) THEN RAISE EXCEPTION 'Сетка уже создана'; END IF;
    CASE v_format
        WHEN 'single_elim' THEN CALL sp_create_single_elim_bracket(p_tournament_id);
        WHEN 'double_elim' THEN CALL sp_create_double_elim_bracket(p_tournament_id);
        WHEN 'round_robin' THEN CALL sp_create_round_robin_schedule(p_tournament_id);
        ELSE RAISE EXCEPTION 'Неизвестный формат: %', v_format;
    END CASE;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_create_single_elim_bracket(p_tournament_id bigint)
LANGUAGE plpgsql AS $$
DECLARE
    v_teams int; v_rounds int; v_round int; v_m int; v_matches int;
BEGIN
    SELECT COUNT(*) INTO v_teams FROM tournament_participants WHERE tournament_id = p_tournament_id;
    IF v_teams < 2 THEN RAISE EXCEPTION 'Нужно минимум 2 команды'; END IF;
    v_rounds := ceil(log(2, v_teams))::int;
    
    FOR v_round IN 1..v_rounds LOOP
        v_m := 2 ^ (v_rounds - v_round);
        FOR v_matches IN 1..v_m LOOP
            INSERT INTO matches (tournament_id, round_number, match_number, best_of, status) VALUES (p_tournament_id, v_round, v_matches, CASE WHEN v_round = 1 THEN 5 ELSE 3 END, 'scheduled');
        END LOOP;
    END LOOP;

    UPDATE matches m1 SET next_match_id = m2.match_id, next_slot = CASE WHEN m1.match_number % 2 = 1 THEN 'A' ELSE 'B' END
    FROM matches m2 WHERE m1.tournament_id = p_tournament_id AND m2.tournament_id = p_tournament_id AND m1.round_number > 1 AND m2.round_number = m1.round_number - 1 AND m2.match_number = (m1.match_number + 1) / 2;

    WITH seeded AS (SELECT tp.team_id, ROW_NUMBER() OVER (ORDER BY tp.seed NULLS LAST, tp.team_id) AS rn FROM tournament_participants tp WHERE tp.tournament_id = p_tournament_id),
    first_round AS (SELECT m.match_id, ROW_NUMBER() OVER (ORDER BY m.match_number) AS mrn FROM matches m WHERE m.tournament_id = p_tournament_id AND m.round_number = v_rounds)
    UPDATE matches m SET team_a_id = s_a.team_id, team_b_id = s_b.team_id FROM first_round frm JOIN seeded s_a ON s_a.rn = (frm.mrn - 1) * 2 + 1 LEFT JOIN seeded s_b ON s_b.rn = (frm.mrn - 1) * 2 + 2 WHERE m.match_id = frm.match_id;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_create_double_elim_bracket(p_tournament_id bigint)
LANGUAGE plpgsql AS $$
DECLARE
    v_teams int; v_ub_rounds int; v_lb_rounds int; v_round int; v_m int; v_cnt int; v_ub_final bigint; v_lb_final bigint; v_gf_id bigint;
BEGIN
    SELECT COUNT(*) INTO v_teams FROM tournament_participants WHERE tournament_id = p_tournament_id;
    IF v_teams < 2 THEN RAISE EXCEPTION 'Нужно минимум 2 команды'; END IF;
    v_ub_rounds := ceil(log(2, v_teams))::int;
    v_lb_rounds := 2 * v_ub_rounds - 2;

    -- UB
    FOR v_round IN 1..v_ub_rounds LOOP
        v_cnt := 2 ^ (v_ub_rounds - v_round);
        FOR v_m IN 1..v_cnt LOOP INSERT INTO matches (tournament_id, round_number, match_number, best_of, status) VALUES (p_tournament_id, v_round, v_m, CASE WHEN v_round = 1 THEN 5 ELSE 3 END, 'scheduled'); END LOOP;
    END LOOP;
    UPDATE matches m1 SET next_match_id = m2.match_id, next_slot = CASE WHEN m1.match_number % 2 = 1 THEN 'A' ELSE 'B' END FROM matches m2 WHERE m1.tournament_id = p_tournament_id AND m2.tournament_id = p_tournament_id AND m1.round_number > 1 AND m1.round_number <= v_ub_rounds AND m2.round_number = m1.round_number - 1 AND m2.match_number = (m1.match_number + 1) / 2;

    -- LB
    FOR v_round IN 1..v_lb_rounds LOOP
        v_cnt := CASE WHEN v_round = 1 THEN 2 ^ (v_ub_rounds - 2) WHEN v_round = v_lb_rounds THEN 1 WHEN v_round % 2 = 1 THEN 2 ^ (v_ub_rounds - 2 - (v_round - 1) / 2) ELSE 2 ^ (v_ub_rounds - 2 - (v_round - 2) / 2) END;
        IF v_cnt < 1 THEN v_cnt := 1; END IF;
        FOR v_m IN 1..v_cnt LOOP INSERT INTO matches (tournament_id, round_number, match_number, best_of, status) VALUES (p_tournament_id, v_ub_rounds + v_round, v_m, 3, 'scheduled'); END LOOP;
    END LOOP;
    UPDATE matches m1 SET next_match_id = m2.match_id, next_slot = CASE WHEN m1.match_number % 2 = 1 THEN 'A' ELSE 'B' END FROM matches m2 WHERE m1.tournament_id = p_tournament_id AND m2.tournament_id = p_tournament_id AND m1.round_number > v_ub_rounds AND m1.round_number < v_ub_rounds + v_lb_rounds AND m2.round_number = m1.round_number + 1 AND m2.match_number = (m1.match_number + 1) / 2;

    -- GF
    INSERT INTO matches (tournament_id, round_number, match_number, best_of, status) VALUES (p_tournament_id, 0, 1, 5, 'scheduled') RETURNING match_id INTO v_gf_id;
    SELECT match_id INTO v_ub_final FROM matches WHERE tournament_id = p_tournament_id AND round_number = 1 AND match_number = 1;
    UPDATE matches SET next_match_id = v_gf_id, next_slot = 'A' WHERE match_id = v_ub_final;
    SELECT match_id INTO v_lb_final FROM matches WHERE tournament_id = p_tournament_id AND round_number = v_ub_rounds + v_lb_rounds AND match_number = 1;
    UPDATE matches SET next_match_id = v_gf_id, next_slot = 'B' WHERE match_id = v_lb_final;

    -- Seed
    WITH seeded AS (SELECT tp.team_id, ROW_NUMBER() OVER (ORDER BY tp.seed NULLS LAST, tp.team_id) AS rn FROM tournament_participants tp WHERE tp.tournament_id = p_tournament_id),
    first_round AS (SELECT m.match_id, ROW_NUMBER() OVER (ORDER BY m.match_number) AS mrn FROM matches m WHERE m.tournament_id = p_tournament_id AND m.round_number = v_ub_rounds)
    UPDATE matches m SET team_a_id = s_a.team_id, team_b_id = s_b.team_id FROM first_round frm JOIN seeded s_a ON s_a.rn = (frm.mrn - 1) * 2 + 1 LEFT JOIN seeded s_b ON s_b.rn = (frm.mrn - 1) * 2 + 2 WHERE m.match_id = frm.match_id;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_finish_match_de(
    p_match_id bigint, p_score_a smallint, p_score_b smallint
)
LANGUAGE plpgsql AS $$
DECLARE
    v_match matches%ROWTYPE; v_winner bigint; v_loser bigint; v_lb_target bigint;
BEGIN
    SELECT * INTO v_match FROM matches WHERE match_id = p_match_id FOR UPDATE;
    IF NOT FOUND OR v_match.status = 'finished' THEN RAISE EXCEPTION 'Матч не найден или уже завершён'; END IF;
    UPDATE matches SET score_a = p_score_a, score_b = p_score_b, status = 'finished', finished_at = now() WHERE match_id = p_match_id;

    v_winner := CASE WHEN p_score_a > p_score_b THEN v_match.team_a_id WHEN p_score_b > p_score_a THEN v_match.team_b_id END;
    v_loser  := CASE WHEN p_score_a < p_score_b THEN v_match.team_a_id WHEN p_score_b < p_score_a THEN v_match.team_b_id END;

    IF v_winner IS NOT NULL AND v_match.next_match_id IS NOT NULL THEN
        IF v_match.next_slot = 'A' THEN UPDATE matches SET team_a_id = v_winner WHERE match_id = v_match.next_match_id;
        ELSIF v_match.next_slot = 'B' THEN UPDATE matches SET team_b_id = v_winner WHERE match_id = v_match.next_match_id; END IF;
    END IF;

    IF v_loser IS NOT NULL THEN
        SELECT match_id INTO v_lb_target FROM matches WHERE tournament_id = v_match.tournament_id AND round_number > (SELECT MAX(round_number) FROM matches WHERE tournament_id = v_match.tournament_id AND round_number <= 2) AND status = 'scheduled' AND (team_a_id IS NULL OR team_b_id IS NULL) ORDER BY round_number, match_number LIMIT 1;
        IF v_lb_target IS NOT NULL THEN
            UPDATE matches SET team_a_id = COALESCE(team_a_id, v_loser), team_b_id = CASE WHEN team_a_id IS NOT NULL AND team_b_id IS NULL THEN v_loser ELSE team_b_id END WHERE match_id = v_lb_target;
        END IF;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_create_round_robin_schedule(p_tournament_id bigint)
LANGUAGE plpgsql AS $$
DECLARE
    v_teams int; v_n int; v_rounds int; v_round int; v_arr bigint[]; v_i int; v_tmp bigint; v_match_no int; v_has_bye boolean;
BEGIN
    SELECT COUNT(*) INTO v_teams FROM tournament_participants WHERE tournament_id = p_tournament_id;
    IF v_teams < 2 THEN RAISE EXCEPTION 'Нужно минимум 2 команды'; END IF;
    v_n := v_teams; v_has_bye := FALSE;
    IF v_n % 2 = 1 THEN v_n := v_n + 1; v_has_bye := TRUE; END IF;
    v_rounds := v_n - 1;

    SELECT ARRAY(SELECT tp.team_id FROM tournament_participants tp WHERE tp.tournament_id = p_tournament_id ORDER BY tp.seed NULLS LAST, tp.team_id) INTO v_arr;
    IF v_has_bye THEN v_arr := v_arr || ARRAY[NULL::bigint]; END IF;

    FOR v_round IN 1..v_rounds LOOP
        v_match_no := 1;
        FOR v_i IN 1..(v_n / 2) LOOP
            DECLARE
                v_a bigint := v_arr[v_i]; v_b bigint := v_arr[v_n - v_i + 1];
            BEGIN
                IF v_a IS NOT NULL AND v_b IS NOT NULL THEN
                    INSERT INTO matches (tournament_id, round_number, match_number, team_a_id, team_b_id, best_of, status) VALUES (p_tournament_id, v_round, v_match_no, v_a, v_b, 3, 'scheduled');
                    v_match_no := v_match_no + 1;
                END IF;
            END;
        END LOOP;
        v_tmp := v_arr[v_n];
        FOR v_i IN REVERSE v_n..3 LOOP v_arr[v_i] := v_arr[v_i - 1]; END LOOP;
        v_arr[2] := v_tmp;
    END LOOP;
END;
$$;