# 🏷️ 이미지 태그 버저닝으로 변경

## ✅ 변경 사항

### **이미지 태그 형식**

#### **변경 전 (latest 고정)**
```yaml
IMAGE_TAG: "latest"
# 결과: 703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/demo-app:latest
```

#### **변경 후 (버전 기반)**
```yaml
IMAGE_TAG: ${{ inputs.app_name }}-${{ github.ref_name }}-${{ github.run_number }}
# 결과: demo-main-123
```

### **태그 예시**

| 브랜치 | run_number | 결과 태그 |
|--------|-----------|-----------|
| main | 1 | `demo-main-1` |
| main | 50 | `demo-main-50` |
| feature | 10 | `demo-feature-10` |
| develop | 25 | `demo-develop-25` |

---

## 📦 이미지 구성

### **ECR 저장소**
```
Repository: demo-app
Images:
  - 703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/demo-app:demo-main-1
  - 703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/demo-app:demo-main-2
  - 703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/demo-app:demo-main-3
  ...
```

---

## 🔄 배포 흐름

```
1. eks-app 코드 변경 (demo/ 폴더)
   ↓
2. GitHub Actions 트리거 (eks-app/.github/workflows/ci.yaml)
   ↓
3. Reusable Workflow 호출 (devops-templates)
   ↓
4. Checkout Source Code & GitOps Repository
   - eks-app 코드 checkout
   - gitops 저장소 checkout (PAT 사용)
   ↓
5. Gradle 빌드
   ↓
6. Docker 이미지 빌드 & ECR 푸시
   - 태그: demo-main-123 (버전 기반)
   ↓
7. Install yq (Helm YAML 편집 도구)
   ↓
8. GitOps 저장소 자동 업데이트
   - charts/values-prod.yaml
   - image.repository 업데이트
   - image.tag: "demo-main-123"
   - git commit & push
   ↓
9. ArgoCD 감지 (GitOps Git 변경)
   ↓
10. Kubernetes Pod 재시작
    - 이전 이미지: demo-main-122
    - 새 이미지: demo-main-123
```

---

## ✅ 설정 변경 요약

### **build_and_push_template.yml**

```yaml
# 변경 전
IMAGE_TAG: "latest"

# 변경 후
IMAGE_TAG: ${{ inputs.app_name }}-${{ github.ref_name }}-${{ github.run_number }}
```

### **values-prod.yaml**

```yaml
# 변경 전
image:
  tag: "latest"
  pullPolicy: Always

# 변경 후
image:
  tag: "demo-main-1"  # 초기값 (자동 업데이트됨)
  pullPolicy: IfNotPresent
```

---

## 🎯 버전 관리 장점

### **1. 버전 추적 가능**
```bash
# ECR에서 이미지 확인
aws ecr describe-images \
  --repository-name demo-app \
  --region ap-northeast-2 \
  --query 'imageDetails[*].[imageTags[0],imagePushedAt]' \
  --output table
```

**출력 예시**:
```
IMAGE_TAG                 IMAGE_PUSHED_AT
demo-main-123            2025-01-28T12:34:56
demo-main-122            2025-01-28T11:23:45
demo-main-121            2025-01-28T10:12:34
```

### **2. 특정 버전 롤백 가능**

```bash
# 이전 버전으로 롤백
kubectl set image deployment/demo-app \
  app=703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/demo-app:demo-main-121
```

### **3. 병렬 배포 가능**

```yaml
# Feature 브랜치 테스트
deployment: demo-feature-10

# Production 배포
deployment: demo-main-123
```

---

## 📊 배포 시나리오

### **시나리오 1: 정상 배포**

```
1. 코드 변경 → main에 push
2. GitHub Actions 실행
3. 이미지 빌드: demo-main-123
4. ECR 푸시: ✅
5. GitOps 업데이트: charts/values-prod.yaml
   image.tag: "demo-main-123"
6. ArgoCD 동기화: ✅
7. Pod 재시작: demo-main-122 → demo-main-123
```

### **시나리오 2: 문제 발생 시 롤백**

```bash
# Pod 로그 확인
kubectl logs -n default -l app=demo-app

# 문제 발견: demo-main-123에 버그
# 이전 버전으로 롤백
kubectl patch deployment demo-app -n default --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", \
       "value": "703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/demo-app:demo-main-122"}]'
```

### **시나리오 3: Feature 브랜치 테스트**

```
1. feature 브랜치에 코드 푸시
2. GitHub Actions 실행
3. 이미지: demo-feature-10
4. ECR 푸시: ✅
5. 별도 테스트 환경에 배포
   - ArgoCD Application (feature)
   - GitOps: values-feature.yaml
   - image.tag: "demo-feature-10"
```

---

## 🔧 GitOps 업데이트 로직

### **자동 업데이트 스크립트**

GitHub Actions에서 다음과 같이 자동 업데이트됩니다:

```bash
cd gitops
yq -i '.image.repository = env(IMAGE_REPO)' "$VALUES_FILE"
yq -i '.image.tag = env(IMAGE_TAG)' "$VALUES_FILE"
git add ${VALUES_FILE}
git commit -m "chore: update demo image to ${IMAGE_TAG}"
git push
```

**결과**:
```yaml
# charts/values-prod.yaml
image:
  repository: 703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/demo-app
  tag: "demo-main-123"  # ← 자동 업데이트
```

**주요 변경**:
- `yq -i` 명령어는 환경변수를 `env(변수명)` 형식으로 참조
- `gitops/` 경로에서 직접 실행
- `actions/checkout`으로 gitops 저장소를 먼저 가져옴

---

## 📝 Kubernetes Deployment

### **Deployment 매니페스트 (렌더링 결과)**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: 703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/demo-app:demo-main-123
        imagePullPolicy: IfNotPresent
        # ...
```

---

## ✅ 완료 상태

| 항목 | 상태 | 설명 |
|------|------|------|
| **이미지 태그** | ✅ 변경됨 | 버전 기반 (demo-main-123) |
| **pullPolicy** | ✅ 변경됨 | IfNotPresent (버전 태그 사용 시 안전) |
| **GitOps 업데이트** | ✅ 자동 | GitHub Actions가 자동 처리 |
| **ArgoCD 배포** | ✅ 자동 | Git 변경 시 자동 동기화 |

---

## 🎯 다음 단계

### **배포 테스트**

1. **eks-app 코드 변경**
   ```bash
   # 간단한 변경으로 CI 트리거
   echo "// Test build" >> demo/src/main/java/com/example/demo/DemoController.java
   git add .
   git commit -m "test: trigger CI/CD"
   git push origin main
   ```

2. **GitHub Actions 실행 확인**
   - https://github.com/june2git/eks-app/actions
   - 모든 단계가 성공하는지 확인

3. **ECR에 이미지 푸시 확인**
   ```bash
   aws ecr describe-images \
     --repository-name demo-app \
     --region ap-northeast-2 \
     --query 'imageDetails[*].[imageTags[0],imagePushedAt]' \
     --output table
   ```

4. **GitOps 저장소 업데이트 확인**
   - https://github.com/june2git/gitops/commits/main
   - 자동 커밋 생성 확인

5. **ArgoCD 동기화 확인**
   ```bash
   kubectl get application demo-app-prod -n argocd
   ```

6. **Pod 재시작 및 배포 확인**
   ```bash
   kubectl get pods -n default -w
   kubectl describe pod -n default -l app=demo-app
   ```

**완전 자동 배포 구성 완료!** ✅

---

## 📋 현재 프로젝트 상태

### **실제 사용 중인 태그**
현재 GitOps values 파일에 있는 태그: `demo-main-41`

이는 이미 CI/CD가 성공적으로 실행되어 자동 업데이트된 것입니다!

### **검증**
```bash
# ECR 이미지 확인
aws ecr list-images --repository-name demo-app --region ap-northeast-2

# GitOps 저장소 확인
cd /Users/june2soul/study/project/gitops
git log --oneline -5 charts/values-prod.yaml
```

