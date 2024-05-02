# Terraform 기반 OpenStack 자동 설치 스크립트 이용 가이드

## 1. 요구 사항

- 필요 노드 3대 (Controller 노드, Compute 노드, Storage 노드)
- 인프라 자동 구성 기능 사용시 다음과 같은 사항들을 추가로 필요로 함
    - OpenStack을 구성하는 Controller 노드와 Compute 노드에서 IPMI 지원
    - isc-dhcp-server 패키지를 이용하는 DHCP 서버
    - TFTP 서버
    - FreeBSD 를 사용하며, ZFS 파일시스템과 ctld 로 구성된 iSCSI 서버
- Controller 노드 요구 사항
    - CPU: 4Core 이상
    - RAM: 8GB 이상
    - Disk: 10GB 이상
    - NIC 2개
        - External: 외부 통신용 1개
        - Internal: 내부 통신용 1개
    - OS: Ubuntu 20.04 LTS
    - Kernel: 4.15+, IPv6 Enabled
    - Python 3.6.x~3.7.x
    - SSH Server Installed
- Compute 노드 요구 사항
    - CPU: 솔루션 설치를 위해 16Core 이상 권장, 가상화 활성화
    - RAM: 솔루션 설치를 위해 32GB 이상 권장
    - Disk:  10GB 이상
    - NIC 2개
        - External: 외부 통신용 1개
        - Internal: 내부 통신용 1개
    - OS: Ubuntu 20.04 LTS
    - Kernel: 4.15+, IPv6 Enable, KVM Enabled
    - Python 3.6.x~3.7.x
    - SSH Server Installed
- Storage 노드 요구 사항
    - NFS 서버 활성화
    - Disk: 1TB 이상 권장
    - NIC 1개
        - Internal: 내부 통신용 1개

## 2. 사전 필요 설정 사항

- Controller 노드
    - NIC
        - External
            - 외부 인터넷과 통신 가능하도록 IP, Gateway, 네임서버를 설정합니다.
            - Compute 노드와 같은 네트워크에 속하도록 구성합니다.
        - Internal
            - Compute 노드, Storage 노드와 통신 가능하도록 IP를 설정합니다.
    - SSH 서버 설치 및 root 계정 패스워드 로그인 활성화 (Compute 노드와 동일한 패스워드 설정)
- Compute  노드
    - NIC
        - External
            - 외부 인터넷과 통신 가능하도록 IP, Gateway, 네임서버를 설정합니다.
            - Controller 노드와 같은 네트워크에 속하도록 구성합니다.
        - Internal
            - Controller 노드, Storage 노드와 통신 가능하도록 IP를 설정합니다.
    - SSH 서버 설치 및 root 계정 패스워드 로그인 활성화 (Controller 노드와 동일한 패스워드 설정)
- Storage 노드
    - NIC
        - Internal
            - Controller 노드, Compute 노드와 통신 가능하도록 IP를 설정합니다.
    - NFS 서버 설치 및 Controller 노드와 Compute 노드의 External, Internal IP들 허용가능도록 /etc/exports 파일을 설정합니다.
    - /etc/exports 파일에 다음 3개의 폴더에 대해 exports 필요
        - 각 폴더의 exports 옵션 설정
            
            (rw,nohide,sync,no_subtree_check,insecure,no_root_squash)
            
        - cinder
            - 필요 권한 UID, GID: 42407
        - glance
            - 필요 권한 UID, GID: 42415
        - nova-compute
            - 필요 권한 UID, GID: 42436
        - 폴더 권한 예시
            
            ```bash
            # ls -aln
            total 20
            drwxr-xr-x  5     0     0 4096 Feb  2 11:00 .
            drwxr-xr-x 25     0     0 4096 Feb  2 10:59 ..
            drwxr-xr-x  2 42407 42407 4096 Feb  3 11:10 cinder
            drwxr-xr-x  2 42415 42415 4096 Feb  2 13:06 images
            drwxr-xr-x  5 42436 42436 4096 Feb  3 11:11 instances
            ```
            
        - /etc/exports 예시
            
            ```bash
            # Openstack
            /Storage/openstack/cinder 172.29.0.0/255.255.255.0(rw,nohide,sync,no_subtree_check,insecure,no_root_squash)
            /Storage/openstack/images 172.29.0.0/255.255.255.0(rw,nohide,sync,no_subtree_check,insecure,no_root_squash)
            /Storage/openstack/instances 172.29.0.0/255.255.255.0(rw,nohide,sync,no_subtree_check,insecure,no_root_squash)
            ```
            
- 인프라 자동 구성 기능 사용시 사전 필요 사항
    - 네트워크 구성
        1. Terraform 스크립트를 실행하고자 하는 호스트에서 Controller 노드와 Compute 노드의 Internal IP 주소를 통해 SSH 접근이 가능하여야 합니다.
        2. Terraform 스크립트를 실행하고자 하는 호스트에서 Controller 노드와 Compute 노드의 IPMI IP 주소들로 접근이 가능하여야 합니다.
        3. Controller 노드와 Compute 노드의 Internal Interface의 MAC 주소를 각각 사전에 알고 있어야 합니다.
        4. Controller 노드와 Compute 노드는 Internal Interface를 통해 DHCP 서버, TFTP 서버, iSCSI 서버에 접근 가능하여야 합니다.
    - Controller 노드와 Compute 노드에서의 IPMI 설정
        1. 각 노드에서 BIOS에 진입하여 IPMI 사용자를 추가해 줍니다. BIOS 진입 방법 및 IPMI 사용자 추가 방법은 서버 모델에 따라 다르기 때문에 각 서버별 메뉴얼을 참고하시기 바랍니다.
        2. Ubuntu Live OS로 부팅하여 ipmitool 패키지를 설치합니다.
        
        ```bash
        sudo apt install -y ipmitool
        ```
        
        1. IPMI lan channel 번호를 지정하여 MD5, PASSWORD 방식의 사용자 로그인을 활성화 합니다.
        
        ```bash
        ipmitool lan set {IPMI lan channel} auth ADMIN MD5,PASSWORD
        ```
        
        1. 이제 다른 호스트에서 IPMI를 제어하고자 하는 서버를 원격으로 다음과 같이 사용할 수 있습니다. 아래는 Power 상태를 보는 예시입니다.
        
        ```bash
        ipmitool -A PASSWORD -U admin -P '****' -I lan -H 172.31.0.1 power status
        Chassis Power is on
        ```
        
    - DHCP 서버 설정
        
        DHCP 서버로 사용할 대상의 노드에 isc-dhcp-server 패키지가 깔려 있어야 합니다.
        
        대상 노드가 Ubuntu의 경우 다음과 같이 설치합니다.
        
        ```bash
        sudo apt install isc-dhcp-server
        ```
        
        DHCP 서버는 Controller 노드와 Compute 노드에서 사용하는 Internal Interface를 통해서 접근 가능하여야 합니다.
        
    - TFTP 서버 설정
        
        Controller와 Compute노드가 부팅되면서 사용할 PXE 파일들을 제공할 TFTP 서버가 구성되어 있어야 합니다.
        
        TFTP 서버는 Controller 노드와 Compute 노드에서 사용하는 Internal Interface를 통해서 접근 가능하여야 합니다.
        
    - iSCSI 서버 설정
        
        FreeBSD 운영체제를 사용하며, ZFS 파일시스템이 구성되어있고, ctld로 iSCSI 서버가 운영되어야 합니다.
        
        iSCSI 서버는 Controller 노드와 Compute 노드에서 사용하는 Internal Interface를 통해서 접근 가능하여야 합니다.
        
    - Controller 노드와 Compute 노드의 iSCSI 볼륨에서 사용되는 루트 파티션의 UUID 값
        
        PXE를 통해 iSCSI 볼륨의 루트 파티션으로 부팅을 하기 위해 UUID 값을 사전에 알고 있어야 합니다.
        

## 3. 설치 옵션 변수 설정

terraform.tfvars 파일을 열어 설치에 필요한 변수들을 설정합니다.

```bash
/* Infra Configuration Settings */
enable_infra_configuration = true
// iSCSI
iscsi_server_ip_address = "172.19.0.1"
iscsi_server_ssh_root_password = "****"
# iscsi_os_volume_target_name_controller_node="iqn.openstack-controller_terraform.target"
# iscsi_os_volume_target_name_compute_node="iqn.openstack-compute_terraform.target"
iscsi_os_volume_snapshot_name_controller_node = "volmgmt/openstack_controller_no_cloud_init_script@init"
iscsi_os_volume_snapshot_name_compute_node = "volmgmt/openstack_compute_no_cloud_init_script@init"
iscsi_os_volume_clone_name_controller_node = "volmgmt/openstack_controller_terraform"
iscsi_os_volume_clone_name_compute_node = "volmgmt/openstack_compute_terraform"
iscsi_os_volume_size_controller_node = "100G"
iscsi_os_volume_size_compute_node = "100G"
iscsi_os_volume_root_uuid_controller_node = "e3e9e4e9-2093-497d-8837-b92cff8302fa"
iscsi_os_volume_root_uuid_compute_node = "e3e9e4e9-2093-497d-8837-b92cff8302fa"
// DHCP
dhcp_server_ip_address = "192.168.110.240"
dhcp_server_ssh_root_password = "****"
dhcp_tftp_server_ip_address = "172.19.0.1"
dhcp_tftp_server_ssh_root_password = "****"
dhcp_tftp_server_exported_folder_location = "/volmgmt/boottp"
# dhcp_pxe_target_folder_name = "openstack_auto_install_terraform"
dhcp_nodes_internal_gateway_ip_address = "172.19.0.10"
dhcp_mac_address_controller_node = "00:00:00:00:00:01"
dhcp_mac_address_compute_node = "00:00:00:00:00:02"
// IPMI
ipmi_ip_address_controller_node = "172.31.0.1"
ipmi_user_name_controller_node = "admin"
ipmi_user_password_controller_node = "****"
ipmi_ip_address_compute_node = "172.31.0.2"
ipmi_user_name_compute_node = "admin"
ipmi_user_password_compute_node = "****"

/* Node Settings */
openstack_nodes_ssh_root_password = "****"
// controller
controller_node_hostname = "ct-01"
controller_node_internal_ip_address = "172.19.0.111"
controller_node_internal_ip_address_prefix_length = "24"
controller_node_internal_interface = "eno1"
controller_node_external_ip_address = "192.168.110.191"
controller_node_external_ip_address_prefix_length = "24"
controller_node_external_interface = "eno2"
// compute
compute_node_hostname = "cp-01"
compute_node_internal_ip_address = "172.19.0.112"
compute_node_internal_ip_address_prefix_length = "24"
compute_node_internal_interface = "eno1"
compute_node_external_ip_address = "192.168.110.192"
compute_node_external_ip_address_prefix_length = "24"
compute_node_external_interface = "eno2"

/* OpenStack Settings */
# openstack_keystone_admin_password = "openstack"
# openstack_octavia_ca_password = "openstack"
# openstack_octavia_client_ca_password = "openstack"
# openstack_octavia_keystone_password = "openstack"
# openstack_databases_password = "openstack"
openstack_vip_internal = "172.19.0.100"
openstack_vip_external = "192.168.110.190"
openstack_external_subnet_range = "192.168.110.0/24"
openstack_external_subnet_pool_start_ip_address = "192.168.110.180"
openstack_external_subnet_pool_end_ip_address = "192.168.110.189"
openstack_external_subnet_pool_gateway = "192.168.110.254"
openstack_internal_subnet_range = "10.0.0.0/24"
openstack_internal_subnet_gateway = "10.0.0.1"
# openstack_router_enable_snat = false
# openstack_create_cirros_test_image = true
# openstack_cirros_test_image_version = "0.6.1"

/* OpenStack NFS configuration */
// NFS server /etc/exports NFS options: (rw,nohide,sync,no_subtree_check,insecure,no_root_squash)
// Need permission for cinder: 42407
openstack_cinder_volumes_nfs_target = "172.29.0.10:/Storage/openstack/cinder"
// Need permission for glance: 42415
openstack_glance_images_nfs_target = "172.29.0.10:/Storage/openstack/images"
// Need permission for nova-compute: 42436
openstack_nova_compute_instances_nfs_target = "172.29.0.10:/Storage/openstack/instances"
```

- 인프라 자동 구성 옵션
    - enable_infra_configuration
        
        인프라 자동 구성 옵션을 활성화 합니다. iSCSI 볼륨을 구성하고, TFTP 서버와 DHCP 서버를 구성한 후 IPMI를 통해 부팅하는 과정들이 자동으로 됩니다.
        
        - 사용가능한 값 : true 또는 false
        - 기본값 : false
    - iSCSI
        - iscsi_server_ip_address
            
            iSCSI 서버의 IP 주소를 설정합니다.
            
            예시 : “172.19.0.1”
            
        - iscsi_server_ssh_root_password
            
            iSCSI 서버 SSH root 계정 암호를 설정합니다.
            
        - iscsi_os_volume_target_name_controller_node (옵션)
            
            Controller 노드 iSCSI OS 볼륨 타겟 이름을 설정합니다.
            
            기본값 : “iqn.openstack-controller_terraform.target”
            
        - iscsi_os_volume_target_name_compute_node (옵션)
            
            Compute 노드 iSCSI OS 볼륨 타겟 이름을 설정합니다.
            
            기본값 : "iqn.openstack-compute_terraform.target”
            
        - iscsi_os_volume_snapshot_name_controller_node
            
            Controller 노드 iSCSI OS 볼륨 스냅샷 이름을 설정합니다.
            
            예시 : “volmgmt/openstack_controller_no_cloud_init_script@init”
            
        - iscsi_os_volume_snapshot_name_compute_node
            
            Compute 노드 iSCSI OS 볼륨 스냅샷 이름을 설정합니다.
            
            예시 : “volmgmt/openstack_compute_no_cloud_init_script@init”
            
        - iscsi_os_volume_clone_name_controller_node
            
            Controller 노드 iSCSI OS 볼륨 클론 이름을 설정합니다.
            
            예시 : "volmgmt/openstack_controller_terraform”
            
        - iscsi_os_volume_clone_name_compute_node
            
            Compute 노드 iSCSI OS 볼륨 클론 이름을 설정합니다.
            
            예시 : "volmgmt/openstack_compute_terraform”
            
        - iscsi_os_volume_size_controller_node
            
            Controller 노드 OS 볼륨 사이즈를 설정합니다.
            
            예시 : “100G”
            
        - iscsi_os_volume_size_compute_node
            
            Compute 노드 OS 볼륨 사이즈를 설정합니다.
            
            예시 : “100G”
            
        - iscsi_os_volume_root_uuid_controller_node
            
            Controller 노드 OS 볼륨 root 파티션 UUID 를 설정합니다.
            
            예시 : “e3e9e4e9-2093-497d-8837-b92cff8302fa”
            
        - iscsi_os_volume_root_uuid_compute_node
            
            Compute 노드 OS 볼륨 root 파티션 UUID 를 설정합니다.
            
            예시 : “e3e9e4e9-2093-497d-8837-b92cff8302fa”
            
    - DHCP
        - dhcp_server_ip_address
            
            DHCP 서버 IP 주소를 설정합니다.
            
            예시 : "192.168.110.240”
            
        - dhcp_server_ssh_root_password
            
            DHCP 서버 SSH root 계정 암호를 설정합니다.
            
        - dhcp_tftp_server_ip_address
            
            TFTP 서버의 IP 주소를 설정합니다.
            
            예시 : “172.19.0.1”
            
        - dhcp_tftp_server_ssh_root_password
            
            TFTP 서버의 root 계정 암호를 설정합니다.
            
        - dhcp_tftp_server_exported_folder_location
            
            TFTP 서버에서 공유된 폴더 경로를 설정합니다.
            
            예시 : “/volmgmt/boottp”
            
        - dhcp_tftp_target_folder_name (옵션)
            
            TFTP 서버에 부팅시 필요한 PXE 파일들을 저장할 PXE 폴더명을 설정합니다.
            
            기본값 : "openstack_auto_install_terraform”
            
        - dhcp_nodes_internal_gateway_ip_address
            
            노드들에 사용되는 내부 게이트웨이 IP 주소를 설정합니다.
            
            예시 : “172.31.0.1”
            
        - dhcp_mac_address_controller_node
            
            Controller 노드의 MAC 주소를 설정합니다.
            
            예시 : “00:00:00:00:00:01”
            
        - dhcp_mac_address_compute_node
            
            Compute 노드의 MAC 주소를 설정합니다.
            
            예시 : “00:00:00:00:00:02”
            
    - IPMI
        - ipmi_ip_address_controller_node
            
            Controller 노드 IPMI IP 주소를 설정합니다.
            
            예시 : “172.31.0.1”
            
        - ipmi_user_name_controller_node
            
            Controller 노드 IPMI 사용자명을 설정합니다.
            
            예시 : “admin”
            
        - ipmi_user_password_controller_node
            
            Controller 노드 IPMI 사용자 암호를 설정합니다.
            
        - ipmi_ip_address_compute_node
            
            Compute 노드 IPMI IP 주소를 설정합니다.
            
            예시 : “172.31.0.2”
            
        - ipmi_user_name_compute_node
            
            Compute 노드 IPMI 사용자명을 설정합니다.
            
            예시 : “admin”
            
        - ipmi_user_password_compute_node
            
            Compute 노드 IPMI 사용자 암호를 설정합니다.
            
- 공통
    - openstack_nodes_ssh_root_password
        
        OpenStack 노드별 SSH 접속시 사용될 비밀번호를 설정합니다.
        
- Controller 노드 관련 설정
    - controller_node_hostname
        
        Controller 노드의 호스트 명을 설정합니다.
        
        예시 : “ct-01”
        
    - controller_node_internal_ip_address
        
        Controller 노드의 내부 인터페이스에 사용할 IP 주소를 설정합니다.
        
        예시 : "172.19.0.111"
        
    - controller_node_internal_ip_address_prefix_length
        
        Controller 노드의 내부 인터페이스에 설정할 IP 주소의 Prefix 길이를 설정합니다.
        
        예시 : “24”
        
    - controller_node_internal_interface
        
        Controller 노드의 내부 인터페이스명을 설정합니다.
        
        예시 : “eno1”
        
    - controller_node_external_ip_address
        
        Controller 노드의 외부 인터페이스에 사용할  IP 주소를 설정합니다.
        
        예시 : "192.168.110.191"
        
    - controller_node_external_ip_address_prefix_length
        
        Controller 노드의 외부 인터페이스에 사용할 IP 주소의 Prefix 길이를 설정합니다.
        
        예시 : "24"
        
    - controller_node_external_interface
        
        Controller 노드의 외부 인터페이스명을 설정합니다.
        
        예시 : “eno2”
        
- Compute 노드 관련 설정
    - compute_node_hostname
        
        Compute 노드의 호스트 명을 설정합니다.
        
        예시 : "cp-01"
        
    - compute_node_internal_ip_address
        
        Compute 노드의 내부 인터페이스에 사용할 IP 주소를 설정합니다.
        
        예시 : "172.19.0.112"
        
    - compute_node_internal_ip_address_prefix_length
        
        Compute 노드의 내부 인터페이스에 사용할 IP 주소의 Prefix 길이를 설정합니다.
        
        예시 : "24"
        
    - compute_node_internal_interface
        
        Compute 노드의 내부 인터페이스명을 설정합니다.
        
        예시 : "eno1"
        
    - compute_node_external_ip_address
        
        Compute 노드의 외부 인터페이스에 사용할  IP 주소를 설정합니다.
        
        예시 : "192.168.110.192"
        
    - compute_node_external_ip_address_prefix_length
        
        Compute 노드의 외부 인터페이스에 사용할 IP 주소의 Prefix 길이를 설정합니다.
        
        예시 : "24"
        
    - compute_node_external_interface
        
        Compute 노드의 외부 인터페이스명을 설정합니다.
        
        예시 : "eno2"
        
- OpenStack
    - openstack_keystone_admin_password
        - admin 계정으로 로그인시 사용할 암호를 설정합니다.
        - 기본값 : "openstack"
    - openstack_octavia_ca_password
        - Octavia CA 인증서 생성시 사용할 암호를 설정합니다.
        - 기본값 : "openstack"
    - openstack_octavia_client_ca_password
        - Octavia Client 인증서 생성시 사용할 암호를 설정합니다.
        - 기본값 : "openstack"
    - openstack_octavia_keystone_password
        - octavia 사용자가 사용할 암호를 설정합니다.
        - 기본값 : "openstack"
    - openstack_databases_password
        - OpenStack에 사용되는 데이터베이스들에 사용할 암호를 설정합니다.
        - 기본값 : "openstack"
    - openstack_vip_internal
        - OpenStack의 내부 인터페이스 로드밸런싱에 사용할 VIP를 설정합니다.
        - 예시 : "172.19.0.100"
    - openstack_vip_external
        - OpenStack의 외부 인터페이스 로드밸런싱에 사용할 VIP를 설정합니다.
        - 예시 : "192.168.110.190"
    - openstack_external_subnet_range
        - OpenStack에서 외부 IP 할당시 사용할 서브넷 범위를 설정합니다.
        - 예시 : "192.168.110.0/24"
    - openstack_external_subnet_pool_start_ip_address
        - OpenStack에서 외부 IP 할당시 사용될 처음 시작 주소를 설정합니다.
        - 예시 : "192.168.110.180"
    - openstack_external_subnet_pool_end_ip_address
        - OpenStack에서 외부 IP 할당시 사용될 마지막 끝 주소를 설정합니다.
        - 예시 : "192.168.110.189"
    - openstack_external_subnet_pool_gateway
        - OpenStack에서 외부 IP 할당시 사용되는 서브넷에서 사용할 게이트웨이 주소를 설정합니다.
        - 예시 : "192.168.110.254"
    - openstack_interanl_subnet_range
        - OpenStack 내부적으로 인스턴스에 사용할 서브넷 범위를 설정합니다.
        - 예시 : "10.0.0.0/24"
    - openstack_internal_subnet_gateway
        - OpenStack 내부적으로 인스턴스에 사용할 서브넷에서 사용할 게이트웨이 주소를 설정합니다. openstack_interanl_subnet_range 범위에 속하는 IP중 하나를 지정하여 설정하면 됩니다.
        - 예시 : "10.0.0.1"
    - openstack_router_enable_snat
        - OpenStack 라우터에서 SNAT 기능을 사용할지 여부를 설정합니다. 활성화 된 경우 인스턴스는 openstack_interanl_subnet_range 서브넷 범위내에서 IP를 할당받고 외부로 나갈시 NAT를 통해 외부 주소로 변환되어 Floating IP를 할당하지 않고도 외부 통신이 가능합니다. 활성화 되어 있지 않은 경우 인스턴스가 외부로 통신하기 위해서는 Floating IP가 할당되어 있어야 합니다.
        - 사용가능한 값 : true 또는 false
        - 기본값 : false
    - openstack_create_cirros_test_image = true
        - OpenStack 설치가 완료되고 난 후 CirrOS 이미지를 구성합니다. 용량이 작은 이미지로 간단하게 인스턴스가 정상적으로 동작하는지 테스트하는 용도로 사용할 수 있습니다.
        - 사용가능한 값 : true 또는 false
        - 기본값 : true
    - openstack_cirros_test_image_version = "0.6.1"
        - CirrOS 이미지 구성시 사용할 버전을 설정합니다.
        - 버전 참고 : [https://github.com/cirros-dev/cirros/tags](https://github.com/cirros-dev/cirros/tags)
        - 기본값 : "0.6.1"
- OpenStack NFS 마운트 경로 설정
    
    NFS Server에서 /etc/exports 파일에 각 폴더의 옵션을 다음과 같이 설정합니다.
    
    (rw,nohide,sync,no_subtree_check,insecure,no_root_squash)
    
    - openstack_cinder_volumes_nfs_target
        - Cinder 모듈에서 Volume 저장시 사용될 NFS 타겟 경로를 설정합니다.
        - NFS 서버에서 해당 폴더의 UID, GID 권한은 42407로 설정되어 있어야 합니다.
        - 예시 : "172.29.0.10:/Storage/openstack/cinder"
    - openstack_glance_images_nfs_target
        - Glance 모듈에서 Image 저장시 사용될 NFS 타겟 경로를 설정합니다.
        - NFS 서버에서 해당 폴더의 UID, GID 권한은 42415로 설정되어 있어야 합니다.
        - 예시 : "172.29.0.10:/Storage/openstack/images"
    - openstack_nova_compute_instances_nfs_target
        - Nova Compute 모듈에서 인스턴스 저장시 사용될 NFS 타겟 경로를 설정합니다.
        - NFS 서버에서 해당 폴더의 UID, GID 권한은 42436으로 설정되어 있어야 합니다.
        - 예시 : "172.29.0.10:/Storage/openstack/instances"

## 4. 자동화 설치 스크립트 실행

Controller 노드에서 자동화 스크립트를 실행합니다.

```bash
cd openstack_install_automation/
./install_openstack

...(생략)...

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

...(생략)...

[*] Installation finished!
[*] Please reboot the system.
```

## 5. 로그 확인

설치 과정 중에 출력된 메세지들은 스크립트 실행 폴더에 `log.out` 이라는 파일로 기록됩니다.

```bash
vi log.out
```

## 6. Terraform State 파일 정리

Terraform 설치 스크립트를 실행하면서 저장된 State를 초기화 하기 위해서는 스크립트 실행 폴더에 있는 `clean_terraform_states.sh` 스크립트를 실행합니다.

```bash
./clean_terraform_states.sh
```

# 이슈

## 1. 인스턴스 생성시 Timeout 초과되어 인스턴스 생성 에러가 발생하는 문제

- Compute Node에 SSH 접속한 후 아래 파일을 수정한다.

vi /etc/kolla/nova-compute/nova.conf

```bash
## [DEFAULT] 섹션에 아래 2 옵션을 추가한다.
## 아래 설정은 Block이 매핑되기까지 1800초 (30분)을 대기하고 실패 시 6번을 retry 한다는 설정이다.
block_device_allocate_retries = 1800
block_device_allocate_retries_interval = 6
```

- 수정후 nova-compute 컨테이너를 재시작 한다.

## 2. ipmitool 사용가능하도록 authtype 설정

ipmitool을 사용가능 하도록 하려는 장비에 접속하여 다음과 같이 실행한다.

```bash
apt install -y ipmitool

ipmitool lan set {IPMI lan channel} auth ADMIN MD5,PASSWORD
# 예시
# ipmitool lan set 3 auth ADMIN MD5,PASSWORD
```

이제 다른 호스트에서 IPMI를 제어하고자 하는 서버를 원격으로 다음과 같이 사용할 수 있다. 아래는 Power 상태를 보는 예시이다.

```bash
ipmitool -A PASSWORD -U admin -P '****' -I lan -H 172.31.0.3 power status
Chassis Power is on
```

## 3. Kolla Ansible 설치 과정중 OVN 관련 컨테이너가 설정되면 외부 인터페이스의 연결이 끊어지는 문제

 Kolla Ansible 설치를 진행할 때는 컨테이너 이미지들을 미리 모두 Pull 하도록 하고 난 후 내부 인터페이스를 통해 SSH 접속을 하여 설치를 진행한다.

## 4. Network Manager가 설치되어 있는 경우 네트워크 설정에 충돌이 발생하는 문제

 OpenStack에서 네트워크 설정을 하려고 하면 Network Manager는 네트워크 상태가 변경될 경우 기존에 설정된 값으로 네트워크를 재설정 하려고 하기 때문에 둘 간의 충돌이 발생하게 됨.

- 시도한 방법
    
     netplan YAML 파일에서 인터페이스 별로 renderer 설정이 가능하다. systemd 에서 제어하게 할 인터페이스는 networkd renderer를 사용하게 하고, Network Manager 에서 제어하게 할 인터페이스는 renderer에 Netwok Manager를 써주면 된다.
    
    - 예시
        
        ```bash
        network:
          version: 2
          ethernets:
            eno1:
              renderer: networkd
              addresses:
              - 10.0.0.100/24
            eno2:
              renderer: NetworkManager
              addresses:
              - 192.168.110.100/24
              gateway4: 192.168.110.254
              nameservers:
                addresses:
                - 1.1.1.1
                - 1.0.0.1
                search: []
        ```
        
    
     하지만 여전히 Network Manager에 연결 프로파일이 남아 있는 경우 경우에 따라 해당 프로파일에 설정된 값들로 인터페이스가 설정되는 경우가 발생한다.
    

 

따라서, OpenStack 설치시에는 network-manager 패키지를 삭제해 주는 것이 권장된다.

```bash
sudo apt purge network-manager
sudo apt purge --auto-remove
```
