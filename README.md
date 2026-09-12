# 🗄️ tech-challenge-soat-fiap-db-infra

Provisionamento do banco de dados **Amazon RDS MySQL 8.0** da plataforma **Sistema de Gestão de Oficina** via Terraform.

Este repositório é o **segundo a ser executado** na cadeia de provisionamento. Ele depende dos outputs do `k8s-infra` (VPC, subnets, security groups) para colocar o RDS em rede isolada.

---

## 📑 Documentação

| Documento | Descrição |
|-----------|-----------|
| [Pré-requisitos](docs/prerequisitos.md) | AWS CLI, Terraform e credenciais necessárias |
| [Provisionamento Manual](docs/provisionamento-manual.md) | Passo a passo para aplicar o Terraform localmente |
| [Pipeline CI/CD](docs/pipeline.md) | Como funciona a pipeline e os GitHub Secrets necessários |
| [Recursos Provisionados](docs/recursos-provisionados.md) | Inventário do RDS e Security Group criados |
| [Comandos Úteis](docs/comandos-uteis.md) | AWS CLI para RDS, Secrets Manager e Terraform |

---

## ⚡ Visão Rápida

```
┌──────────────────────────────────────────────────┐
│  Pré-requisito: k8s-infra já provisionado        │
│  (VPC, subnets e SG dos nodes EKS disponíveis)   │
└──────────────────┬───────────────────────────────┘
                   │
                   ▼
         terraform apply
                   │
                   ▼
┌──────────────────────────────────────────────────┐
│  RDS MySQL 8.0 (db.t3.micro)                     │
│  Database Subnets (privadas, sem acesso público) │
│  Senha gerenciada pelo AWS Secrets Manager       │
└──────────────────────────────────────────────────┘
```

---

## 🔗 Arquitetura

```
VPC: oficina-vpc (10.0.0.0/16)
│
└── Database Subnets (10.0.201.0/24, 10.0.202.0/24)
    │
    └── RDS MySQL 8.0 — oficina-rds
        ├── Security Group: porta 3306 apenas do CIDR da VPC
        ├── Senha: AWS Secrets Manager (gerenciada automaticamente)
        ├── Backup: diário 03:00–06:00 UTC (1 dia de retenção)
        └── Charset: utf8mb4

Acessado por:
  ├── oficina-api (EKS) — via JDBC na private subnet
  └── auth-lambda        — via JDBC direto (private subnet)
```

---

## 🗂️ Estrutura do Repositório

```
.
├── .github/
│   └── workflows/
│       └── pipeline.yml        # Pipeline CI/CD (Plan → Apply)
├── terraform/
│   ├── modules/
│   │   └── rds/
│   │       ├── main.tf         # Security Group + módulo RDS
│   │       ├── variables.tf    # Variáveis do módulo
│   │       └── outputs.tf      # endpoint, port, secret_arn
│   ├── main.tf                 # Lê remote state do k8s-infra + chama módulo rds
│   ├── variables.tf            # region, app_name, db_username, db_name
│   ├── outputs.tf              # rds_endpoint, rds_port
│   ├── backend.tf              # State em S3: db/terraform.tfstate
│   └── provider.tf             # AWS ~> 6.0, Terraform >= 1.6.0
└── docs/                       # Documentação detalhada
```

---

## 🔄 Ordem de Provisionamento

```
[1] k8s-infra   →  VPC + EKS + ECR + API GW   ✅ deve estar pronto
[2] db-infra    →  RDS MySQL                   ← ESTE REPOSITÓRIO
[3] auth-lambda →  Lambda + rota API GW
[4] Aplicação   →  Helm → EKS
```

> ⚠️ O `k8s-infra` **precisa estar aplicado** antes deste repo. O Terraform lê o remote state do k8s-infra para obter `vpc_id`, `database_subnets`, `db_subnet_group_name` e `eks_node_security_group_id`.

---

## 🛠️ Tecnologias

| Tecnologia | Versão | Uso |
|-----------|--------|-----|
| Terraform | >= 1.6.0 | Provisionamento |
| AWS Provider | ~> 6.0 | Recursos AWS |
| terraform-aws-modules/rds | latest | Módulo RDS gerenciado |
| Amazon RDS | MySQL 8.0 | Banco de dados relacional |
| AWS Secrets Manager | — | Gerenciamento da senha do banco |

---

## 🔗 Links Relacionados

- [k8s-infra](../tech-challenge-soat-fiap-k8s-infra) — deve ser provisionado antes
- [auth-lambda](../tech-challenge-soat-fiap-auth-lambda) — consome o RDS após criado
- [Repositório principal](../tech-challenge-soat-fiap) — aplicação que usa este banco
- [Swagger UI](https://<API_GATEWAY_URL>/swagger-ui/index.html) *(disponível após deploy da app)*
