/* Infra Configuration Settings */
enable_infra_configuration = false

/* Node Settings */
openstack_nodes_ssh_root_password = "****"
// controller
controller_node_hostname = "ct-01"
controller_node_internal_ip_address = "10.0.0.101"
controller_node_internal_ip_address_prefix_length = "24"
controller_node_internal_interface = "ens33"
controller_node_external_ip_address = "10.0.0.101"
controller_node_external_ip_address_prefix_length = "24"
controller_node_external_interface = "ens33"

/* OpenStack Settings */
# openstack_keystone_admin_password = "openstack"
# openstack_octavia_ca_password = "openstack"
# openstack_octavia_client_ca_password = "openstack"
# openstack_octavia_keystone_password = "openstack"
# openstack_databases_password = "openstack"
openstack_vip_internal = "10.0.0.10"
openstack_vip_external = "10.0.0.10"
openstack_external_subnet_range = "10.0.0.0/24"
openstack_external_subnet_pool_start_ip_address = "10.0.0.200"
openstack_external_subnet_pool_end_ip_address = "10.0.0.254"
openstack_external_subnet_pool_gateway = "10.0.0.2"
openstack_internal_subnet_range = "172.16.0.0/24"
openstack_internal_subnet_gateway = "172.16.0.1"
# openstack_router_enable_snat = false
# openstack_create_cirros_test_image = true
# openstack_cirros_test_image_version = "0.6.1"

/* OpenStack NFS configuration */
// NFS server /etc/exports NFS options: (rw,nohide,sync,no_subtree_check,insecure,no_root_squash)
// Need permission for cinder: 42407
openstack_cinder_volumes_nfs_target = "127.0.0.1:/openstack/cinder"
// Need permission for glance: 42415
openstack_glance_images_nfs_target = "127.0.0.1:/openstack/images"
// Need permission for nova-compute: 42436
openstack_nova_compute_instances_nfs_target = "127.0.0.1:/openstack/instances"
