######################
# StorageClass Setup #
######################

# gp3 StorageClass: EBS CSI Driver를 사용하여 gp3 볼륨 프로비저닝
# Kafka 등 고성능 워크로드에 적합한 스토리지 클래스
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      # gp3를 기본 StorageClass로 설정
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  # EBS CSI Driver를 프로비저너로 사용
  storage_provisioner = "ebs.csi.aws.com"
  
  # gp3 볼륨 타입 설정
  parameters = {
    type       = "gp3"
    iops       = "3000"      # 기본 IOPS
    throughput = "125"       # 처리량 (MiB/s)
  }

  # Pod이 생성될 때까지 볼륨 바인딩을 지연 (Multi-AZ에서 Pod과 같은 AZ에 볼륨 생성)
  volume_binding_mode = "WaitForFirstConsumer"
  
  # 볼륨 확장 허용
  allow_volume_expansion = true
  
  # 클레임 삭제 시 볼륨 삭제
  reclaim_policy = "Delete"

  # EKS 클러스터와 EBS CSI Driver가 먼저 생성되어야 함
  depends_on = [
    module.eks,
    module.eks.cluster_addons
  ]
}

# gp2 StorageClass의 default 제거 (선택사항)
# 기본적으로 EKS는 gp2를 default로 생성하므로, gp3를 default로 만들기 위해 gp2의 annotation을 수정
# 필요시 주석을 해제하여 사용
# resource "kubernetes_annotations" "gp2_default_removal" {
#   api_version = "storage.k8s.io/v1"
#   kind        = "StorageClass"
#   
#   metadata {
#     name = "gp2"
#   }
#   
#   annotations = {
#     "storageclass.kubernetes.io/is-default-class" = "false"
#   }
#
#   # gp3가 먼저 생성된 후 gp2의 annotation 수정
#   depends_on = [kubernetes_storage_class_v1.gp3]
# }

