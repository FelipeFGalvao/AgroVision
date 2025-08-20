# ===================================================================
# Bloco 1: Configuração do Provedor e do Backend
# Define que estamos usando a AWS e a região escolhida (us-east-2).
# O backend "local" significa que o ficheiro de estado do Terraform
# (que rastreia a infraestrutura) será guardado na sua máquina.
# ===================================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = "us-east-2" 
}

# ===================================================================
# Bloco 2: Registro de Contêiner (ECR)
# Cria o repositório privado para armazenar a imagem Docker da sua
# aplicação, conforme a sua escolha.
# ===================================================================
resource "aws_ecr_repository" "agrovision_repo" {
  name                 = "agrovision-prod-app" # Nome do repositório
  image_tag_mutability = "MUTABLE"             # Permite sobrescrever tags como "latest"

  image_scanning_configuration {
    scan_on_push = true # Boa prática: verifica vulnerabilidades a cada novo push
  }

  tags = {
    Project = "agrovision-prod"
    ManagedBy = "Terraform"
  }
}

# ===================================================================
# Bloco 3: Serviço da Aplicação (App Runner)
# O coração da sua infraestrutura. Cria o serviço App Runner que
# executa a sua aplicação.
# ===================================================================
resource "aws_apprunner_service" "agrovision_service" {
  service_name = "agrovision-prod-service" # Nome do serviço

  # Define a origem da imagem: o nosso repositório ECR
  source_configuration {
      authentication_configuration {
        access_role_arn = aws_iam_role.apprunner_access_role.arn
    }
    image_repository {
      image_identifier      = "${aws_ecr_repository.agrovision_repo.repository_url}:latest" # Aponta para a tag 'latest'
      image_repository_type = "ECR"
      image_configuration {
        port = "8501" # A porta que o Streamlit usa dentro do contêiner
      }
    }
    # A configuração de auto-deploy é ativada por padrão quando a origem é ECR.
    # O App Runner irá automaticamente buscar a nova imagem quando a tag 'latest' for atualizada.
    auto_deployments_enabled = true
  }

  # Define os recursos de CPU e Memória, conforme a sua escolha
  instance_configuration {
    cpu    = "2048" # 2 vCPU (2048 = 2 * 1024)
    memory = "4096" # 4 GB RAM (4096 = 4 * 1024)
  }

  # A escalabilidade é gerenciada pelo App Runner. Esta configuração
  # define os limites para o auto-scaling.
  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.default.arn

  tags = {
    Project = "agrovision-prod"
    ManagedBy = "Terraform"
  }
    depends_on = [
    aws_iam_role_policy_attachment.apprunner_ecr_policy
  ]
}

# Define uma configuração de auto-scaling padrão para o App Runner
resource "aws_apprunner_auto_scaling_configuration_version" "default" {
  auto_scaling_configuration_name = "default-agrovision-config"
  max_concurrency = 100 # Número de requisições simultâneas por instância antes de escalar
  min_size        = 1   # Sempre manter pelo menos 1 instância ativa
  max_size        = 3   # Escalar até no máximo 3 instâncias
  
  tags = {
    Project = "agrovision-prod"
    ManagedBy = "Terraform"
  }
}

# ===================================================================
# Bloco 4: Permissões para o CI/CD (GitHub Actions)
# Configura a conexão segura entre o GitHub e a AWS usando OIDC.
# Isso permite que o GitHub Actions faça o deploy sem precisar de
# chaves de acesso secretas.
# ===================================================================

# 1. Cria o Provedor de Identidade OIDC para o GitHub
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # Thumbprint padrão do GitHub
}

# 2. Cria a Política de Permissão para o GitHub Actions
# Define exatamente o que o GitHub pode fazer: apenas enviar a imagem para o ECR.
resource "aws_iam_policy" "github_actions_policy" {
  name        = "GitHubActionsECRPolicy-AgroVision"
  description = "Policy for GitHub Actions to push images to ECR for AgroVision"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ],
        Resource = aws_ecr_repository.agrovision_repo.arn
      }
    ]
  } )
}

# 3. Cria o "Role" (Papel) que o GitHub Actions irá assumir
resource "aws_iam_role" "github_actions_role" {
  name = "GitHubActionsRole-AgroVision"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringLike = {
            # V-- ESTA É A LINHA CORRETA PARA EDITAR --V
            "token.actions.githubusercontent.com:sub" = "repo:FelipeFGalvao/AgroVision:*"
          }
        }
      }
    ]
  })
}

# 4. Anexa a política de permissão ao papel
resource "aws_iam_role_policy_attachment" "attach_ecr_policy" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.github_actions_policy.arn
}

# ===================================================================
# Bloco 5: Outputs
# Exibe informações úteis após a execução do Terraform, como a URL
# da sua aplicação.
# ===================================================================
output "app_runner_service_url" {
  description = "The URL of the AgroVision web application"
  value       = aws_apprunner_service.agrovision_service.service_url
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository to push images to"
  value       = aws_ecr_repository.agrovision_repo.repository_url
}

output "github_actions_role_arn" {
  description = "The ARN of the IAM Role for GitHub Actions to assume"
  value       = aws_iam_role.github_actions_role.arn
}

# ===================================================================
# Bloco EXTRA: Papel de Acesso para o App Runner
# Cria um papel que o App Runner pode assumir para ter permissão
# de acessar outros serviços da AWS, como o ECR.
# ===================================================================
resource "aws_iam_role" "apprunner_access_role" {
  name = "AppRunnerECRAccessRole-AgroVision"

  # Define que o serviço App Runner é quem pode assumir este papel
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project   = "agrovision-prod"
    ManagedBy = "Terraform"
  }
}

# Anexa a política gerenciada pela AWS que dá acesso ao ECR
resource "aws_iam_role_policy_attachment" "apprunner_ecr_policy" {
  role       = aws_iam_role.apprunner_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}
