# 🔐 Reusable Workflow Secrets 가이드

## ❌ 문제 원인

Reusable workflow에서 secrets을 사용하려면 **두 곳에서 설정**이 필요합니다:

1. ✅ **호출하는 워크플로우** (eks-app/.github/workflows/ci.yaml)
2. ✅ **Reusable workflow** (devops-templates/.github/workflows/build_and_push_template.yml)

**하나만 설정하면 에러 발생!**

---

## ✅ 해결 방법

### **1. Reusable Workflow에 secrets 정의 추가**

```yaml
# devops-templates/.github/workflows/build_and_push_template.yml

on:
  workflow_call:
    # ... inputs ...
    
    # ⬅️ 이 부분 추가!
    secrets:
      GITOPS_PAT:
        required: true
        description: "GitHub Personal Access Token for GitOps repository access"
```

### **2. 호출 워크플로우에서 secrets 전달**

```yaml
# eks-app/.github/workflows/ci.yaml

jobs:
  ci:
    uses: june2git/devops-templates/.github/workflows/build_and_push_template.yml@main
    
    # ⬅️ 이 부분 추가!
    secrets:
      GITOPS_PAT: ${{ secrets.GITOPS_PAT }}
    
    with:
      app_name: demo
      # ... 기타 입력들 ...
```

---

## 📋 전체 설정 체크리스트

### **확인 1: Reusable Workflow**

```yaml
# devops-templates/.github/workflows/build_and_push_template.yml
on:
  workflow_call:
    inputs:
      # ...
    secrets:
      GITOPS_PAT:
        required: true
```

### **확인 2: 호출 워크플로우**

```yaml
# eks-app/.github/workflows/ci.yaml
jobs:
  ci:
    uses: june2git/devops-templates/.github/workflows/build_and_push_template.yml@main
    secrets:
      GITOPS_PAT: ${{ secrets.GITOPS_PAT }}
```

### **확인 3: GitHub Secrets**

- [x] GITOPS_PAT가 eks-app 저장소에 설정됨 (37분 전 업데이트)

---

## 🎯 작동 원리

### **Secrets 전달 과정**

```
1. eks-app 저장소
   ├── Secrets: GITOPS_PAT
   └── workflows/ci.yaml
       └── secrets: GITOPS_PAT → 전달

2. devops-templates 저장소
   └── workflows/build_and_push_template.yml
       └── secrets: GITOPS_PAT 수신
       └── token: ${{ secrets.GITOPS_PAT }} 사용
```

---

## ⚠️ 추가 확인 사항

### **1. Secret 이름 정확히 확인**

```yaml
# eks-app 저장소의 Secret 이름
Name: GITOPS_PAT  # 대소문자 구분!

# ❌ 틀린 이름들
- gitops_pat
- Gitops_Pat
- GITOPS-PAT
```

### **2. PAT 권한 확인**

PAT가 다음 권한을 가지고 있는지 확인:

- ✅ `repo` (Full control of private repositories)

**확인 방법**:
1. https://github.com/settings/tokens
2. 생성한 토큰의 권한 확인

### **3. GitOps 저장소 접근 권한**

PAT가 gitops 저장소에 접근할 수 있는지 확인:

```bash
# 로컬에서 테스트
TOKEN="your-token"
curl -H "Authorization: token $TOKEN" https://api.github.com/repos/june2git/gitops
```

성공하면 JSON이 반환됩니다.

---

## 🚀 테스트 방법

### **1. 워크플로우 수정 후 push**

```bash
cd eks-app
git add .github/workflows/ci.yaml
git commit -m "fix: add secrets to reusable workflow"
git push origin main
```

### **2. GitHub Actions 확인**

https://github.com/june2git/eks-app/actions

**확인할 단계**:
- [ ] "Checkout GitOps Repository" 성공
- [ ] "Update GitOps Values" 성공
- [ ] "✅ GitOps repository updated successfully" 출력

### **3. GitOps 저장소 확인**

https://github.com/june2git/gitops/commits/main

자동 커밋이 생성되었는지 확인:
```
chore: update demo image to demo-main-123
```

---

## 🔍 트러블슈팅

### **에러: "Secret 'GITOPS_PAT' is not defined"**

**원인**: Reusable workflow에 secrets 정의 없음

**해결**: 
```yaml
# devops-templates/.github/workflows/build_and_push_template.yml
on:
  workflow_call:
    secrets:
      GITOPS_PAT: required: true
```

### **에러: "Token is invalid or expired"**

**해결**: 
1. 새 PAT 생성
2. eks-app에 Secret 업데이트

### **에러: "Permission to june2git/gitops.git denied"**

**원인**: PAT 권한 부족

**해결**: 
- PAT에 `repo` 권한 추가
- 또는 GitOps 저장소를 Public으로 변경

---

## ✅ 최종 확인

현재 설정 상태:

1. ✅ **PAT 생성**: 완료 (37분 전 업데이트)
2. ✅ **eks-app Secrets**: GITOPS_PAT 설정됨
3. ✅ **Reusable workflow**: secrets 정의 추가됨
4. ✅ **호출 워크플로우**: secrets 전달 추가됨
5. ✅ **values_file 경로**: `charts/values-prod.yaml` 수정됨

**이제 정상 작동할 것입니다!** ✅

