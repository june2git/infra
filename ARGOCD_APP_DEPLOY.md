# 🚀 ArgoCD Application 배포 가이드

## 📋 프로젝트 정보

- **저장소**: https://github.com/june2git/gitops.git
- **Chart 경로**: `charts`
- **Values 파일**: `values-prod.yaml`
- **Namespace**: `default`
- **App 이름**: `demo-app-prod`

---

## 🎯 방법 1: kubectl apply (권장) ⭐

### **설정 확인**

현재 `gitops/apps/demo-app.yaml` 파일이 이미 올바르게 설정되어 있습니다:

```yaml
cat > demo-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/june2git/gitops.git
    targetRevision: main
    path: charts
    helm:
      valueFiles:
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

### **배포 명령**

```bash
# Bastion Host에서
cd ~
git clone https://github.com/june2git/gitops.git
cd gitops

# ArgoCD Application 생성
kubectl apply -f apps/demo-app.yaml

# 상태 확인
kubectl get application -n argocd
kubectl describe application demo-app-prod -n argocd
```

---

## 🎯 방법 2: ArgoCD CLI 사용 (대안)

### **GitOps 저장소 ArgoCD에 추가**

```bash
# ArgoCD에 저장소 추가
argocd repo add https://github.com/june2git/gitops.git \
  --name gitops \
  --type git

# 저장소 확인
argocd repo list
```

### **Application 생성**

```bash
# ArgoCD CLI로 Application 생성
argocd app create demo-app \
  --repo https://github.com/june2git/gitops.git \
  --path charts \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --project default \
  --sync-policy automated \
  --self-heal \
  --auto-prune

# State 확인
argocd app list
argocd app get demo-app
```

**⚠️ 주의**: ArgoCD CLI를 사용할 경우 앱 이름이 `demo-app`이 되고, 기존 YAML의 `demo-app-prod`와 다릅니다.

---

## 🔧 설정 비교

### **현재 프로젝트 설정**

| 설정 | 값 | 설명 |
|------|-----|------|
| **repoURL** | `https://github.com/june2git/gitops.git` | GitOps 저장소 |
| **targetRevision** | `main` | 브랜치 |
| **path** | `charts` | Helm Chart 디렉토리 |
| **valueFiles** | `values-prod.yaml` | Helm values 파일 |
| **destination.namespace** | `default` | 배포 네임스페이스 |

### **setting_on_bastion.md의 설정 (수정 필요)**

```bash
# ❌ 잘못된 설정 (현재 setting_on_bastion.md)
argocd app create demo-app \
  --repo https://github.com/june2git/gitops.git \
  --path manifests \  # ❌ 실제는 'charts'
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated

# ✅ 올바른 설정 (프로젝트에 맞게 수정)
argocd app create demo-app \
  --repo https://github.com/june2git/gitops.git \
  --path charts \  # ✅ Helm Chart 경로
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated \
  --helm-set 'image.repository=703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/demo-app' \
  --helm-set 'image.tag=latest'
```

---

## 🚀 배포 후 확인

### **1. ArgoCD Application 상태**

```bash
# kubectl로 확인
kubectl get application -n argocd
kubectl describe application demo-app-prod -n argocd

# ArgoCD CLI로 확인
argocd app list
argocd app get demo-app-prod
argocd app logs demo-app-prod
```

### **2. Kubernetes 리소스 확인**

```bash
# Pod 확인
kubectl get pods -n default

# Service 확인
kubectl get svc -n default

# Ingress 확인
kubectl get ingress -n default

# 전체 리소스 확인
kubectl get all -n default
```

### **3. ArgoCD Sync 상태**

```bash
# Application 동기화 확인
argocd app sync demo-app-prod

# Sync 상태 확인
argocd app get demo-app-prod

# Sync 이력
argocd app history demo-app-prod
```

---

## 🔄 동작 흐름

1. **GitOps 저장소에 Application 정의**
   - `gitops/apps/demo-app.yaml` 적용

2. **ArgoCD가 GitOps 저장소 모니터링**
   - `gitops/charts/` 디렉토리의 Helm Chart 사용
   - `gitops/values-prod.yaml` 파일로 값 주입

3. **Kubernetes 리소스 생성**
   - Deployment 생성
   - Service 생성
   - Ingress 생성 (ALB)

4. **자동 동기화**
   - GitOps 저장소 변경 시 자동 감지
   - 자동으로 Kubernetes 리소스 업데이트

---

## 📝 setting_on_bastion.md 수정 제안

```bash
# ❌ 기존 (140-145번 라인)
argocd app create demo-app \
  --repo https://github.com/june2git/gitops.git \
  --path manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated

# ✅ 수정 제안
# 방법 1: kubectl apply 사용 (권장)
kubectl apply -f apps/demo-app.yaml

# 방법 2: ArgoCD CLI 사용
argocd app create demo-app-prod \
  --repo https://github.com/june2git/gitops.git \
  --path charts \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated \
  --self-heal \
  --auto-prune \
  --revision main
```

---

## 🎯 권장사항

✅ **권장**: 방법 1 (kubectl apply)
- GitOps 원칙 준수 (Git이 소스)
- 설정 파일이 버전 관리됨
- 동일한 설정 반복 배포 가능

⚠️ **대안**: 방법 2 (ArgoCD CLI)
- CLI로 빠르게 생성 가능
- 하지만 설정이 Git에 관리되지 않음

---

## 💡 추가 명령어

### **Repository 추가**

```bash
# Public 저장소 (인증 불필요)
argocd repo add https://github.com/june2git/gitops.git --type git

# Private 저장소 (인증 필요)
argocd repo add https://github.com/june2git/gitops.git \
  --username june2git \
  --password <PAT>
```

### **Application 동기화**

```bash
# 수동 동기화
argocd app sync demo-app-prod

# 강제 동기화
argocd app sync demo-app-prod --force

# 동기화 이력 확인
argocd app history demo-app-prod

# 롤백
argocd app rollback demo-app-prod <HISTORY_ID>
```

### **Application 삭제**

```bash
# ArgoCD에서 Application 삭제 (Kubernetes 리소스는 유지)
argocd app delete demo-app-prod

# Application과 리소스 모두 삭제
argocd app delete demo-app-prod --cascade
```

---

## 🔍 트러블슈팅

### **에러: "Repository not found"**

```bash
# Repository 추가 확인
argocd repo list

# Repository 추가
argocd repo add https://github.com/june2git/gitops.git
```

### **에러: "Application OutOfSync"**

```bash
# 동기화 실행
argocd app sync demo-app-prod

# 상세 정보 확인
argocd app get demo-app-prod
```

### **에러: "ImagePullBackOff"**

```bash
# ECR 이미지 확인
aws ecr describe-images \
  --repository-name demo-app \
  --region ap-northeast-2

# Pod 로그 확인
kubectl describe pod -n default -l app=demo-app
```

