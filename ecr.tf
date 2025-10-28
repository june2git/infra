resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repo
  image_tag_mutability = "IMMUTABLE" #
  image_scanning_configuration { 
    scan_on_push = true 
  }

  tags = {
    Name        = "${var.ClusterBaseName}-ecr"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  value = aws_ecr_repository.app.arn
}

