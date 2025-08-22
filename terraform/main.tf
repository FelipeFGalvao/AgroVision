# ===================================================================
# Bloco 1: Configuração do Provedor e do Backend
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
# ===================================================================
resource "aws_ecr_repository" "agrovision_repo" {
  name                 = "agrovision-prod-app" 
  image_tag_mutability = "MUTABLE"             # Permite sobrescrever tags como "latest"

  image_scanning_configuration {
    scan_on_push = true # olhar vulnerabilidades a cada push
  }

  tags = {
    Project = "agrovision-prod"
    ManagedBy = "Terraform"
  }
}

# ===================================================================
# Bloco 3: Serviço da Aplicação (App Runner)
# ===================================================================
resource "aws_apprunner_service" "agrovision_service" {
  service_name = "agrovision-prod-service" 

  source_configuration {
      authentication_configuration {
        access_role_arn = aws_iam_role.apprunner_access_role.arn
    }
    image_repository {
      image_identifier      = "${aws_ecr_repository.agrovision_repo.repository_url}:latest" 
      image_repository_type = "ECR"
      image_configuration {
        port = "8501" 
      }
    }
    auto_deployments_enabled = true
  }

  # Define os recursos de CPU e Memória, conforme a sua escolha
  instance_configuration {
    cpu    = "2048" # 2 vCPU
    memory = "4096" # 4 GB RAM
  }

  health_check_configuration {
    protocol    = "HTTP"  
    path        = "/healthz" 
    interval    = 20       
    timeout     = 10       
    healthy_threshold   = 1 
    unhealthy_threshold = 3 
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
  min_size        = 1   
  max_size        = 3   
  
  tags = {
    Project = "agrovision-prod"
    ManagedBy = "Terraform"
  }
}

# ===================================================================
# Bloco 4: Permissões para o CI/CD (GitHub Actions)
# ===================================================================

# 1. Cria o Provedor de Identidade OIDC para o GitHub
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # Thumbprint padrão do GitHub
}

# 2. Cria a Política de Permissão para o GitHub Actions
resource "aws_iam_policy" "github_actions_policy" {
  name        = "GitHubActionsECRPolicy-AgroVision"
  description = "Policy for GitHub Actions to push images to ECR for AgroVision"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        # Declaração 1: Permite obter o token de login para a região
        Effect   = "Allow",
        Action   = "ecr:GetAuthorizationToken",
        Resource = "*"
      },
      {
        # Declaração 2: Permite enviar a imagem para o repositório específico
        Effect   = "Allow",
        Action   = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ],
        Resource = aws_ecr_repository.agrovision_repo.arn
      }
    ]
  })
}

# 3. Cria o "Role" que o GitHub Actions irá assumir
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
