# 📦 배포 구성 요약

## ✅ 현재 구성 상태

### 1️⃣ eks-app 애플리케이션 배포

**저장소**: `eks-app/demo/`  
**애플리케이션**: Spring Boot  
**포트**: 8080  
**헬스체크**: `/actuator/health`

```yaml
# eks-app/demo/build.gradle
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
}
```

---

### 2️⃣ ECR Docker Image로 배포

**ECR 저장소**: `demo-app` (ecr.tf에서 생성)  
**이미지 URL**: `703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/demo-app`

```hcl
# basic_infra/ecr.tf
resource "aws_ecr_repository" "app" {
  name = "demo-app"
}
```

**배포 설정** (values-prod.yaml):

```yaml
image:
  repository: 703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/demo-app
  tag: "demo-main-1"  # 버전 태그 (자동 업데이트됨)
  pullPolicy: IfNotPresent
```

---

### 3️⃣ demo.june2soul.store로 접근

**도메인**: `demo.june2soul.store`  
**Ingress**: AWS ALB를 통한 외부 노출

```yaml
# gitops/charts/values-prod.yaml
ingress:
  enabled: true
  className: alb
  hosts:
    - host: demo.june2soul.store
      paths:
        - path: /
          pathType: Prefix
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
```

---

## 🏗️ Helm Chart 구조

```
gitops/charts/
├── Chart.yaml              # Chart 메타데이터
├── values-prod.yaml        # 프로덕션 values (도메인, 이미지 태그)
└── templates/
    ├── _helpers.tpl        # Helper 함수
    ├── deployment.yaml     # Pod 배포
    ├── service.yaml        # ClusterIP 서비스
    └── ingress.yaml        # ALB Ingress
```

**핵심**: `values-prod.yaml`의 이미지 태그는 GitHub Actions가 자동으로 업데이트합니다.

---

## 🔄 배포 흐름

```
1. eks-app 코드 변경 (demo/ 폴더)
   ↓
2. GitHub Actions 트리거 (eks-app/.github/workflows/ci.yaml)
   ↓
3. Reusable Workflow 호출 (devops-templates)
   ↓
4. Gradle 빌드
   ↓
5. Docker 이미지 빌드 (태그: demo-main-123)
   ↓
6. ECR에 푸시
   703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/demo-app:demo-main-123
   ↓
7. GitOps 저장소 자동 업데이트 (build_and_push_template.yml)
   - charts/values-prod.yaml 수정
   - image.tag: "demo-main-123"
   - 자동 커밋 & 푸시
   ↓
8. ArgoCD 자동 감지 (GitOps 저장소 변경)
   ↓
9. Kubernetes 리소스 동기화
   - Deployment 업데이트 (새 이미지 태그)
   - Service, Ingress 유지
   - Pod 재시작
   ↓
10. AWS ALB 유지 (Ingress 유지)
    ↓
11. demo.june2soul.store 접근 가능 (새 버전)
```

---

## 📋 Kubernetes 리소스

### Deployment

```yaml
# gitops/charts/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
spec:
  replicas: 2
  containers:
  - name: app
    image: 703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/demo-app:demo-main-123
    ports:
    - containerPort: 8080
    readinessProbe:
      httpGet:
        path: /actuator/health
        port: 8080
    livenessProbe:
      httpGet:
        path: /actuator/health
        port: 8080
```

### Service

```yaml
# gitops/charts/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-app
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: demo-app
```

### Ingress

```yaml
# gitops/charts/templates/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-app
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
  - host: demo.june2soul.store
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: demo-app
            port:
              number: 80
```

---

## 🌐 접근 방법

### 1. DNS 설정 필요

`demo.june2soul.store` 도메인이 ALB를 가리키도록 DNS A 레코드를 생성해야 합니다.

```bash
# ALB 주소 확인
kubectl get ingress -n default demo-app

# AWS ALB 확인
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s`)].{Name:LoadBalancerName,DNS:DNSName}' \
  --output table
```

### 2. 접근 테스트

```bash
# 1. Pod 상태 확인
kubectl get pods -n default

# 2. Service 확인
kubectl get svc -n default

# 3. Ingress 확인
kubectl get ingress -n default

# 4. ALB DNS 확인
kubectl describe ingress demo-app -n default

# 5. 헬스체크
curl http://demo.june2soul.store/actuator/health

# 6. 애플리케이션 접근
curl http://demo.june2soul.store/
```

---

## ✅ 설정 검증

### 확인 사항

- [x] eks-app에 actuator 의존성 추가됨
- [x] Dockerfile에서 헬스체크 경로 `/actuator/health` 설정
- [x] values-prod.yaml에 ECR 이미지 URL 설정
- [x] Ingress 도메인 `demo.june2soul.store` 설정
- [x] templates/deployment.yaml에 헬스체크 `/actuator/health` 설정
- [x] ALB Ingress Controller 설정 완료
- [x] 이미지 태그 버전 기반 (demo-main-123) 설정
- [x] GitOps 자동 업데이트 로직 추가됨
- [x] Reusable Workflow에 secrets 전달 설정

### 필요 작업

- [ ] DNS A 레코드 설정 (demo.june2soul.store → ALB)
- [ ] ArgoCD Application 배포 (Bastion에서)
- [ ] 배포 상태 확인
- [ ] CI/CD 파이프라인 테스트

---

## 🚀 다음 단계

### Bastion 서버에서 실행

```bash
# 1. GitOps 저장소 클론
cd ~
git clone https://github.com/june2git/gitops.git
cd gitops

# 2. ArgoCD Application 배포
kubectl apply -f apps/demo-app.yaml

# 3. 상태 확인
kubectl get application -n argocd
kubectl get pods -n default

# 4. Ingress 확인
kubectl get ingress -n default demo-app
```

### DNS 설정

```bash
# ALB DNS 주소 확인
ALB_DNS=$(kubectl get ingress demo-app -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $ALB_DNS

# Route53 또는 도메인 제공업체에서
# demo.june2soul.store → ALB_DNS A 레코드 생성
```

---

## 📊 예상 결과

```
$ kubectl get all -n default

NAME                            READY   STATUS    RESTARTS   AGE
pod/demo-app-xxxxx              1/1     Running   0          1m
pod/demo-app-yyyyy              1/1     Running   0          1m

NAME               TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
service/demo-app   ClusterIP   10.100.x.x    <none>        80/TCP    1m

NAME                               HOSTS                     ADDRESS                                                                   AGE
ingress.networking.k8s.io/demo-app  demo.june2soul.store     k8s-default-demoa-xxxxx.ap-northeast-2.elb.amazonaws.com   1m
```

최종 접근: `http://demo.june2soul.store`

