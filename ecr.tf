# ECR 저장소 생성 (demo-app, kafka-producer, kafka-consumer)
resource "aws_ecr_repository" "apps" {
  for_each = var.ecr_repos

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"
  
  image_scanning_configuration { 
    scan_on_push = true 
  }

  tags = {
    Name        = "${var.ClusterBaseName}-ecr-${each.value}"
    Environment = "production"
    ManagedBy   = "terraform"
    Application = each.value
  }
}

# 모든 ECR 저장소 URL 출력
output "ecr_repository_urls" {
  description = "ECR 저장소 URL 맵"
  value = {
    for repo_name, repo in aws_ecr_repository.apps : repo_name => repo.repository_url
  }
}

# 모든 ECR 저장소 ARN 출력
output "ecr_repository_arns" {
  description = "ECR 저장소 ARN 맵"
  value = {
    for repo_name, repo in aws_ecr_repository.apps : repo_name => repo.arn
  }
}

# 개별 저장소 URL (하위 호환성)
output "demo_app_ecr_url" {
  description = "Demo App ECR 저장소 URL"
  value       = aws_ecr_repository.apps["demo-app"].repository_url
}

output "kafka_producer_ecr_url" {
  description = "Kafka Producer ECR 저장소 URL"
  value       = aws_ecr_repository.apps["kafka-producer"].repository_url
}

output "kafka_consumer_ecr_url" {
  description = "Kafka Consumer ECR 저장소 URL"
  value       = aws_ecr_repository.apps["kafka-consumer"].repository_url
}

