-- Datastream logical-replication setup for the Cymbal database.
-- Run through the IAP tunnel with the password passed as a psql variable:
--
--   PGPASSWORD="$BK_DB_PASSWORD" psql -h localhost -p 5432 -U postgres -d cymbal \
--       -v ds_password="$BK_DS_PASSWORD" \
--       -f content/agenticdata/src/datastream/replication_setup.sql
--
-- Notes:
--  * The replication user follows the documented Cloud SQL pattern
--    (WITH REPLICATION IN ROLE cloudsqlsuperuser).
--  * FOR ALL TABLES avoids the classic "table missing from publication"
--    stream-validation failure.
--  * Names are case-sensitive when referenced at stream creation
--    (cymbal_pub / cymbal_slot -- keep lowercase everywhere).

CREATE USER datastream_user WITH REPLICATION IN ROLE cloudsqlsuperuser LOGIN PASSWORD :'ds_password';

GRANT USAGE ON SCHEMA cymbal TO datastream_user;
GRANT SELECT ON ALL TABLES IN SCHEMA cymbal TO datastream_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA cymbal GRANT SELECT ON TABLES TO datastream_user;

CREATE PUBLICATION cymbal_pub FOR ALL TABLES;

SELECT PG_CREATE_LOGICAL_REPLICATION_SLOT('cymbal_slot', 'pgoutput');
