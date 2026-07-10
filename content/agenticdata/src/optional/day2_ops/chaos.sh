#!/bin/bash
# =====================================================================
# Cymbal SRE chaos drill -- "The Quiet Bronze"
#
# You were told to run this WITHOUT reading it first. If you are here
# now, you are either mid-diagnosis (welcome -- the crime scene is
# below) or you peeked. We will pretend it is the former.
#
# WHAT THIS DOES -- two SQL statements, nothing more:
#
#   1. ALTER ROLE datastream_user NOLOGIN;
#        Datastream's replication user may not open NEW connections.
#
#   2. SELECT pg_terminate_backend(pid) FROM pg_stat_activity
#        WHERE usename = 'datastream_user';
#        ...and its CURRENT connection is killed. Datastream now
#        retries, fails to log in ("role \"datastream_user\" is not
#        permitted to log in"), and the stream stalls. Postgres itself
#        is perfectly healthy -- the simulator writes as user
#        `postgres` and never notices a thing. Bronze freezes while
#        the source keeps humming: the worst kind of quiet.
#
# WHY IT IS SAFE (strictly reversible):
#   The ONLY thing touched is the datastream_user role attribute --
#   never the data, never the publication (cymbal_pub), never the
#   replication slot (cymbal_slot). The slot keeps retaining WAL while
#   Datastream is locked out, so nothing is lost -- just delayed.
#
# THE FIX (one line, typed by a human, not by this script):
#   ALTER ROLE datastream_user LOGIN;
# =====================================================================
set -euo pipefail
: "${BK_DB_PASSWORD:?BK_DB_PASSWORD is not set -- run: source ~/.bashrc}"

export PGPASSWORD="$BK_DB_PASSWORD"
psql -v ON_ERROR_STOP=1 \
     -h "${BK_CYMBAL_DB_HOST:-localhost}" -p "${BK_CYMBAL_DB_PORT:-5432}" \
     -U postgres -d cymbal <<'SQL'
ALTER ROLE datastream_user NOLOGIN;
SELECT pg_terminate_backend(pid) AS replication_connection_terminated
FROM pg_stat_activity
WHERE usename = 'datastream_user';
SQL

echo
echo "[chaos] $(date -u +%H:%M:%S) UTC -- injected. Write this time down: your incident timeline starts now."
echo "[chaos] Postgres is fine. The simulator is fine. Something else is not."
echo "[chaos] Do NOT read this script yet. Go look at your dashboard."
