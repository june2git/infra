# 🔄 CI/CD 구조 설명

## 📦 저장소별 역할

### 1. `eks-app` - 애플리케이션 소스 코드

**역할**: Spring Boot 애플리케이션 + CI 트리거

**CI/CD 워크플로우**: ✅ 필요
- 파일: `.github/workflows/ci.yaml`
- 작업:
  - Reusable Workflow 호출
  - secrets 전달 (GITOPS_PAT)
  - inputs 전달 (app_name, ecr_repo, gitops_repo 등)

**실제 작업은 devops-templates의 Reusable Workflow에서 수행됨**

---

### 2. `gitops` - ArgoCD 배포 설정

**역할**: Kubernetes 리소스 선언 (ArgoCD가 읽음)

**CI/CD 워크플로우**: ❌ 불필요
- 이 저장소는 "설정 파일"만 저장
- 실제 빌드나 배포는 하지 않음
- ArgoCD가 Git 변경을 감지하여 자동으로 배포

---

### 3. `devops-templates` - Reusable Workflow

**역할**: 공통 CI/CD 템플릿 (여러 앱에서 재사용)

**CI/CD 워크플로우**: ✅ 핵심
- 파일: `.github/workflows/build_and_push_template.yml`
- 실제 빌드/배포 작업을 모두 수행:
  - 코드 빌드 (Gradle/Maven/Node)
  - Docker 이미지 빌드
  - ECR에 이미지 푸시
  - **GitOps 저장소 자동 업데이트** (build_and_push_template.yml)

---

## 🔄 전체 흐름

```
┌──────────────────────────────────────────────────────┐
│ 1. eks-app 저장소 (코드 변경)                        │
│    - demo/ 폴더 코드 변경                              │
│    - GitHub Actions 트리거                           │
└────────────────┬─────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────┐
│ 2. eks-app의 ci.yaml                               │
│    - Reusable Workflow 호출                          │
│    - secrets 전달 (GITOPS_PAT)                       │
│    - inputs 전달 (app_name, ecr_repo, gitops_repo) │
└────────────────┬─────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────┐
│ 3. Reusable Workflow (devops-templates)              │
│    - eks-app 코드 checkout                           │
│    - gitops 저장소 checkout (PAT 사용)              │
│    - Gradle 빌드                                      │
│    - Docker 이미지 빌드                              │
└────────────────┬─────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────┐
│ 4. ECR에 푸시                                         │
│    - 이미지: demo-app:demo-main-123 (버전 태그)     │
└────────────────┬─────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────┐
│ 5. GitOps 저장소 자동 업데이트                       │
│    - charts/values-prod.yaml 수정                    │
│    - image.repository 업데이트                       │
│    - image.tag = "demo-main-123"                    │
│    - 자동 커밋 & 푸시                                 │
└────────────────┬─────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────┐
│ 6. ArgoCD 자동 감지 및 배포                           │
│    - GitOps Git 변경 감지                             │
│    - Kubernetes 리소스 동기화                        │
│    - Pod 재배포 (새 이미지 태그)                     │
└────────────────┬─────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────┐
│ 7. Kubernetes (EKS)                                  │
│    - Pod: demo-main-122 → demo-main-123             │
│    - Service, Ingress 유지                           │
│    - demo.june2soul.store 접근 가능                  │
└──────────────────────────────────────────────────────┘
```

---

## ❓ 왜 GitOps에 CI/CD가 불필요한가?

### **GitOps 원칙**

GitOps는 Git을 "단일 소스"로 사용합니다.

```bash
# ✅ 올바른 구조
eks-app 저장소
  ├── demo/               # 소스 코드
  └── .github/workflows/  # CI/CD 파이프라인

gitops 저장소
  └── charts/             # Kubernetes 설정 (배포만)
      ├── templates/      # K8s 리소스 템플릿
      └── values-prod.yaml # 이미지 태그 (자동 업데이트)
```

GitOps 저장소는:
- **설정 파일**만 저장
- 코드 빌드나 배포 로직은 없음
- ArgoCD가 읽어서 사용

---

## 📝 현재 프로젝트 구조

```
project/
├── infra/          # Terraform 인프라 (EKS 클러스터)
├── eks-app/              # ✅ CI 트리거
│   ├── demo/             # Spring Boot 애플리케이션
│   └── .github/workflows/ci.yaml (Reusable Workflow 호출)
├── devops-templates/     # ✅ CI/CD 핵심 (Reusable Workflow)
│   └── .github/workflows/build_and_push_template.yml
│       - 빌드 & ECR 푸시
│       - GitOps 저장소 자동 업데이트
└── gitops/               # ❌ CI/CD 없음 (선언만)
    ├── apps/demo-app.yaml (ArgoCD Application)
    └── charts/
        ├── templates/     (Deployment, Service, Ingress)
        └── values-prod.yaml (이미지 태그)
```

---

## 🎯 결론

- ✅ `eks-app/.github/workflows/ci.yaml` - CI 트리거만 담당
- ✅ `devops-templates/.github/workflows/...` - 실제 빌드/배포 작업 수행

**핵심 정리**:
- **eks-app**: 코드만 저장, CI 트리거 역할
- **devops-templates**: 실제 빌드/배포 + GitOps 자동 업데이트
- **gitops**: Kubernetes 선언만 저장, ArgoCD가 자동 배포

**GitOps는 "선언적 배포 설정"만 저장하는 저장소**이므로 CI/CD 워크플로우가 필요 없습니다.

