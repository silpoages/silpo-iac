# Acessando o banco (RDS) pelo DBeaver

O RDS fica numa subnet privada, sem acesso pela internet. Para chegar nele, o script
`scripts/db-tunnel.sh` abre um túnel da sua máquina até o banco passando pela task da API que já
roda no ECS (ECS Exec + SSM port forwarding). Não tem bastion, VPN nem porta aberta: só quem tem
credencial AWS no grupo certo consegue abrir o túnel.

```
DBeaver ──► localhost:5433 ──(túnel SSM)──► task da API no ECS ──► RDS :5432
```

> ⚠️ É o banco de **produção** (o projeto só tem um ambiente). Use com cuidado, principalmente
> com `UPDATE`/`DELETE`.

## 1. Configuração (uma vez só)

### Pedir acesso

Peça para quem administra a AWS do projeto:

1. Criar um usuário IAM para você (se ainda não tiver) com uma **access key**.
2. Te adicionar ao grupo **`silpo-shared-db-access`**:

   ```bash
   aws iam add-user-to-group --group-name silpo-shared-db-access --user-name <seu-usuario>
   ```

O grupo só permite abrir o túnel e ler a credencial do banco, nada além disso.

### Instalar as ferramentas

| O quê | macOS | Linux | Windows |
| ----- | ----- | ----- | ------- |
| AWS CLI v2 | `brew install awscli` | [instalador](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | [instalador .msi](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Session Manager plugin | `brew install --cask session-manager-plugin` | [.deb/.rpm](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) | [instalador](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) |
| Bash | já vem | já vem | **Git Bash** (vem com o [Git for Windows](https://git-scm.com/download/win)) |

Confira com `aws --version` e `session-manager-plugin --version`.

### Configurar a credencial AWS

```bash
aws configure --profile silpo
# AWS Access Key ID:     <sua access key>
# AWS Secret Access Key: <seu secret>
# Default region name:   us-east-2
# Default output format: json
```

## 2. Uso no dia a dia

No clone do `silpo-iac`:

```bash
AWS_PROFILE=silpo ./scripts/db-tunnel.sh
```

O script mostra os dados de conexão (host, porta, database, usuário e senha) e mantém o túnel
aberto. **Deixe o terminal aberto** enquanto usar o banco; `Ctrl+C` fecha o túnel.

Para usar outra porta local (ex.: se a 5433 já estiver em uso): `./scripts/db-tunnel.sh 5434`.

### Configurar o DBeaver

1. **Nova conexão** → **PostgreSQL**.
2. Aba **Main**:
   - Host: `localhost`
   - Port: `5433` (ou a porta que você passou para o script)
   - Database, Username e Password: os que o script mostrou. Marque **Save password**.
3. **Test Connection** → **Finish**.

A senha do banco só muda se a infra for recriada. Então, depois de configurar uma vez, no dia a dia
é só rodar o script e conectar no DBeaver.

## Problemas comuns

| Mensagem | O que fazer |
| -------- | ----------- |
| `Sem credenciais AWS válidas` | Rode `aws configure --profile silpo` e use `AWS_PROFILE=silpo`. |
| `Não consegui ler o secret` | Seu usuário ainda não está no grupo `silpo-shared-db-access`. |
| `Nenhuma task da API rodando` | Um deploy está trocando a task. Espere 1–2 minutos e rode de novo. |
| `não tem ECS Exec ligado` | A task foi criada antes de o ECS Exec ser ativado. Alguém precisa forçar um novo deploy da API. |
| O túnel caiu sozinho | A task foi trocada (deploy) ou ficou muito tempo ociosa. Rode o script de novo. |
| DBeaver reclama de SSL | Na aba **SSL** da conexão, marque *Use SSL* com *SSL mode* = `require`. |
| `Address already in use` | A porta local já está em uso. Rode com outra: `./scripts/db-tunnel.sh 5434`. |
