===bastion 서버 설정===

1.   # EKS 클러스터 인증 정보 업데이트
aws eks update-kubeconfig \
  --region $AWS_DEFAULT_REGION \
  --name $CLUSTER_NAME


2.  # kubens default 설정
kubens default


3. # 변수 호출 종합
echo $AWS_DEFAULT_REGION
echo $CLUSTER_NAME
echo $VPCID
echo $PublicSubnet1,$PublicSubnet2,$PublicSubnet3
echo $PrivateSubnet1,$PrivateSubnet2,$PrivateSubnet3


4. # eksctl을 통한 eks cluster 정보 확인
eksctl get cluster


5. # eksctl을 통한 노드 그룹 정보 확인
eksctl get nodegroup \
  --cluster $CLUSTER_NAME \
  --name ${CLUSTER_NAME}-node-group

6. # kubectl을 통한 노드 정보 확인
kubectl get node -owide

7. # 노드 IP 변수 선언
PublicN1=$(kubectl get node --label-columns=topology.kubernetes.io/zone --selector=topology.kubernetes.io/zone=ap-northeast-2a -o jsonpath={.items[0].status.addresses[0].address})
PublicN2=$(kubectl get node --label-columns=topology.kubernetes.io/zone --selector=topology.kubernetes.io/zone=ap-northeast-2b -o jsonpath={.items[0].status.addresses[0].address})
PublicN3=$(kubectl get node --label-columns=topology.kubernetes.io/zone --selector=topology.kubernetes.io/zone=ap-northeast-2c -o jsonpath={.items[0].status.addresses[0].address})
echo "export PublicN1=$PublicN1" >> /etc/profile
echo "export PublicN2=$PublicN2" >> /etc/profile
echo "export PublicN3=$PublicN3" >> /etc/profile
echo $PublicN1, $PublicN2, $PublicN3


8. # 노드에 ssh 접근 확인
for node in $PublicN1 $PublicN2 $PublicN3; \
  do \
  ssh -i ~/.ssh/kp_node.pem -o StrictHostKeyChecking=no ec2-user@$node hostname; \
  done


9. # 각자의 도메인 변수 선언
MyDomain=june2soul.store; echo $MyDomain
echo "export MyDomain=$MyDomain" >> /etc/profile


===helm으로 ArgoCD 설치===
1. # helm repo 추가
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

2. # CERT ARN 변수 선언
export CERT_ARN=$(aws acm list-certificates --region ap-northeast-2 --query "CertificateSummaryList[?DomainName=='*.${MyDomain}'].CertificateArn" --output text)
echo "export CERT_ARN=$CERT_ARN" >> /etc/profile; echo $CERT_ARN    

3. # ArgoCD 설치 (helm install)
kubectl create ns argocd

helm install argocd argo/argo-cd \
  --namespace argocd \
  --version 7.8.5 \
  --set global.domain="argocd.$MyDomain" \
  --set server.ingress.enabled=true \
  --set server.ingress.controller=aws \
  --set server.ingress.ingressClassName=alb \
  --set server.ingress.hostname="argocd.$MyDomain" \
  --set server.ingress.annotations."alb\.ingress\.kubernetes\.io/scheme"=internet-facing \
  --set server.ingress.annotations."alb\.ingress\.kubernetes\.io/target-type"=ip \
  --set server.ingress.annotations."alb\.ingress\.kubernetes\.io/backend-protocol"=HTTPS \
  --set server.ingress.annotations."alb\.ingress\.kubernetes\.io/listen-ports"="[{\"HTTP\":80}\,{\"HTTPS\":443}]" \
  --set server.ingress.annotations."alb\.ingress\.kubernetes\.io/certificate-arn"="$CERT_ARN" \
  --set server.ingress.annotations."alb\.ingress\.kubernetes\.io/ssl-redirect"=443 \
  --set server.aws.serviceType=ClusterIP \
  --set server.aws.backendProtocolVersion=GRPC \
  --set dex.enabled=false \
  --set notifications.enabled=false


4. kubectl get all -n argocd

5. # elb 생성 확인 (Ctrl + Z로 중지)
while true; do \
    aws elbv2 describe-load-balancers \
        --query 'LoadBalancers[*].[LoadBalancerName,State.Code]' \
        --output table; \
done

6. # admin의 초기 암호 출력 (복사)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

===ArgoCD CLI 설치===
1. # ArgoCD CLI 설치
ARGO_VER=2.14.2
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v${ARGO_VER}/argocd-linux-amd64
install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

2. # ArgoCD 버전 확인
argocd version

3. # ArgoCD CLI 로그인
argocd login argocd.${MyDomain}

4. # ArgoCD 클러스터 정보 확인
argocd cluster list

5. # ArgoCD에 애플리케이션 리스트 확인
argocd app list

6. # ArgoCD에 연결된 Repository 리스트 확인
argocd repo list


===ArgoCD에 Repository 연결===
1. # ArgoCD에 Repository 추가
argocd repo add https://github.com/june2git/gitops.git \
--username june2git \
--password <PAT> \
--name gitops

2. # ArgoCD에 연결된 Repository 리스트 확인
argocd repo list


===ArgoCD에 애플리케이션 추가===
1. # ArgoCD ConfigMap 확인
kubectl get cm argocd-cm -n argocd -o yaml | yh


2. # ArgoCD app 생성 (방법 1: kubectl apply - 권장)
cd ~/gitops
kubectl apply -f apps/demo-app.yaml

# 또는 방법 2: ArgoCD CLI 사용
# argocd app create demo-app-prod \
#   --repo https://github.com/june2git/gitops.git \
#   --path charts \
#   --dest-server https://kubernetes.default.svc \
#   --dest-namespace default \
#   --sync-policy automated \
#   --self-heal \
#   --auto-prune

3. # default 네임스페이스 파드 확인
kubectl get pod,deploy,svc

4. # ArgoCD app 리스트 확인
argocd app list

5. # ArgoCD 클러스터 리스트 확인
argocd cluster list

6. # ArgoCD app 확인
argocd app get demo-app-prod


7. #  Ingress LoadBalancer 주소 확인
DEMOAPP_LB=$(kubectl get ingress demo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ ! -z "$DEMOAPP_LB" ]; then
  echo "export DEMOAPP_LB=$DEMOAPP_LB" >> /etc/profile
  echo "Demo App LoadBalancer: $DEMOAPP_LB"
else
  echo "⚠️  Ingress가 아직 생성되지 않았습니다. 잠시 후 다시 확인하세요."
  kubectl get ingress
fi

8. #  demo-app 접속 테스트
if [ ! -z "$DEMOAPP_LB" ]; then
  curl http://$DEMOAPP_LB/actuator/health
fi

9. #  애플리케이션 모니터링
kubectl get pods -n default -w
