# Pré-requisitos

## Ferramentas necessárias

| Ferramenta | Versão mínima | Instalação |
|-----------|--------------|-----------|
| Terraform | >= 1.6.0 | https://developer.hashicorp.com/terraform/install |
| AWS CLI | v2 | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |

---

## 1. k8s-infra deve estar provisionado

Este repositório lê o state remoto do `k8s-infra` via `terraform_remote_state`. Se o k8s-infra ainda não foi aplicado, o `terraform plan` falhará.

Verifique se o state existe:

```bash
aws s3 ls s3://bucket-tfstate-1029/k8s/terraform.tfstate
```

Se o arquivo existir, o k8s-infra está provisionado e você pode continuar.

---

## 2. Configurar AWS CLI

### Ambiente normal

```bash
aws configure
# Preencha: Access Key ID, Secret Access Key, região us-east-1, formato json
```

### AWS Academy (sessão temporária)

```bash
aws configure set aws_access_key_id     "ASIA..."
aws configure set aws_secret_access_key "..."
aws configure set aws_session_token     "..."
aws configure set region                "us-east-1"
```

Ou via variáveis de ambiente:

```bash
export AWS_ACCESS_KEY_ID="ASIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_DEFAULT_REGION="us-east-1"
```

> ⚠️ **AWS Academy:** credenciais expiram a cada ~4h. Atualize antes de cada execução.

Verifique:

```bash
aws sts get-caller-identity
```

---

## 3. Variáveis do Terraform

Todas as variáveis têm valores padrão, exceto opcionalmente o `db_username`. O padrão é `admindb`.

| Variável | Padrão | Sensível | Descrição |
|----------|--------|----------|-----------|
| `region` | `us-east-1` | Não | Região AWS |
| `app_name` | `oficina` | Não | Prefixo dos recursos |
| `db_name` | `oficina` | Não | Nome do schema criado no RDS |
| `db_username` | `admindb` | Sim | Usuário master do RDS |

A **senha** do banco **não é uma variável** — ela é gerada automaticamente pelo AWS Secrets Manager via `manage_master_user_password = true`.

Para sobrescrever o `db_username` via `tfvars` (opcional):

```hcl
# terraform/terraform.tfvars  (está no .gitignore)
db_username = "meu_usuario"
```
