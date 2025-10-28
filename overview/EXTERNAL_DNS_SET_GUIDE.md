# 🌐 External-DNS 설정 가이드

## ✅ 현재 상태

### **기본_infra에서 External-DNS 설치 여부 확인**

현재 Terraform 설정에서 External-DNS가 설치되어 있는지 확인이 필요합니다.

---

## 📋 External-DNS란?

External-DNS는 Kubernetes Service와 Ingress 리소스를 감지하여 자동으로 DNS 레코드를 생성/삭제하는 도구입니다.

### **지원하는 DNS 제공업체**
- AWS Route53
- Google Cloud DNS
- Azure DNS
- Cloudflare
- 등등

---

## 🔍 현재 프로젝트 확인

### **External-DNS 설치 여부 확인**

```bash
# Kubernetes에 External-DNS가 설치되어 있는지 확인
kubectl get deployment -n kube-system external-dns

# 또는
kubectl get pods -A | grep external-dns
```

---

## 🚀 External-DNS 설치 (없는 경우)

### **방법 1: Terraform으로 자동 설치**

`basic_infra/helm_addons.tf`에 External-DNS를 추가:

```hcl
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "6.28.5"
  
  depends_on = [module.eks]

  values = [
    yamlencode({
      provider = "aws"
      aws = {
        region = var.TargetRegion
        zoneType = "public"
      }
      domainFilters = ["june2soul.store"]
      policy = "sync"
      txtOwnerId = "myeks"
      
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
        }
      }
    })
  ]
}
```

### **방법 2: Helm으로 수동 설치**

```bash
# Helm repository 추가
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# IAM Role 생성 (IRSA)
eksctl create iamserviceaccount \
  --name external-dns \
  --namespace kube-system \
  --cluster myeks \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess \
  --approve

# External-DNS 설치
helm install external-dns bitnami/external-dns \
  --namespace kube-system \
  --set provider=aws \
  --set aws.region=ap-northeast-2 \
  --set txtOwnerId=myeks \
  --set domainFilters[0]=june2soul.store
```

---

## 🎯 External-DNS로 자동 DNS 등록

### **Ingress에 주석 추가**

External-DNS가 자동으로 DNS를 등록하려면 Ingress에 다음과 같은 주석이 필요합니다:

```yaml
# gitops/charts/templates/ingress.yaml
metadata:
  name: {{ include "demo-app.fullname" . }}
  annotations:
    # External-DNS 관련
    external-dns.alpha.kubernetes.io/hostname: demo.june2soul.store
    # 또는 values에 추가
    {{- toYaml .Values.ingress.annotations | nindent 4 }}
```

### **Values에 주석 추가**

```yaml
# gitops/charts/values-prod.yaml
ingress:
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
    external-dns.alpha.kubernetes.io/hostname: demo.june2soul.store  # ⬅️ 추가
```

---

## 📊 자동 등록 과정

```
1. Ingress 생성 (demo.june2soul.store)
   ↓
2. External-DNS가 Ingress 감지
   ↓
3. AWS Route53 확인
   - june2soul.store 호스팅 영역 확인
   ↓
4. DNS A 레코드 자동 생성
   - demo.june2soul.store → ALB IP
   ↓
5. DNS 전파 (몇 분 소요)
   ↓
6. demo.june2soul.store 접근 가능
```

---

## 🔍 External-DNS 로그 확인

```bash
# External-DNS Pod 로그 확인
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns

# Event 확인
kubectl get events -n default --sort-by='.lastTimestamp'
```

---

## ✅ 권장 사항

### **External-DNS가 설치되어 있는 경우**

다음과 같이 Ingress에 주석을 추가하면 자동으로 DNS가 등록됩니다:

```yaml
ingress:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: demo.june2soul.store
```

### **External-DNS가 설치되어 있지 않은 경우**

수동으로 DNS 레코드를 설정해야 합니다:

```bash
# ALB 주소 확인
ALB_DNS=$(kubectl get ingress demo-app -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $ALB_DNS

# Route53에서 A 레코드 생성
aws route53 change-resource-record-sets --hosted-zone-id Z123456789 --change-batch '{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "demo.june2soul.store",
      "Type": "A",
      "AliasTarget": {
        "DNSName": "'$ALB_DNS'",
        "EvaluateTargetHealth": false,
        "HostedZoneId": "Z2ULH7S6PLK55E"
      }
    }
  }]
}'
```

---

## 🎯 현재 프로젝트에 적용

1. **External-DNS 설치 여부 확인**
   ```bash
   kubectl get deployment -A | grep external-dns
   ```

2. **설치되어 있다면** Ingress에 주석 추가
3. **설치되어 있지 않다면** 수동 DNS 설정 또는 External-DNS 설치

