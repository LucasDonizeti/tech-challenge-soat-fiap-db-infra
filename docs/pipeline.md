# Pipeline CI/CD

A pipeline é acionada em todo push para `main` ou `develop` e executa dois jobs encadeados.

---

## Fluxo

```
Push → main / develop
         │
         ▼
┌─────────────────────────┐
│  Job 1: Plan            │  terraform init + terraform plan
│  terraform-plan         │  Salva o tfplan como artefato
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│  Job 2: Apply           │  terraform apply com o tfplan salvo
│  terraform-apply        │  + captura rds_endpoint como output
└─────────────────────────┘  + configura kubectl (para uso manual)
```

---

## GitHub Secrets obrigatórios

Acesse: **Repositório → Settings → Secrets and variables → Actions → New repository secret**

| Secret | Descrição | Como obter |
|--------|-----------|-----------|
| `AWS_ACCESS_KEY_ID` | ID da chave de acesso AWS | AWS Academy → **AWS Details** → `aws_access_key_id` |
| `AWS_SECRET_ACCESS_KEY` | Chave secreta de acesso AWS | AWS Academy → **AWS Details** → `aws_secret_access_key` |
| `AWS_SESSION_TOKEN` | Token de sessão temporário | AWS Academy → **AWS Details** → `aws_session_token` |
| `DB_USERNAME` | Usuário master do RDS | Valor livre — ex: `admindb` (padrão do Terraform) |

> **Nota:** A senha do banco **não é um secret** — ela é gerada automaticamente pelo AWS Secrets Manager. Não é necessário configurar um secret de senha para este repositório.

> ⚠️ **AWS Academy:** Os três secrets AWS expiram a cada ~4h. Atualize-os antes de cada execução da pipeline.

---

## Detalhes dos jobs

### Job 1 — Terraform Plan

1. Configura credenciais AWS
2. Instala Terraform 1.15.7
3. Executa `terraform init` com o backend S3
4. Executa `terraform plan -var="db_username=..."` com o secret `DB_USERNAME`
5. Salva o `tfplan` como artefato (retenção: 1 dia)

### Job 2 — Terraform Apply

1. Baixa o `tfplan` do Job 1
2. Re-executa `terraform init`
3. Aplica com `terraform apply -auto-approve tfplan`
4. Captura o `rds_endpoint` como output do job (para uso em outros workflows)
5. Configura `kubectl` para o cluster `oficina-cluster` (para verificações manuais)

---

## Output do Job 2

O endpoint do RDS é capturado como output do job e pode ser referenciado por outros workflows:

```yaml
# Em outro workflow que depende deste:
needs: terraform-apply
steps:
  - run: echo "RDS: ${{ needs.terraform-apply.outputs.rds_endpoint }}"
```

---

## Atualizar secrets do AWS Academy

1. Acesse o laboratório → **AWS Details**
2. Copie `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token`
3. No GitHub: **Settings → Secrets and variables → Actions**
4. Atualize os três secrets AWS
5. Faça um push ou re-run do último workflow

---

## Verificar status do RDS após apply

```bash
aws rds describe-db-instances \
  --db-instance-identifier oficina-rds \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address}' \
  --output table
```

Saída esperada:
```
---------------------------------
|    DescribeDBInstances         |
+----------+---------------------+
|  Status  | available           |
| Endpoint | oficina-rds.xyz.us-east-1.rds.amazonaws.com |
+----------+---------------------+
```
