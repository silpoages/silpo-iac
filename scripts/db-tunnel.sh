#!/usr/bin/env bash
# Opens a tunnel from your machine to the Silpo RDS database, through the running API task
# (ECS Exec + SSM port forwarding). While it's open, connect DBeaver/psql to localhost.
#
# Usage:   ./scripts/db-tunnel.sh [local-port]        (default port: 5433)
# Needs:   AWS CLI v2, the Session Manager plugin, and AWS credentials for a user in the
#          "silpo-shared-db-access" IAM group. Full guide: docs/db-access.md
#
# Env overrides: AWS_PROFILE, AWS_REGION (default us-east-2), SILPO_ENV (default shared).
set -euo pipefail

REGION="${AWS_REGION:-us-east-2}"
ENV_NAME="${SILPO_ENV:-shared}"
LOCAL_PORT="${1:-5433}"

CLUSTER="silpo-${ENV_NAME}"
SERVICE="silpo-${ENV_NAME}"
SECRET_ID="silpo-${ENV_NAME}/database"

fail() {
    printf '\n❌ %s\n\n' "$1" >&2
    exit 1
}

# --- Prerequisites -----------------------------------------------------------------------
command -v aws >/dev/null 2>&1 ||
    fail "AWS CLI não encontrado. Instale: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
command -v session-manager-plugin >/dev/null 2>&1 ||
    fail "Session Manager plugin não encontrado. Instale: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"

aws sts get-caller-identity --region "$REGION" >/dev/null 2>&1 ||
    fail "Sem credenciais AWS válidas. Rode 'aws configure' (ou defina AWS_PROFILE) — veja docs/db-access.md."

# --- Database credentials ----------------------------------------------------------------
secret="$(aws secretsmanager get-secret-value --region "$REGION" --secret-id "$SECRET_ID" \
    --query SecretString --output text 2>/dev/null)" ||
    fail "Não consegui ler o secret '$SECRET_ID'. Seu usuário está no grupo IAM 'silpo-${ENV_NAME}-db-access'?"

# The secret is flat JSON with string values only (see the rds-postgres module), and the
# password is restricted to [A-Za-z0-9-_.~], so a plain sed extraction is enough — no jq needed.
field() { printf '%s' "$secret" | sed -n "s/.*\"$1\" *: *\"\([^\"]*\)\".*/\1/p"; }
DB_HOST="$(field host)"
DB_PORT="$(field port)"
DB_NAME="$(field dbname)"
DB_USER="$(field username)"
DB_PASS="$(field password)"
[ -n "$DB_HOST" ] && [ -n "$DB_PASS" ] || fail "Formato inesperado no secret '$SECRET_ID'."

# --- Running task to tunnel through ------------------------------------------------------
task_arn="$(aws ecs list-tasks --region "$REGION" --cluster "$CLUSTER" --service-name "$SERVICE" \
    --desired-status RUNNING --query 'taskArns[0]' --output text)"
[ -n "$task_arn" ] && [ "$task_arn" != "None" ] ||
    fail "Nenhuma task da API rodando no cluster '$CLUSTER' (deploy em andamento?). Tente de novo em instantes."
task_id="${task_arn##*/}"

read -r exec_enabled runtime_id agent_status <<<"$(aws ecs describe-tasks --region "$REGION" \
    --cluster "$CLUSTER" --tasks "$task_id" \
    --query 'tasks[0].[enableExecuteCommand, containers[0].runtimeId, containers[0].managedAgents[?name==`ExecuteCommandAgent`].lastStatus | [0]]' \
    --output text)"
[ "$exec_enabled" = "True" ] ||
    fail "A task $task_id não tem ECS Exec ligado. Ela é anterior à mudança no silpo-iac — force um novo deploy da API."
[ "$agent_status" = "RUNNING" ] ||
    fail "O agente do ECS Exec ainda não está pronto na task (status: $agent_status). Tente de novo em ~1 minuto."

# --- Connection info + tunnel ------------------------------------------------------------
cat <<EOF

✅ Túnel pronto para abrir. Configure o DBeaver (ou psql) assim:

   Host:      localhost
   Porta:     $LOCAL_PORT
   Database:  $DB_NAME
   Usuário:   $DB_USER
   Senha:     $DB_PASS

   psql:      psql "postgresql://$DB_USER:$DB_PASS@localhost:$LOCAL_PORT/$DB_NAME?sslmode=require"

⚠️  Esse é o banco de PRODUÇÃO. Cuidado com UPDATE/DELETE.
   Deixe este terminal aberto enquanto usar o banco. Ctrl+C fecha o túnel.
   Se cair (ex.: depois de um deploy, a task muda), é só rodar o script de novo.

EOF

exec aws ssm start-session --region "$REGION" \
    --target "ecs:${CLUSTER}_${task_id}_${runtime_id}" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$DB_HOST\"],\"portNumber\":[\"$DB_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}"
