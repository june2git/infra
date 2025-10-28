# 🔐 GITOPS_PAT 설정 가이드

## ❌ 에러 원인

```
remote: Invalid username or token. Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/june2git/gitops.git/'
```

**원인**: `GITOPS_PAT` Secret이 설정되지 않았거나 토큰이 유효하지 않음

---

## ✅ 해결 방법

### **방법 1: Personal Access Token (PAT) 사용**

#### **1-1. GitHub에서 PAT 생성**

1. GitHub에 로그인
2. Settings → Developer settings → Personal access tokens → Tokens (classic)
3. "Generate new token" → "Generate new token (classic)" 클릭
4. 설정:
   - **Note**: `GitOps Push Token`
   - **Expiration**: 원하는 기간 선택
   - **Scopes**: 
     - ✅ `repo` (Full control of private repositories)
     - ✅ `workflow` (Update GitHub Action workflows) - 필요시
5. "Generate token" 클릭
6. **토큰 복사** (한 번만 표시됨!)

#### **1-2. eks-app 저장소에 Secret 추가**

1. **eks-app** 저장소로 이동: https://github.com/june2git/eks-app
2. Settings → Secrets and variables → Actions
3. "New repository secret" 클릭
4. 설정:
   - **Name**: `GITOPS_PAT`
   - **Secret**: 생성한 토큰 붙여넣기
5. "Add secret" 클릭

---

### **방법 2: GitHub App 사용 (더 안전, 권장) ⭐**

GitHub App을 사용하면 더 세밀한 권한 제어가 가능합니다.

#### **2-1. GitHub App 생성**

```bash
# GitHub에서
1. Settings → Developer settings → GitHub Apps
2. "New GitHub App" 클릭
3. 설정:
   - Name: gitops-updater
   - Callback URL: https://your-domain.com
   - Permissions:
     - Contents: Read and write
     - Metadata: Read-only
4. "Create GitHub App" 클릭
5. Private key 다운로드
```

#### **2-2. eks-app에 App 설정**

```yaml
# eks-app/.github/workflows/ci.yaml에 추가
- name: Generate token
  id: generate-token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.GITHUB_APP_ID }}
    private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
```

---

## 🔧 현재 권장 방법 (PAT)

### **최종 설정**

#### **eks-app 저장소 Secrets**

```
GITOPS_PAT = <Personal Access Token>
```

#### **Workflow 코드 (이미 설정됨)**

```yaml
# build_and_push_template.yml
- name: Update GitOps Repository
  env:
    GITOPS_PAT: ${{ secrets.GITOPS_PAT }}  # ← 이 Secret 필요
    GITOPS_REPO: ${{ inputs.gitops_repo }}
    VALUES_FILE: ${{ inputs.values_file }}
  run: |
    git clone https://x-access-token:${GITOPS_PAT}@github.com/${GITOPS_REPO}.git gitops
    # ...
```

---

## 📝 PAT 생성 가이드 (자세히)

### **Step 1: GitHub PAT 생성**

```
https://github.com/settings/tokens
→ "Generate new token" → "Generate new token (classic)"
```

### **Step 2: 권한 설정**

최소한의 권한:
- ✅ `repo` (Full control of private repositories)

또는 최소 권한 (더 안전):
- ✅ `public_repo` (Public repository access)
- ✅ `repo:status` (Access commit status)

### **Step 3: eks-app에 Secret 추가**

```
https://github.com/june2git/eks-app/settings/secrets/actions
→ "New repository secret"
→ Name: GITOPS_PAT
→ Value: <토큰>
```

---

## 🚀 테스트

### **워크플로우 재실행**

eks-app 코드를 약간 수정하고 push하면 자동으로 실행됩니다:

```bash
# eks-app/demo/src/main/java/com/example/demo/DemoController.java
# 간단한 수정 (주석 추가)

git add .
git commit -m "test: trigger CI/CD"
git push origin main
```

### **확인 사항**

1. GitHub Actions 실행 확인
2. "Update GitOps Repository" 단계가 성공하는지 확인
3. gitops 저장소에 커밋이 생성되었는지 확인

---

## ⚠️ 문제 해결

### **에러: "Secret not found"**

```
Error: Secret 'GITOPS_PAT' is not defined.
```

**해결**: eks-app 저장소에 `GITOPS_PAT` secret 추가

### **에러: "Permission denied"**

```
remote: Permission to june2git/gitops.git denied
```

**해결**: 
- PAT의 `repo` 권한 확인
- token이 유효한지 확인
- 새로운 토큰 생성

### **에러: "Token expired"**

```
fatal: Authentication failed
```

**해결**: 새 토큰 생성하고 Secret 업데이트

---

## 🔐 보안 모범 사례

### **PAT 사용 시**

1. ✅ 가능한 한 짧은 만료 기간 설정
2. ✅ 최소 권한만 부여
3. ✅ 조직/팀 단위로 관리
4. ✅ 정기적으로 로테이션

### **GitHub App 사용 시 (권장)**

1. ✅ 특정 저장소만 접근
2. ✅ Fine-grained 권한
3. ✅ 키 로테이션 용이
4. ✅ 감사(Audit) 로그

---

## 📋 체크리스트

배포 전 확인:

- [ ] GitHub Personal Access Token 생성
- [ ] eks-app 저장소에 `GITOPS_PAT` Secret 추가
- [ ] gitops 저장소 접근 권한 확인
- [ ] Workflow 파일 수정 완료 (build_and_push_template.yml)
- [ ] 테스트 실행

---

## 🎯 빠른 설정

### **1. PAT 생성**
```
https://github.com/settings/tokens → Generate new token
→ repo 권한 → 생성
```

### **2. eks-app에 Secret 추가**
```
https://github.com/june2git/eks-app/settings/secrets/actions
→ New repository secret
→ Name: GITOPS_PAT
→ Value: <토큰>
```

### **3. 완료!**
이제 eks-app 코드를 push하면 자동으로 GitOps가 업데이트됩니다.

