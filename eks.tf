########################
# Provider Definitions #
########################

# AWS 공급자: 지정된 리전에서 AWS 리소스를 설정
provider "aws" {
  region = var.TargetRegion
}

# 요구 프로바이더 버전: helm 2.12.1
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.1"
    }
  }
}

# Kubernetes 공급자: EKS 클러스터와 연결 (엔드포인트, 인증 토큰, CA 인증서 사용)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Helm 공급자: EKS 클러스터에서 Helm Chart 배포를 관리
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}



##################
# Data Resources #
##################

# AWS 계정 정보 조회 (현재 실행 중인 AWS 계정의 정보)
# 사용 예: Account ID를 IAM 역할 ARN 구성에 활용
data "aws_caller_identity" "current" {}

# Local 변수: EKS 클러스터의 OIDC 공급자 ARN을 구성
# IRSA(IAM Roles for Service Accounts)에서 사용
locals {
  cluster_oidc_issuer_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}"
}

# Data Source: EKS 클러스터 메타데이터 조회
# 클러스터 엔드포인트, 보안 그룹 등의 정보를 가져옴
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks]                           # EKS 클러스터가 먼저 생성되어야 함
}

# Data Source: EKS 클러스터 인증 정보 조회
# kubectl 명령어 실행 시 필요한 인증 토큰을 가져옴
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}



########################
# Security Group Setup #
########################

# 보안 그룹: EKS 워커 노드용 보안 그룹 생성
# 워커 노드 간 통신 및 외부 트래픽을 제어
resource "aws_security_group" "node_group_sg" {
  name        = "${var.ClusterBaseName}-node-group-sg"  # 보안 그룹 이름
  description = "Security group for EKS Node Group"     # 설명
  vpc_id      = module.vpc.vpc_id                       # VPC ID

  tags = {
    Name = "${var.ClusterBaseName}-node-group-sg"
  }
}

# 보안 그룹 규칙: 특정 IP에서 EKS 워커 노드로 SSH(22번 포트) 접속 허용
# 주의: 운영 환경에서는 Bastion Host를 통한 접근을 권장
resource "aws_security_group_rule" "allow_ssh" {
  type        = "ingress"                              # 인바운드 규칙
  from_port   = 22                                     # SSH 포트
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["192.168.1.100/32"]                   # 허용할 IP 범위 (예시)

  security_group_id = aws_security_group.node_group_sg.id
}



#######################
# Amazon EKS Cluster  #
#######################

# EKS 모듈: 관리형 노드 그룹 및 기본 애드온이 포함된 EKS 클러스터 생성
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~>20.0"

  # 클러스터 기본 설정
  cluster_name = var.ClusterBaseName                  # EKS 클러스터 이름
  cluster_version = var.KubernetesVersion             # Kubernetes 버전 (예: 1.29, 1.30)
  cluster_endpoint_private_access = false             # VPC 내부에서만 접근 가능 (현재: 비활성화)
  cluster_endpoint_public_access  = true              # 인터넷에서 직접 접근 가능 (현재: 활성화)

  # 클러스터 애드온 설정 (EKS에서 관리하는 필수 구성 요소)
  cluster_addons = {
    # CoreDNS: Kubernetes 클러스터 내부 DNS 서버
    coredns = {
      most_recent = true                              # 최신 버전 자동 사용
    }
    # kube-proxy: 클러스터 네트워크 규칙 관리 (Service와 Pod 간 트래픽 라우팅)
    kube-proxy = {
      most_recent = true
    }
    # VPC CNI: AWS VPC 네트워크를 Pod에 직접 할당
    vpc-cni = {
      most_recent = true
    }
    # EBS CSI Driver: Amazon EBS 볼륨을 Kubernetes PersistentVolume으로 사용
    aws-ebs-csi-driver = {
      most_recent = true
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn  # IRSA를 통한 IAM 권한 부여
    }
    # External-DNS: Kubernetes Ingress를 감지하여 Route 53 DNS 레코드 자동 생성
    external-dns = {
      most_recent = true
    }
  }

  # 네트워크 설정
  vpc_id = module.vpc.vpc_id                          # EKS 클러스터가 위치할 VPC ID
  enable_irsa = true                                  # IRSA(IAM Roles for Service Accounts) 활성화
  subnet_ids = module.vpc.public_subnets              # 노드 그룹이 배포될 서브넷 목록
  
  # EKS 관리형 노드 그룹 설정 (워커 노드)
  eks_managed_node_groups = {
    default = {
      # 노드 그룹 기본 정보
      name             = "${var.ClusterBaseName}-node-group"  # 노드 그룹 이름
      use_name_prefix  = false                                # 이름 접두사 사용 안 함
      
      # 인스턴스 설정
      instance_types   = ["${var.WorkerNodeInstanceType}"]    # EC2 인스턴스 타입 (예: t3.medium)
      desired_size     = var.WorkerNodeCount                  # 초기 노드 수
      max_size         = var.WorkerNodeCount + 2              # 최대 노드 수 (Auto Scaling)
      min_size         = var.WorkerNodeCount - 1              # 최소 노드 수
      disk_size        = var.WorkerNodeVolumesize             # 루트 볼륨 크기 (GB)
      
      # 네트워크 및 접근 설정
      subnets          = module.vpc.public_subnets            # 노드가 배포될 서브넷
      key_name         = "kp_node"                            # SSH 키페어 이름 (노드 접속용)
      vpc_security_group_ids = [aws_security_group.node_group_sg.id]  # 보안 그룹 ID
      
      # IAM 역할 설정
      iam_role_name    = "${var.ClusterBaseName}-node-group-eks-node-group"  # IAM 역할 이름
      iam_role_use_name_prefix = false                        # IAM 역할 이름 접두사 사용 안 함
      iam_role_additional_policies = {
        # External-DNS가 Route 53을 수정할 수 있도록 정책 추가
        "${var.ClusterBaseName}ExternalDNSPolicy" = aws_iam_policy.external_dns_policy.arn
      } 
   }
  }

  # 의존성 설정: Bastion 서버가 먼저 생성된 후 EKS 클러스터 생성
  depends_on = [aws_instance.eks_bastion]
  
  # EKS 클러스터 액세스 관리 (클러스터 API 접근 권한)
  access_entries = {
    # 관리자 액세스 엔트리
    admin = {
      kubernetes_groups = []                          # Kubernetes RBAC 그룹 (비어 있음)
      principal_arn     = "${data.aws_caller_identity.current.arn}"  # 현재 AWS 사용자/역할의 ARN
      
      # 정책 연결: EKS 클러스터 관리자 권한 부여
      policy_associations = {
        myeks = {
          # EKS 클러스터 전체에 대한 관리자 권한
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            namespaces = []                           # 모든 네임스페이스 접근 가능
            type       = "cluster"                    # 클러스터 전체에 적용
          }
        }
      }
    }
  }

  tags = {
    Environment = "cnaee-lab"
    Terraform   = "true"
  }
}



################
# IAM Policies #
################

# IAM 정책: ExternalDNS가 Route 53 DNS 레코드를 관리할 수 있도록 허용
# Kubernetes Ingress/Service를 감지하여 DNS 레코드를 자동으로 생성/업데이트/삭제
resource "aws_iam_policy" "external_dns_policy" {
  name        = "${var.ClusterBaseName}ExternalDNSPolicy"  # 정책 이름
  description = "Policy for allowing ExternalDNS to modify Route 53 records"

  policy = file("external_dns_policy.json")               # JSON 파일에서 정책 내용 로드
}

# IAM 정책: AWS Load Balancer Controller가 ALB/NLB를 관리할 수 있도록 허용
# Kubernetes Ingress 리소스를 감지하여 AWS ALB를 자동으로 생성/수정/삭제
resource "aws_iam_policy" "aws_lb_controller_policy" {
  name        = "${var.ClusterBaseName}AWSLoadBalancerControllerPolicy"  # 정책 이름
  description = "Policy for allowing AWS LoadBalancerController to modify AWS ELB"

  policy = file("aws_lb_controller_policy.json")         # JSON 파일에서 정책 내용 로드
}

# Data Source: AWS 관리형 IAM 정책 (EBS CSI Driver용)
# EBS 볼륨을 생성, 삭제, 연결, 스냅샷 생성 등의 작업을 수행할 수 있는 권한
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"  # AWS 관리형 정책 ARN
}


####################
# IRSA Roles Setup #
####################

# IRSA (IAM Roles for Service Accounts): AWS Load Balancer Controller용
# Kubernetes Service Account가 AWS IAM 권한을 안전하게 사용할 수 있도록 설정
module "irsa-lb-controller" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true                                        # IAM 역할 생성
  role_name                     = "AmazonEKSTFLBControllerRole-${module.eks.cluster_name}"  # 역할 이름
  provider_url                  = module.eks.oidc_provider                    # EKS OIDC 공급자 URL
  role_policy_arns              = [aws_iam_policy.aws_lb_controller_policy.arn]  # 연결할 IAM 정책 (ALB/NLB 관리)
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]  # Service Account 전체 경로
  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]                     # OIDC Audience (AWS STS)
}

# IRSA (IAM Roles for Service Accounts): EBS CSI Driver용
# EBS 볼륨을 생성, 연결, 삭제할 수 있는 권한을 Service Account에 부여
module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true                                        # IAM 역할 생성
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"  # 역할 이름
  provider_url                  = module.eks.oidc_provider                    # EKS OIDC 공급자 URL
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]   # AWS 관리형 EBS CSI 정책
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]  # Service Account 전체 경로
}


######################
# Helm Chart Install #
######################

# Helm Chart: AWS Load Balancer Controller를 EKS 클러스터에 배포
# Kubernetes Ingress 리소스를 감지하여 AWS ALB/NLB를 자동으로 생성/관리
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"        # Helm Release 이름
  repository = "https://aws.github.io/eks-charts"    # AWS 공식 Helm 저장소
  chart      = "aws-load-balancer-controller"        # Chart 이름
  namespace  = "kube-system"                         # 배포할 네임스페이스
  
  # Helm Chart 설정 값 (set 블록)
  set {
    name  = "clusterName"                            # EKS 클러스터 이름
    value = var.ClusterBaseName
  }
  set {
    name  = "serviceAccount.create"                  # Service Account 자동 생성
    value = "true"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"  # IRSA 역할 ARN 주입
    value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AmazonEKSTFLBControllerRole-${module.eks.cluster_name}"
  }
  set {
    name  = "region"                                 # AWS 리전
    value = "ap-northeast-2"
  }
  
  # 의존성: EKS 클러스터와 IRSA 역할이 먼저 생성되어야 함
  depends_on = [module.eks, module.irsa-lb-controller]
}