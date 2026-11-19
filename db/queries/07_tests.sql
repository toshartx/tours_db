-- 07_tests.sql
DO $$ BEGIN RAISE NOTICE '--- ТЕСТЫ ТРИГГЕРОВ ---'; END $$;

-- 1. trg_users_updated_at
DO $$
DECLARE v_before timestamptz; v_after timestamptz;
BEGIN
    SELECT updated_at INTO v_before FROM users WHERE user_id = 2;
    PERFORM pg_sleep(0.1);
    UPDATE users SET last_login_at = now() WHERE user_id = 2;
    SELECT updated_at INTO v_after FROM users WHERE user_id = 2;
    IF v_after > v_before THEN RAISE NOTICE '✅ trg_users_updated_at OK'; ELSE RAISE EXCEPTION '❌ trg_users_updated_at FAIL'; END IF;
END $$;

-- 2. trg_tickets_resolved_at
DO $$
DECLARE v_id bigint; v_res timestamptz;
BEGIN
    INSERT INTO tickets (author_id, subject, body, category, status, priority) VALUES (2, 'Тест', 'Тело', 'other', 'resolved', 'low') RETURNING ticket_id, resolved_at INTO v_id, v_res;
    IF v_res IS NULL THEN RAISE EXCEPTION '❌ trg_tickets_resolved_at: не проставлен'; END IF;
    UPDATE tickets SET status = 'open' WHERE ticket_id = v_id;
    SELECT resolved_at INTO v_res FROM tickets WHERE ticket_id = v_id;
    IF v_res IS NOT NULL THEN RAISE EXCEPTION '❌ trg_tickets_resolved_at: не сброшен'; END IF;
    DELETE FROM tickets WHERE ticket_id = v_id;
    RAISE NOTICE '✅ trg_tickets_resolved_at OK';
END $$;

DO $$ BEGIN RAISE NOTICE '--- ТЕСТЫ ПРОЦЕДУР ---'; END $$;

-- 1. sp_register_user
DO $$
DECLARE v_id bigint;
BEGIN
    CALL sp_register_user('test@test.by', 'test_user', 'hash', TRUE);
    SELECT user_id INTO v_id FROM users WHERE username = 'test_user';
    IF v_id IS NULL THEN RAISE EXCEPTION '❌ sp_register_user FAIL'; END IF;
    RAISE NOTICE '✅ sp_register_user OK (user_id=%)', v_id;
END $$;

-- 2. sp_create_team (для test_user)
DO $$
DECLARE v_uid bigint;
BEGIN
    SELECT user_id INTO v_uid FROM users WHERE username = 'test_user';
    CALL sp_create_team(v_uid, 'Test Team 1', 'TT1');
    IF NOT EXISTS (SELECT 1 FROM teams WHERE name = 'Test Team 1') THEN RAISE EXCEPTION '❌ sp_create_team FAIL'; END IF;
    RAISE NOTICE '✅ sp_create_team OK';
END $$;

-- 3. sp_submit_application (заявка от test_user в команду 1)
DO $$
DECLARE v_uid bigint; v_pid bigint;
BEGIN
    SELECT user_id, player_id INTO v_uid, v_pid FROM users JOIN players USING (user_id) WHERE username = 'test_user';
    CALL sp_submit_application(1, v_pid, 'Хочу в Wolves');
    IF NOT EXISTS (SELECT 1 FROM applications WHERE player_id = v_pid AND status = 'pending') THEN RAISE EXCEPTION '❌ sp_submit_application FAIL'; END IF;
    RAISE NOTICE '✅ sp_submit_application OK';
END $$;

DO $$ BEGIN RAISE NOTICE '--- ВСЕ ТЕСТЫ ЗАВЕРШЕНЫ ---'; END $$;
-- Откат:
-- DELETE FROM applications WHERE player_id = (SELECT player_id FROM players WHERE nickname = 'test_user');
-- DELETE FROM team_members WHERE team_id = (SELECT team_id FROM teams WHERE name = 'Test Team 1');
-- DELETE FROM user_roles WHERE user_id = (SELECT user_id FROM users WHERE username = 'test_user');
-- DELETE FROM teams WHERE name = 'Test Team 1';
-- DELETE FROM players WHERE nickname = 'test_user';
-- DELETE FROM users WHERE username = 'test_user';