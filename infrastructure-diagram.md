# 인프라 구조 도식화

## 전체 아키텍처

```mermaid
graph TB
    subgraph "AWS 리전: ap-northeast-2"
        subgraph "VPC: 192.168.0.0/16"
            subgraph "Public Subnets"
                PS1["Public Subnet 1<br/>192.168.1.0/24<br/>AZ: ap-northeast-2a"]
                PS2["Public Subnet 2<br/>192.168.2.0/24<br/>AZ: ap-northeast-2b"]
                PS3["Public Subnet 3<br/>192.168.3.0/24<br/>AZ: ap-northeast-2c"]
            end
            
            subgraph "Private Subnets"
                PRIV1["Private Subnet 1<br/>192.168.11.0/24<br/>AZ: ap-northeast-2a"]
                PRIV2["Private Subnet 2<br/>192.168.12.0/24<br/>AZ: ap-northeast-2b"]
                PRIV3["Private Subnet 3<br/>192.168.13.0/24<br/>AZ: ap-northeast-2c"]
            end
            
            IGW["Internet Gateway"]
            
            subgraph "EC2 인스턴스"
                BASTION["Bastion Host<br/>Instance: t3.medium<br/>IP: 192.168.1.100<br/>Ubuntu 22.04<br/>- kubectl, helm<br/>- eksctl, aws-cli<br/>- docker"]
            end
            
            subgraph "EKS 클러스터"
                EKS["EKS Control Plane<br/>myeks<br/>Kubernetes 1.32"]
                
                subgraph "관리형 노드 그룹"
                    NODE1["Worker Node 1<br/>t3.large<br/>Disk: 30GB"]
                    NODE2["Worker Node 2<br/>t3.large<br/>Disk: 30GB"]
                    NODE3["Worker Node 3<br/>t3.large<br/>Disk: 30GB"]
                end
                
                subgraph "EKS 애드온"
                    COREDNS["CoreDNS"]
                    KUBEPROXY["kube-proxy"]
                    VPCNI["VPC CNI"]
                    EBSCSI["EBS CSI Driver<br/>(IRSA)"]
                    EXTDNS["External-DNS<br/>(IRSA)"]
                end
                
                subgraph "Helm Charts"
                    ALB["AWS Load Balancer<br/>Controller<br/>(IRSA)"]
                end
                
                subgraph "Kubernetes 리소스"
                    SC["StorageClass: gp3<br/>(default)"]
                end
            end
        end
        
        subgraph "컨테이너 레지스트리"
            ECR1["ECR: demo-app"]
            ECR2["ECR: kafka-producer"]
            ECR3["ECR: kafka-consumer"]
        end
        
        subgraph "IAM 역할 및 정책"
            IRSA1["IRSA: EBS CSI<br/>Role"]
            IRSA2["IRSA: Load Balancer<br/>Controller Role"]
            IRSA3["IRSA: External-DNS<br/>Role"]
            GITHUB["GitHub Actions OIDC<br/>Role (ECR 푸시용)"]
        end
        
        subgraph "보안 그룹"
            SG1["eks-sec-group<br/>(Bastion용)<br/>SSH: 22"]
            SG2["node-group-sg<br/>(EKS 노드용)"]
        end
    end
    
    subgraph "외부"
        INTERNET["인터넷"]
        GITHUB_ACTIONS["GitHub Actions<br/>CI/CD"]
        ADMIN["관리자<br/>SSH 접근"]
    end
    
    %% 연결
    INTERNET --> IGW
    IGW --> PS1
    IGW --> PS2
    IGW --> PS3
    
    PS1 --> BASTION
    PS1 --> NODE1
    PS2 --> NODE2
    PS3 --> NODE3
    
    EKS --> NODE1
    EKS --> NODE2
    EKS --> NODE3
    
    NODE1 --> COREDNS
    NODE1 --> KUBEPROXY
    NODE1 --> VPCNI
    NODE1 --> EBSCSI
    NODE1 --> EXTDNS
    NODE1 --> ALB
    NODE1 --> SC
    
    ADMIN -->|SSH| SG1
    SG1 --> BASTION
    BASTION --> EKS
    
    GITHUB_ACTIONS -->|OIDC| GITHUB
    GITHUB --> ECR1
    GITHUB --> ECR2
    GITHUB --> ECR3
    
    ECR1 --> NODE1
    ECR2 --> NODE1
    ECR3 --> NODE1
    
    IRSA1 --> EBSCSI
    IRSA2 --> ALB
    IRSA3 --> EXTDNS
    
    style EKS fill:#ff9999
    style BASTION fill:#99ccff
    style ECR1 fill:#99ff99
    style ECR2 fill:#99ff99
    style ECR3 fill:#99ff99
    style GITHUB fill:#ffcc99
```

## 네트워크 구조 상세

```mermaid
graph LR
    subgraph "VPC: 192.168.0.0/16"
        subgraph "AZ: ap-northeast-2a"
            PS1["Public Subnet 1<br/>192.168.1.0/24"]
            PRIV1["Private Subnet 1<br/>192.168.11.0/24"]
        end
        
        subgraph "AZ: ap-northeast-2b"
            PS2["Public Subnet 2<br/>192.168.2.0/24"]
            PRIV2["Private Subnet 2<br/>192.168.12.0/24"]
        end
        
        subgraph "AZ: ap-northeast-2c"
            PS3["Public Subnet 3<br/>192.168.3.0/24"]
            PRIV3["Private Subnet 3<br/>192.168.13.0/24"]
        end
        
        IGW["Internet Gateway"]
    end
    
    INTERNET["인터넷"] --> IGW
    IGW --> PS1
    IGW --> PS2
    IGW --> PS3
    
    PS1 --> PRIV1
    PS2 --> PRIV2
    PS3 --> PRIV3
    
    style PS1 fill:#ffcccc
    style PS2 fill:#ffcccc
    style PS3 fill:#ffcccc
    style PRIV1 fill:#ccffcc
    style PRIV2 fill:#ccffcc
    style PRIV3 fill:#ccffcc
```

## EKS 클러스터 구성 요소

```mermaid
graph TB
    subgraph "EKS 클러스터: myeks"
        CONTROL["Control Plane<br/>(AWS 관리)"]
        
        subgraph "워커 노드 (Public Subnets)"
            NODE["Managed Node Group<br/>인스턴스: t3.large<br/>노드 수: 3<br/>볼륨: 30GB"]
        end
        
        subgraph "클러스터 애드온"
            A1["CoreDNS<br/>DNS 서버"]
            A2["kube-proxy<br/>네트워크 프록시"]
            A3["VPC CNI<br/>네트워크 플러그인"]
            A4["EBS CSI Driver<br/>스토리지 드라이버"]
            A5["External-DNS<br/>DNS 자동화"]
        end
        
        subgraph "Helm 배포"
            H1["AWS Load Balancer<br/>Controller<br/>ALB/NLB 생성"]
        end
        
        subgraph "Kubernetes 리소스"
            SC["StorageClass: gp3<br/>IOPS: 3000<br/>Throughput: 125 MiB/s"]
        end
    end
    
    CONTROL --> NODE
    NODE --> A1
    NODE --> A2
    NODE --> A3
    NODE --> A4
    NODE --> A5
    NODE --> H1
    A4 --> SC
    
    style CONTROL fill:#ff9999
    style NODE fill:#99ccff
    style SC fill:#ffcc99
```

## CI/CD 파이프라인

```mermaid
graph LR
    subgraph "GitHub"
        REPO["GitHub Repository<br/>june2git/eks-app"]
        ACTIONS["GitHub Actions<br/>워크플로우"]
    end
    
    subgraph "AWS"
        OIDC["GitHub OIDC<br/>Provider"]
        ROLE["IAM Role<br/>github-actions-ecr-role"]
        ECR1["ECR: demo-app"]
        ECR2["ECR: kafka-producer"]
        ECR3["ECR: kafka-consumer"]
        EKS["EKS 클러스터"]
    end
    
    REPO --> ACTIONS
    ACTIONS -->|OIDC 인증| OIDC
    OIDC --> ROLE
    ROLE -->|푸시 권한| ECR1
    ROLE -->|푸시 권한| ECR2
    ROLE -->|푸시 권한| ECR3
    ACTIONS -->|Docker 이미지 푸시| ECR1
    ACTIONS -->|Docker 이미지 푸시| ECR2
    ACTIONS -->|Docker 이미지 푸시| ECR3
    
    ECR1 -->|이미지 풀| EKS
    ECR2 -->|이미지 풀| EKS
    ECR3 -->|이미지 풀| EKS
    
    style ACTIONS fill:#ffcc99
    style ROLE fill:#ff9999
    style ECR1 fill:#99ff99
    style ECR2 fill:#99ff99
    style ECR3 fill:#99ff99
```

## IAM 역할 및 권한 (IRSA)

```mermaid
graph TB
    subgraph "EKS 클러스터"
        OIDC["OIDC Provider"]
        
        subgraph "Service Accounts"
            SA1["ebs-csi-controller-sa<br/>(kube-system)"]
            SA2["aws-load-balancer-controller<br/>(kube-system)"]
            SA3["external-dns<br/>(kube-system)"]
        end
    end
    
    subgraph "IAM 역할"
        R1["AmazonEKSTFEBSCSIRole<br/>EBS 볼륨 관리"]
        R2["AmazonEKSTFLBControllerRole<br/>ALB/NLB 관리"]
        R3["Node Group Role<br/>External-DNS 정책"]
    end
    
    subgraph "IAM 정책"
        P1["AmazonEBSCSIDriverPolicy<br/>(AWS 관리형)"]
        P2["AWSLoadBalancerControllerPolicy<br/>(커스텀)"]
        P3["ExternalDNSPolicy<br/>(커스텀)"]
    end
    
    OIDC --> R1
    OIDC --> R2
    
    SA1 -->|AssumeRole| R1
    SA2 -->|AssumeRole| R2
    SA3 -->|AssumeRole| R3
    
    R1 --> P1
    R2 --> P2
    R3 --> P3
    
    style OIDC fill:#ffcc99
    style R1 fill:#ff9999
    style R2 fill:#ff9999
    style R3 fill:#ff9999
```

## 주요 리소스 요약

### 네트워크
- **VPC**: 192.168.0.0/16
- **Public Subnets**: 3개 (각 AZ마다 1개)
- **Private Subnets**: 3개 (각 AZ마다 1개)
- **Internet Gateway**: 1개
- **NAT Gateway**: 없음 (현재 구성)

### 컴퓨팅
- **EKS 클러스터**: myeks (Kubernetes 1.32)
- **워커 노드**: t3.large × 3개 (Public Subnets)
- **Bastion Host**: t3.medium × 1개 (Public Subnet 1)

### 컨테이너
- **ECR 저장소**: demo-app, kafka-producer, kafka-consumer

### 스토리지
- **StorageClass**: gp3 (기본)
- **EBS CSI Driver**: 활성화

### 보안
- **보안 그룹**: 2개 (Bastion용, Node Group용)
- **IRSA**: 3개 역할 (EBS CSI, Load Balancer Controller, External-DNS)
- **GitHub OIDC**: ECR 푸시용 역할

### CI/CD
- **GitHub Actions**: OIDC를 통한 ECR 푸시 자동화

