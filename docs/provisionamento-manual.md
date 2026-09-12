# Provisionamento Manual

Siga este guia para provisionar o RDS localmente sem a pipeline.

> **Pré-requisito:** O [k8s-infra](../../tech-challenge-soat-fiap-k8s-infra) já deve estar provisionado.

---

## Passo a passo

### 1. Autentique-se na AWS

```bash
aws sts get-caller-identity
```

### 2. Acesse a pasta do Terraform

```bash
cd terraform/
```

### 3. Inicialize com o backend remoto

```bash
terraform init \
  -backend-config="bucket=bucket-tfstate-1029" \
  -backend-config="key=db/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=meu-terraform-state-lock" \
  -backend-config="encrypt=true"
```

### 4. Visualize o plano

```bash
terraform plan
```

Revise o que será criado: um Security Group e uma instância RDS MySQL.

Para sobrescrever o usuário padrão:

```bash
terraform plan -var="db_username=meu_usuario"
```

### 5. Aplique

```bash
terraform apply
```

Confirme com `yes`.

> ⏱️ **Tempo esperado:** 8–12 minutos (o RDS leva tempo para inicializar).

---

## Verificar o resultado

```bash
# Ver todos os outputs (rds_endpoint é sensitive — não aparece sem -raw)
terraform output

# Ver a porta
terraform output rds_port

# Ver o endpoint (masked como sensitive, mas acessível assim)
terraform output -raw rds_endpoint

# Ver o ARN do secret no Secrets Manager
terraform output -raw module.rds.secret_arn
```

---

## Obter a senha do banco

A senha é gerenciada pelo AWS Secrets Manager. Para recuperá-la:

```bash
# 1. Obter o ARN do secret
SECRET_ARN=$(aws rds describe-db-instances \
  --db-instance-identifier oficina-rds \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' \
  --output text)

echo "Secret ARN: $SECRET_ARN"

# 2. Recuperar a senha
aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query 'SecretString' \
  --output text
```

A saída será um JSON como:
```json
{"username":"admindb","password":"AbCdEfGh1234!"}
```

Para extrair só a senha:

```bash
aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query 'SecretString' \
  --output text | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])"
```

> ⚠️ A senha é mascarada nos logs da pipeline com `::add-mask::`. Nunca a exponha em código ou commits.

---

## Conectar ao banco localmente (via tunnel)

O RDS está em uma subnet privada — não é acessível diretamente da internet. Para conectar localmente, use um pod do EKS como jump:

```bash
# 1. Configure o kubectl
aws eks update-kubeconfig --region us-east-1 --name oficina-cluster

# 2. Obtenha o endpoint do RDS
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)

# 3. Crie um pod temporário com MySQL client
kubectl run mysql-client --rm -it --image=mysql:8.0 -- \
  mysql -h "$RDS_ENDPOINT" -u admindb -p

# 4. Digite a senha quando solicitado
```

---

## Destruir o banco

```bash
terraform destroy
```

> ⚠️ `deletion_protection = false` — o banco será deletado imediatamente. Todos os dados serão perdidos. Use apenas em ambiente de desenvolvimento/acadêmico.

---

## Reprovisionar após nova sessão do Academy

```bash
# 1. Atualize as credenciais
aws configure set aws_access_key_id     "NOVA_KEY"
aws configure set aws_secret_access_key "NOVO_SECRET"
aws configure set aws_session_token     "NOVO_TOKEN"

# 2. Re-aplique (Terraform detecta o que precisa recriar)
cd terraform/
terraform apply
```
