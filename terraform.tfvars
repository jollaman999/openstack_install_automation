/* Infra Configuration Settings */
enable_infra_configuration = false
# // iSCSI
# iscsi_server_ip_address = "10.0.30.1"
# iscsi_server_ssh_root_password = "****"
# # iscsi_os_volume_target_name_controller_node="iqn.openstack-controller_terraform.target"
# # iscsi_os_volume_target_name_compute1_node="iqn.openstack-compute1_terraform.target"
# # iscsi_os_volume_target_name_compute2_node="iqn.openstack-compute2_terraform.target"
# iscsi_os_volume_snapshot_name_controller_node = "volmgmt/openstack_controller_no_cloud_init_script@init"
# iscsi_os_volume_snapshot_name_compute_node = "volmgmt/openstack_compute_no_cloud_init_script@init"
# iscsi_os_volume_clone_name_controller_node = "volmgmt/openstack_controller_terraform"
# iscsi_os_volume_clone_name_compute1_node = "volmgmt/openstack_compute1_terraform"
# iscsi_os_volume_clone_name_compute2_node = "volmgmt/openstack_compute2_terraform"
# iscsi_os_volume_size_controller_node = "100G"
# iscsi_os_volume_size_compute_node = "100G"
# iscsi_os_volume_root_uuid_controller_node = "e3e9e4e9-2093-497d-8837-b92cff8302fa"
# iscsi_os_volume_root_uuid_compute_node = "e3e9e4e9-2093-497d-8837-b92cff8302fa"
# // DHCP
# dhcp_server_ip_address = "192.168.110.240"
# dhcp_server_ssh_root_password = "hcc123!Q"
# dhcp_tftp_server_ip_address = "10.0.30.1"
# dhcp_tftp_server_ssh_root_password = "****"
# dhcp_tftp_server_exported_folder_location = "/volmgmt/boottp"
# # dhcp_pxe_target_folder_name = "openstack_auto_install_terraform"
# dhcp_nodes_internal_gateway_ip_address = "10.0.30.10"
# dhcp_mac_address_controller_node = "a4:bf:01:5a:b2:33"
# dhcp_mac_address_compute1_node = "a4:bf:01:5a:b0:03"
# dhcp_mac_address_compute2_node = "a4:bf:01:5a:b1:1b"
# // IPMI
# ipmi_ip_address_controller_node = "172.31.0.1"
# ipmi_user_name_controller_node = "admin"
# ipmi_user_password_controller_node = "****"
# ipmi_ip_address_compute1_node = "172.31.0.2"
# ipmi_user_name_compute1_node = "admin"
# ipmi_user_password_compute1_node = "****"
# ipmi_ip_address_compute2_node = "172.31.0.3"
# ipmi_user_name_compute2_node = "admin"
# ipmi_user_password_compute2_node = "****"

/* Node Settings */
openstack_nodes_ssh_root_password = "****"
// controller
controller_node_hostname = "ct-01"
controller_node_internal_ip_address = "10.0.30.191"
controller_node_internal_ip_address_prefix_length = "24"
controller_node_internal_interface = "ens8"
controller_node_external_ip_address = "192.168.123.191"
controller_node_external_ip_address_prefix_length = "24"
controller_node_external_interface = "ens3"
// compute 1
compute1_node_hostname = "cp-01"
compute1_node_internal_ip_address = "10.0.30.192"
compute1_node_internal_ip_address_prefix_length = "24"
compute1_node_internal_interface = "ens8"
compute1_node_external_ip_address = "192.168.123.192"
compute1_node_external_ip_address_prefix_length = "24"
compute1_node_external_interface = "ens3"
// compute 2
compute2_node_hostname = "cp-02"
compute2_node_internal_ip_address = "10.0.30.193"
compute2_node_internal_ip_address_prefix_length = "24"
compute2_node_internal_interface = "ens8"
compute2_node_external_ip_address = "192.168.123.193"
compute2_node_external_ip_address_prefix_length = "24"
compute2_node_external_interface = "ens3"

/* OpenStack Settings */
# openstack_keystone_admin_password = "openstack"
# openstack_octavia_ca_password = "openstack"
# openstack_octavia_client_ca_password = "openstack"
# openstack_octavia_keystone_password = "openstack"
# openstack_databases_password = "openstack"
openstack_vip_internal = "10.0.30.100"
openstack_vip_external = "192.168.123.190"
openstack_external_subnet_range = "192.168.123.0/24"
openstack_external_subnet_pool_start_ip_address = "192.168.123.180"
openstack_external_subnet_pool_end_ip_address = "192.168.123.189"
openstack_external_subnet_pool_gateway = "192.168.123.254"
openstack_internal_subnet_range = "10.0.0.0/24"
openstack_internal_subnet_gateway = "10.0.0.1"
# openstack_router_enable_snat = false
# openstack_create_cirros_test_image = true
# openstack_cirros_test_image_version = "0.6.1"

/* OpenStack NFS configuration */
// NFS server /etc/exports NFS options: (rw,nohide,sync,no_subtree_check,insecure,no_root_squash)
// Need permission for cinder: 42407
openstack_cinder_volumes_nfs_target = "192.168.110.240:/Storage/openstack_ish/cinder"
// Need permission for glance: 42415
openstack_glance_images_nfs_target = "192.168.110.240:/Storage/openstack_ish/images"
// Need permission for nova-compute: 42436
openstack_nova_compute_instances_nfs_target = "192.168.110.240:/Storage/openstack_ish/instances"
