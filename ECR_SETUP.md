# ECR 저장소 설정 가이드

## 📝 변경 사항

Go 애플리케이션(Kafka Producer/Consumer)을 위한 ECR 저장소를 추가했습니다.

### 수정된 파일

1. **`var.tf`**: 단일 ECR 저장소에서 여러 저장소 관리로 변경
   - `ecr_repo` → `ecr_repos` (set 타입)
   - 기본값: `["demo-app", "kafka-producer", "kafka-consumer"]`

2. **`ecr.tf`**: `for_each`를 사용한 동적 리소스 생성
   - 단일 리소스 → 여러 저장소 자동 생성
   - 개별 output 추가 (하위 호환성)

3. **`github_oidc.tf`**: IAM 정책 업데이트
   - 모든 ECR 저장소에 대한 권한 부여

## 🚀 적용 방법

### 1. Terraform 상태 이전 (State Migration)

기존 `aws_ecr_repository.app` 리소스를 새로운 구조로 마이그레이션해야 합니다.

```bash
cd infra/

# 현재 상태 확인
terraform state list

# 기존 demo-app ECR 리소스 이동
terraform state mv \
  'aws_ecr_repository.app' \
  'aws_ecr_repository.apps["demo-app"]'
```

### 2. Terraform Plan 실행

```bash
# 변경 사항 확인
terraform plan

# 예상 결과:
# + aws_ecr_repository.apps["kafka-producer"]
# + aws_ecr_repository.apps["kafka-consumer"]
# ~ aws_iam_role_policy.github_actions_ecr_policy (in-place update)
```

### 3. Terraform Apply 실행

```bash
# 변경 사항 적용
terraform apply

# 생성된 ECR URL 확인
terraform output ecr_repository_urls
```

### 4. 출력 값 확인

```bash
# 모든 ECR 저장소 URL
terraform output ecr_repository_urls

# 개별 저장소 URL
terraform output demo_app_ecr_url
terraform output kafka_producer_ecr_url
terraform output kafka_consumer_ecr_url
```

## 📊 예상 결과

### 생성될 ECR 저장소

```
703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/demo-app
703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/kafka-producer
703671922786.dkr.ecr.ap-northeast-2.amazonaws.com/kafka-consumer
```

### IAM 정책

GitHub Actions가 모든 ECR 저장소에 접근할 수 있도록 권한이 자동으로 부여됩니다.

## 🔧 확장 방법

새로운 애플리케이션 추가 시:

```hcl
# var.tf
variable "ecr_repos" { 
  default = [
    "demo-app",
    "kafka-producer",
    "kafka-consumer",
    "new-app"  # 새 앱 추가
  ]
}
```

그 후 `terraform apply`만 실행하면 자동으로 새 ECR 저장소가 생성됩니다.

## ⚠️ 주의사항

### State Migration 필수

**반드시 Step 1의 state migration을 먼저 실행하세요!**

그렇지 않으면:
- ❌ 기존 `demo-app` ECR이 삭제될 위험
- ❌ 저장된 Docker 이미지가 사라질 수 있음

### 안전한 순서

1. ✅ `terraform state mv` (기존 리소스 이동)
2. ✅ `terraform plan` (삭제 없는지 확인)
3. ✅ `terraform apply` (새 리소스만 생성)

## 📋 체크리스트

- [ ] 백업: `terraform state pull > backup.tfstate`
- [ ] State Migration: `terraform state mv`
- [ ] Plan 확인: 삭제(`-`)가 없는지 확인
- [ ] Apply 실행
- [ ] Output 확인: 3개 ECR URL 생성 확인
- [ ] GitHub Actions 테스트: 이미지 푸시 정상 작동 확인

## 🎯 검증

```bash
# ECR 저장소 확인
aws ecr describe-repositories \
  --repository-names demo-app kafka-producer kafka-consumer \
  --region ap-northeast-2

# IAM 정책 확인
aws iam get-role-policy \
  --role-name myeks-github-actions-ecr-role \
  --policy-name myeks-github-actions-ecr-policy
```

