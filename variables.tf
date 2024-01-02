/* Infra Configuration Settings */
variable "enable_infra_configuration" {
  description = "인프라 구성 활성화"
  type = bool
  default = false
}
// iSCSI
variable "iscsi_server_ip_address" {
  description = "iSCSI 서버 IP 주소"
  default = ""
}
variable "iscsi_server_ssh_root_password" {
  description = "iSCSI 서버 SSH 접속시 사용할 root 계정 비빌번호"
  type = string
  sensitive = true
  default = ""
}
variable "iscsi_os_volume_target_name_controller_node" {
  description = "Controller 노드의 iSCSI OS 볼륨 타겟 이름"
  default = "iqn.openstack-controller_terraform.target"
}
variable "iscsi_os_volume_target_name_compute1_node" {
  description = "Compute 1 노드의 iSCSI OS 볼륨 타겟 이름"
  default = "iqn.openstack-compute1_terraform.target"
}
variable "iscsi_os_volume_target_name_compute2_node" {
  description = "Compute 2 노드의 iSCSI OS 볼륨 타겟 이름"
  default = "iqn.openstack-compute2_terraform.target"
}
variable "iscsi_os_volume_snapshot_name_controller_node" {
  description = "Controller 노드의 iSCSI OS 볼륨 스냅샷 이름"
  default = ""
}
variable "iscsi_os_volume_snapshot_name_compute_node" {
  description = "Compute 노드의 iSCSI OS 볼륨 스냅샷 이름"
  default = ""
}
variable "iscsi_os_volume_clone_name_controller_node" {
  description = "Controller 노드의 iSCSI OS 볼륨 클론 이름"
  default = ""
}
variable "iscsi_os_volume_clone_name_compute1_node" {
  description = "Compute 1 노드의 iSCSI OS 볼륨 클론 이름"
  default = ""
}
variable "iscsi_os_volume_clone_name_compute2_node" {
  description = "Compute 2 노드의 iSCSI OS 볼륨 클론 이름"
  default = ""
}
variable "iscsi_os_volume_size_controller_node" {
  description = "Controller 노드의 iSCSI OS 볼륨 사이즈"
  default = ""
}
variable "iscsi_os_volume_size_compute_node" {
  description = "Compute 노드의 iSCSI OS 볼륨 사이즈"
  default = ""
}
variable "iscsi_os_volume_root_uuid_controller_node" {
  description = "Controller 노드의 iSCSI OS 볼륨 root 파티션 UUID"
  default = ""
}
variable "iscsi_os_volume_root_uuid_compute_node" {
  description = "Compute 노드의 iSCSI OS 볼륨 root 파티션 UUID"
  default = ""
}
// DHCP
variable "dhcp_server_ip_address" {
  description = "DHCP 서버 IP 주소"
  default = ""
}
variable "dhcp_server_ssh_root_password" {
  description = "DHCP 서버 SSH 접속시 사용할 root 계정 비빌번호"
  type = string
  sensitive = true
  default = ""
}
variable "dhcp_tftp_server_ip_address" {
  description = "DHCP 서버 설정파일에 작성될 TFTP 서버 주소"
  default = ""
}
variable "dhcp_tftp_server_ssh_root_password" {
  description = "TFTP 서버 접속시 사용할 root 계정 비빌번호"
  type = string
  sensitive = true
  default = ""
}
variable "dhcp_tftp_server_exported_folder_location" {
  description = "TFTP 서버에서 공유된 폴더 경로"
  default = ""
}
variable "dhcp_pxe_target_folder_name" {
  description = "PXE 타겟 폴더명"
  default = "openstack_auto_install_terraform"
}
variable "dhcp_nodes_internal_gateway_ip_address" {
  description = "DHCP 서버 설정파일에 작성될 내부 게이트웨이 IP 주소"
  default = ""
}
variable "dhcp_mac_address_controller_node" {
  description = "DHCP 서버 설정파일에 작성될 Controller 노드의 MAC 주소"
  default = ""
}
variable "dhcp_mac_address_compute1_node" {
  description = "DHCP 서버 설정파일에 작성될 Compute 1 노드의 MAC 주소"
  default = ""
}
variable "dhcp_mac_address_compute2_node" {
  description = "DHCP 서버 설정파일에 작성될 Compute 2 노드의 MAC 주소"
  default = ""
}
variable "ipmi_ip_address_controller_node" {
  description = "Controller 노드 IPMI IP 주소"
  default = ""
}
variable "ipmi_user_name_controller_node" {
  description = "Controller 노드 IPMI 사용자 이름"
  default = ""
}
variable "ipmi_user_password_controller_node" {
  description = "Controller 노드 IPMI 사용자 암호"
  type = string
  sensitive = true
  default = ""
}
variable "ipmi_ip_address_compute1_node" {
  description = "Compute 1 노드 IPMI IP 주소"
  default = ""
}
variable "ipmi_user_name_compute1_node" {
  description = "Compute 1 노드 IPMI 사용자 이름"
  default = ""
}
variable "ipmi_user_password_compute1_node" {
  description = "Compute 1 노드 IPMI 사용자 암호"
  type = string
  sensitive = true
  default = ""
}
variable "ipmi_ip_address_compute2_node" {
  description = "Compute 2 노드 IPMI IP 주소"
  default = ""
}
variable "ipmi_user_name_compute2_node" {
  description = "Compute 2 노드 IPMI 사용자 이름"
  default = ""
}
variable "ipmi_user_password_compute2_node" {
  description = "Compute 2 노드 IPMI 사용자 암호"
  type = string
  sensitive = true
  default = ""
}

/* Node Settings */
variable "openstack_nodes_ssh_root_password" {
  description = "노드 SSH 접속시 사용할 root 계정 비빌번호"
  type = string
  sensitive = true
}
// controller
variable "controller_node_hostname" {
  description = "Controller 노드 호스트명"
  default = "controller"
}
variable "controller_node_internal_ip_address" {
  description = "Controller 노드 내부 인터페이스 IP 주소"
}
variable "controller_node_internal_ip_address_prefix_length" {
  description = "Controller 노드 내부 인터페이스 IP 주소 서브넷 마스크 Prefix"
}
variable "controller_node_internal_interface" {
  description = "Controller 노드 내부 인터페이스명"
}
variable "controller_node_external_ip_address" {
  description = "Controller 노드 외부 인터페이스 IP 주소"
}
variable "controller_node_external_ip_address_prefix_length" {
  description = "Controller 노드 외부 인터페이스 IP 주소 서브넷 마스크 Prefix"
}
variable "controller_node_external_interface" {
  description = "Controller 노드 외부 인터페이스명"
}
// compute 1
variable "compute1_node_hostname" {
  description = "Compute 1 노드 호스트명"
  default = "compute-node"
}
variable "compute1_node_internal_ip_address" {
  description = "Compute 1 노드 내부 인터페이스 IP 주소"
}
variable "compute1_node_internal_ip_address_prefix_length" {
  description = "Compute 1 노드 내부 인터페이스 IP 주소 서브넷 마스크 Prefix"
}
variable "compute1_node_internal_interface" {
  description = "Compute 1 노드 내부 인터페이스명"
}
variable "compute1_node_external_ip_address" {
  description = "Compute 1 노드 외부 인터페이스 IP 주소"
}
variable "compute1_node_external_ip_address_prefix_length" {
  description = "Compute 1 노드 외부 인터페이스 IP 주소 서브넷 마스크 Prefix"
}
variable "compute1_node_external_interface" {
  description = "Compute 1 노드 외부 인터페이스명"
}
// compute 2
variable "compute2_node_hostname" {
  description = "Compute 2 노드 호스트명"
  default = "compute-node"
}
variable "compute2_node_internal_ip_address" {
  description = "Compute 2 노드 내부 인터페이스 IP 주소"
}
variable "compute2_node_internal_ip_address_prefix_length" {
  description = "Compute 2 노드 내부 인터페이스 IP 주소 서브넷 마스크 Prefix"
}
variable "compute2_node_internal_interface" {
  description = "Compute 2 노드 내부 인터페이스명"
}
variable "compute2_node_external_ip_address" {
  description = "Compute 2 노드 외부 인터페이스 IP 주소"
}
variable "compute2_node_external_ip_address_prefix_length" {
  description = "Compute 2 노드 외부 인터페이스 IP 주소 서브넷 마스크 Prefix"
}
variable "compute2_node_external_interface" {
  description = "Compute 2 노드 외부 인터페이스명"
}

/* OpenStack Settings */
variable "openstack_keystone_admin_password" {
  description = "OpenStack Keystone 관리자 비밀번호"
  default = "openstack"
  type = string
  sensitive = true
}
variable "openstack_octavia_ca_password" {
  description = "OpenStack Octavia CA 비밀번호"
  default = "openstack"
  type = string
  sensitive = true
}
variable "openstack_octavia_client_ca_password" {
  description = "OpenStack Octavia 클라이언트 CA 비밀번호"
  default = "openstack"
  type = string
  sensitive = true
}
variable "openstack_octavia_keystone_password" {
  description = "OpenStack Octavia Keystone 비밀번호"
  default = "openstack"
  type = string
  sensitive = true
}
variable "openstack_databases_password" {
  description = "OpenStack Octavia Keystone 비밀번호"
  default = "openstack"
  type = string
  sensitive = true
}
variable "openstack_vip_internal" {
  description = "OpenStack 내부 Virtual IP"
}
variable "openstack_vip_external" {
  description = "OpenStack 외부 Virtual IP"
}
variable "openstack_external_subnet_range" {
  description = "OpenStack 외부 서브넷 범위"
}
variable "openstack_external_subnet_pool_start_ip_address" {
  description = "OpenStack 외부 서브넷 풀 시작 IP 주소"
}
variable "openstack_external_subnet_pool_end_ip_address" {
  description = "OpenStack 외부 서브넷 풀 마지막 IP 주소"
}
variable "openstack_external_subnet_pool_gateway" {
  description = "OpenStack 외부 서브넷 풀 게이트웨이 IP 주소"
}
variable "openstack_internal_subnet_range" {
  description = "OpenStack 내부 서브넷 범위"
}
variable "openstack_internal_subnet_gateway" {
  description = "OpenStack 내부 서브넷 게이트웨이"
}
variable "openstack_router_enable_snat" {
  description = "OpenStack 라우터 SNAT 사용 여부"
  type = bool
  default = false
}
variable "openstack_create_cirros_test_image" {
  description = "OpenStack CirrOS 테스트 이미지 생성"
  type = bool
  default = true
}
variable "openstack_cirros_test_image_version" {
  description = "OpenStack CirrOS 테스트 이미지 버전"
  default = "0.6.1"
  type = string
}

# OpenStack NFS configuration
variable "openstack_cinder_volumes_nfs_target" {
  description = "OpenStack Cinder 볼륨 NFS 타켓"
}
variable "openstack_glance_images_nfs_target" {
  description = "OpenStack Glance 이미지 NFS 타켓"
}
variable "openstack_nova_compute_instances_nfs_target" {
  description = "OpenStack Nova Compute 인스턴스 NFS 타켓"
}

