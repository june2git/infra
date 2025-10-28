output "bastion_public_ip" {
  value       = aws_instance.eks_bastion.public_ip
  description = "The public IP of the myeks-host EC2 instance."
}

output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS 클러스터 엔드포인트"
  value       = module.eks.cluster_endpoint
}
