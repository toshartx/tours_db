-- 05_triggers.sql

-- 1. Обновление updated_at
CREATE OR REPLACE FUNCTION trg_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

-- 2. Автоматическая простановка resolved_at у тикетов
CREATE OR REPLACE FUNCTION trg_tickets_resolved_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'resolved' AND NEW.resolved_at IS NULL THEN
        NEW.resolved_at := now();
    ELSIF NEW.status <> 'resolved' AND NEW.resolved_at IS NOT NULL THEN
        NEW.resolved_at := NULL;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tickets_resolved_at ON tickets;
CREATE TRIGGER trg_tickets_resolved_at
BEFORE INSERT OR UPDATE OF status ON tickets
FOR EACH ROW EXECUTE FUNCTION trg_tickets_resolved_at();

-- 3. Автоматический кик из команды при её роспуске
CREATE OR REPLACE FUNCTION trg_teams_disband()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.disbanded_at IS NOT NULL AND OLD.disbanded_at IS NULL THEN
        UPDATE team_members
        SET left_at = GREATEST(NEW.disbanded_at::date, joined_at)
        WHERE team_id = NEW.team_id
          AND left_at IS NULL;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_teams_disband ON teams;
CREATE TRIGGER trg_teams_disband
AFTER UPDATE OF disbanded_at ON teams
FOR EACH ROW EXECUTE FUNCTION trg_teams_disband();

-- 4. Проверка вместимости турнира при регистрации команды
CREATE OR REPLACE FUNCTION trg_check_tournament_capacity()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_max      smallint;
    v_current  int;
BEGIN
    SELECT max_teams INTO v_max
    FROM tournaments
    WHERE tournament_id = NEW.tournament_id
    FOR UPDATE;

    IF v_max IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT COUNT(*) INTO v_current
    FROM tournament_participants
    WHERE tournament_id = NEW.tournament_id;

    IF v_current >= v_max THEN
        RAISE EXCEPTION 'Турнир % уже заполнен: % из % команд',
            NEW.tournament_id, v_current, v_max;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tournament_capacity ON tournament_participants;
CREATE TRIGGER trg_tournament_capacity
BEFORE INSERT ON tournament_participants
FOR EACH ROW EXECUTE FUNCTION trg_check_tournament_capacity();

-- 5. Автоматическое заполнение approved_at при пике карты
CREATE OR REPLACE FUNCTION trg_match_games_approved_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.approved_by IS NOT NULL AND NEW.approved_at IS NULL THEN
        NEW.approved_at := now();
    ELSIF NEW.approved_by IS NULL AND NEW.approved_at IS NOT NULL THEN
        NEW.approved_at := NULL;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_match_games_approved_at ON match_games;
CREATE TRIGGER trg_match_games_approved_at
BEFORE INSERT OR UPDATE ON match_games
FOR EACH ROW EXECUTE FUNCTION trg_match_games_approved_at();

-- 6. Проверка на двойное членство в команде
CREATE OR REPLACE FUNCTION trg_no_double_active_membership()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.left_at IS NOT NULL THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        SELECT 1 FROM team_members tm
        WHERE tm.team_id   = NEW.team_id
          AND tm.player_id = NEW.player_id
          AND tm.left_at IS NULL
          AND tm.ctid <> NEW.ctid
    ) THEN
        RAISE EXCEPTION 'Игрок % уже активен в команде %',
            NEW.player_id, NEW.team_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_no_double_active_membership ON team_members;
CREATE TRIGGER trg_no_double_active_membership
BEFORE INSERT OR UPDATE ON team_members
FOR EACH ROW EXECUTE FUNCTION trg_no_double_active_membership();

-- 7. Защита audit_log от изменения
REVOKE UPDATE, DELETE, TRUNCATE ON audit_log FROM PUBLIC;

CREATE OR REPLACE FUNCTION trg_audit_log_immutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'audit_log защищён от изменения (ТЗ п.13)';
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_log_no_update ON audit_log;
CREATE TRIGGER trg_audit_log_no_update
BEFORE UPDATE OR DELETE ON audit_log
FOR EACH ROW EXECUTE FUNCTION trg_audit_log_immutable();

-- 8. Отправка результатов матча для подтверждения судьёй
CREATE OR REPLACE FUNCTION trg_match_games_to_pending_review()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_match        matches%ROWTYPE;
    v_approved     int;
    v_games_needed int;
BEGIN
    IF NEW.approved_by IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT * INTO v_match FROM matches WHERE match_id = NEW.match_id;
    v_games_needed := (v_match.best_of / 2) + 1;

    SELECT COUNT(*) INTO v_approved
    FROM match_games
    WHERE match_id = NEW.match_id AND approved_by IS NOT NULL;

    IF v_approved >= v_games_needed AND v_match.status = 'live' THEN
        UPDATE matches SET status = 'pending_review' WHERE match_id = NEW.match_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_match_games_pending_review ON match_games;
CREATE TRIGGER trg_match_games_pending_review
AFTER UPDATE OF approved_by ON match_games
FOR EACH ROW EXECUTE FUNCTION trg_match_games_to_pending_review();

-- 9. Логическое удаление пользователей
CREATE OR REPLACE FUNCTION trg_users_soft_delete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_admins int;
BEGIN
    IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
        NEW.is_active := FALSE;

        IF EXISTS (
            SELECT 1 FROM user_roles ur
            JOIN roles r ON r.role_id = ur.role_id
            WHERE ur.user_id = NEW.user_id AND r.code = 'admin'
        ) THEN
            SELECT COUNT(*) INTO v_admins
            FROM user_roles ur
            JOIN roles r ON r.role_id = ur.role_id
            WHERE r.code = 'admin' AND ur.user_id <> NEW.user_id;

            IF v_admins = 0 THEN
                RAISE EXCEPTION 'Нельзя удалить последнего администратора';
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_soft_delete ON users;
CREATE TRIGGER trg_users_soft_delete
BEFORE UPDATE OF deleted_at ON users
FOR EACH ROW EXECUTE FUNCTION trg_users_soft_delete();