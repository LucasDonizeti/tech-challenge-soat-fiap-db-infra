# Recursos Provisionados

## Visão geral

Este repositório cria **2 recursos** na AWS dentro da VPC provisionada pelo `k8s-infra`:

| Recurso | Nome | Tipo |
|---------|------|------|
| Security Group | `oficina-rds-sg` | `aws_security_group` |
| RDS MySQL | `oficina-rds` | via `terraform-aws-modules/rds/aws` |

A senha do banco é automaticamente gerenciada pelo **AWS Secrets Manager** — nenhum secret de senha precisa ser configurado manualmente.

---

## Security Group — `oficina-rds-sg`

| Regra | Direção | Porta | Origem | Finalidade |
|-------|---------|-------|--------|-----------|
| MySQL | Ingress | 3306/TCP | CIDR da VPC (`10.0.0.0/16`) | Permite acesso de qualquer recurso dentro da VPC (EKS nodes, Lambda) |
| All traffic | Egress | All | `0.0.0.0/0` | Respostas e conexões de saída |

> O acesso é restrito ao CIDR da VPC. O RDS **não é acessível pela internet**.

---

## RDS MySQL — `oficina-rds`

| Parâmetro | Valor |
|-----------|-------|
| Identificador | `oficina-rds` |
| Engine | MySQL 8.0 |
| Versão da família | `mysql8.0` |
| Instância | `db.t3.micro` |
| Storage | 20 GB (gp2) |
| Schema padrão | `oficina` |
| Usuário master | `admindb` (padrão) |
| Senha | Gerenciada pelo AWS Secrets Manager |
| Porta | `3306` |
| Multi-AZ | `false` (single-AZ) |
| Subnets | Database Subnets privadas do k8s-infra |
| Acesso público | `false` |
| Backup diário | `true` — janela: 03:00–06:00 UTC |
| Retenção de backup | 1 dia |
| Maintenance window | Segunda: 00:00–03:00 UTC |
| Charset cliente | `utf8mb4` |
| Charset servidor | `utf8mb4` |
| Deletion protection | `false` (acadêmico) |
| Monitoring role | Não criado (AWS Academy) |

---

## AWS Secrets Manager

O RDS é criado com `manage_master_user_password = true`, o que faz a AWS gerar e rotacionar automaticamente a senha no Secrets Manager.

O ARN do secret é exportado como output `secret_arn` do módulo:

```bash
# Obter o ARN do secret
terraform output -raw module.rds.secret_arn

# Ou via AWS CLI
aws rds describe-db-instances \
  --db-instance-identifier oficina-rds \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' \
  --output text
```

---

## Topologia de rede

```
VPC: oficina-vpc (10.0.0.0/16)
│
└── Database Subnets
    ├── 10.0.201.0/24 (us-east-1a)
    └── 10.0.202.0/24 (us-east-1b)
        │
        └── RDS MySQL (oficina-rds) — apenas us-east-1a (single-AZ)
            └── Security Group: sg-...
                └── Ingress 3306 from 10.0.0.0/16

Acessado por:
  ├── EKS Nodes (10.0.1.0/24, 10.0.2.0/24) — via Spring DataSource JDBC
  └── Lambda Authorizer (mesmas private subnets) — via JDBC direto
```

---

## Outputs exportados

| Output | Sensível | Descrição |
|--------|----------|-----------|
| `rds_endpoint` | Sim | Hostname do RDS (ex: `oficina-rds.xyz.us-east-1.rds.amazonaws.com`) |
| `rds_port` | Não | Porta do banco (`3306`) |

> O endpoint é `sensitive = true` — não aparece em `terraform output` sem o flag `-raw`.

```bash
# Ver endpoint
terraform output -raw rds_endpoint

# Ver porta
terraform output rds_port
```

---

## Como a aplicação se conecta

A pipeline do repositório principal (`tech-challenge-soat-fiap`) recupera o endpoint e a senha dinamicamente:

```bash
# Endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier oficina-rds \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

# Senha (do Secrets Manager)
SECRET_ARN=$(aws rds describe-db-instances \
  --db-instance-identifier oficina-rds \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' \
  --output text)

DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query 'SecretString' \
  --output text | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")

# URL final para o Spring Boot
SPRING_DATASOURCE_URL="jdbc:mysql://${RDS_ENDPOINT}:3306/oficina"
```

---

## Custo estimado

| Recurso | Custo/h | Custo/dia |
|---------|---------|---------|
| RDS `db.t3.micro` | ~$0.017 | ~$0.41 |
| Storage 20 GB | ~$0.0027 | ~$0.065 |
| **Total** | **~$0.020** | **~$0.48** |

> 💡 O RDS continua rodando mesmo que o EKS seja destruído. Para economizar créditos, destrua o RDS também com `terraform destroy`.
