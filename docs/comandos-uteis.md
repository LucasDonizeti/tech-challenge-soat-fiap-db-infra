# Comandos Úteis

Referência rápida de comandos AWS CLI e Terraform para operar o banco de dados.

---

## Terraform

```bash
# Inicializar
terraform init \
  -backend-config="bucket=bucket-tfstate-1029" \
  -backend-config="key=db/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=meu-terraform-state-lock" \
  -backend-config="encrypt=true"

# Planejar
terraform plan

# Aplicar
terraform apply

# Ver todos os outputs
terraform output

# Ver endpoint (sensitive)
terraform output -raw rds_endpoint

# Ver porta
terraform output rds_port

# Destruir
terraform destroy
```

---

## AWS CLI — RDS

```bash
# Listar instâncias RDS
aws rds describe-db-instances --region us-east-1 \
  --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,Endpoint:Endpoint.Address}' \
  --output table

# Ver status de uma instância específica
aws rds describe-db-instances \
  --db-instance-identifier oficina-rds \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address,Port:Endpoint.Port}' \
  --output table

# Obter endpoint do RDS
aws rds describe-db-instances \
  --db-instance-identifier oficina-rds \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text

# Obter ARN do secret da senha
aws rds describe-db-instances \
  --db-instance-identifier oficina-rds \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' \
  --output text

# Listar snapshots do banco
aws rds describe-db-snapshots \
  --db-instance-identifier oficina-rds \
  --region us-east-1

# Criar snapshot manual
aws rds create-db-snapshot \
  --db-instance-identifier oficina-rds \
  --db-snapshot-identifier oficina-rds-manual-backup \
  --region us-east-1
```

---

## AWS CLI — Secrets Manager

```bash
# Listar secrets relacionados ao RDS
aws secretsmanager list-secrets \
  --filters Key=name,Values=rds \
  --region us-east-1

# Obter o valor do secret (JSON com username + password)
SECRET_ARN=$(aws rds describe-db-instances \
  --db-instance-identifier oficina-rds \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' \
  --output text)

aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query 'SecretString' \
  --output text

# Extrair apenas a senha
aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query 'SecretString' \
  --output text | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])"

# Extrair apenas o usuário
aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query 'SecretString' \
  --output text | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])"
```

---

## Conectar ao banco via kubectl (tunnel)

O RDS está em subnet privada. Para acessar localmente, use um pod temporário no EKS:

```bash
# 1. Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name oficina-cluster

# 2. Obtenha o endpoint e a senha
RDS_HOST=$(aws rds describe-db-instances \
  --db-instance-identifier oficina-rds \
  --query 'DBInstances[0].Endpoint.Address' --output text)

SECRET_ARN=$(aws rds describe-db-instances \
  --db-instance-identifier oficina-rds \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)

DB_PASS=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query 'SecretString' --output text \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")

# 3. Conecte via pod temporário
kubectl run mysql-client --rm -it \
  --image=mysql:8.0 \
  --restart=Never \
  -- mysql -h "$RDS_HOST" -u admindb -p"$DB_PASS" oficina
```

---

## Verificar conexão da aplicação

```bash
# Ver logs do pod para confirmar que o banco foi conectado
kubectl logs -l app.kubernetes.io/name=oficina --tail=50 \
  | grep -i "datasource\|flyway\|hibernate\|mysql\|connection"

# Verificar se o Flyway executou as migrations
kubectl logs -l app.kubernetes.io/name=oficina --tail=100 \
  | grep -i "flyway\|migration\|schema"
```

---

## Cheklist pós-provisionamento

```bash
# 1. RDS disponível
aws rds describe-db-instances \
  --db-instance-identifier oficina-rds \
  --query 'DBInstances[0].DBInstanceStatus' --output text
# Esperado: available

# 2. Secret criado
aws rds describe-db-instances \
  --db-instance-identifier oficina-rds \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text
# Esperado: arn:aws:secretsmanager:...

# 3. Endpoint disponível
aws rds describe-db-instances \
  --db-instance-identifier oficina-rds \
  --query 'DBInstances[0].Endpoint.Address' --output text
# Esperado: oficina-rds.xxx.us-east-1.rds.amazonaws.com
```
