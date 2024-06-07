##########################################
# common
##########################################
locals {
    hosts_ips = toset(
        [
            "${var.controller_node_internal_ip_address}",
            "${var.compute_node_internal_ip_address}"
        ])

    # OpenStack Temp Directory
    openstack_tmp_dir = "/root/openstack_tmp"

    ipmi_node_wait_power_off_seconds = "10"
    node_connection_check_retry_counts = "100"
    node_connection_check_retry_interval_seconds = "3"

    network_reconfigure_wait_time_seconds = "10"

    iscsi_server_ip_address = toset(
        [
            "${var.iscsi_server_ip_address}",
        ])
    dhcp_server_ip_address = toset(
        [
            "${var.dhcp_server_ip_address}",
        ])
    dhcp_tftp_server_ip_address = toset(
        [
            "${var.dhcp_tftp_server_ip_address}",
        ])

    dhcp_pxe_file_path_controller = "/${var.dhcp_pxe_target_folder_name}/controller/pxelinux.0"
    dhcp_pxe_config_file_path_controller = "${var.dhcp_tftp_server_exported_folder_location}/${var.dhcp_pxe_target_folder_name}/controller/pxelinux.cfg/default"
    dhcp_pxe_file_path_compute = "/${var.dhcp_pxe_target_folder_name}/compute/pxelinux.0"
    dhcp_pxe_config_file_path_compute = "${var.dhcp_tftp_server_exported_folder_location}/${var.dhcp_pxe_target_folder_name}/compute/pxelinux.cfg/default"
}

##########################################
# iSCSI
##########################################
resource "null_resource" "iscsi_clone_zfs_volumes" {
    for_each = {for key, val in local.iscsi_server_ip_address:
               key => val if var.enable_infra_configuration == true}

    connection {
        type     = "ssh"
        user     = "root"
        password = var.iscsi_server_ssh_root_password
        host     = each.key
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "zfs clone ${var.iscsi_os_volume_snapshot_name_controller_node} ${var.iscsi_os_volume_clone_name_controller_node}",
            "STATUS=`echo $?`",
            "if [ $STATUS != \"0\" ]; then",
            "  echo \"Failed to clone controller node's os volume!\"",
            "  exit 1",
            "fi",
            "zfs clone ${var.iscsi_os_volume_snapshot_name_compute_node} ${var.iscsi_os_volume_clone_name_compute_node}",
            "STATUS=`echo $?`",
            "if [ $STATUS != \"0\" ]; then",
            "  echo \"Failed to clone compute node's os volume!\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "iscsi_configure_ctld" {
    depends_on = [
        null_resource.iscsi_clone_zfs_volumes
    ]

    for_each = {for key, val in local.iscsi_server_ip_address:
               key => val if var.enable_infra_configuration == true}

    connection {
        type     = "ssh"
        user     = "root"
        password = var.iscsi_server_ssh_root_password
        host     = each.key
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "PORTAL_GROUP_DEFINE=\"portal-group pg0 { discovery-auth-group no-authentication listen 0.0.0.0 listen [::] }\"",
            "PORTAL_GROUP_DEFINED=\"1\"",
            "PORTAL_GROUP=`cat /etc/ctl.conf | grep -i portal-group | grep -i listen | awk '{print $2}'`",
            "STATUS=`echo $?`",
            "if [ $STATUS != \"0\" ]; then",
            "  PORTAL_GROUP_DEFINED=\"0\"",
            "fi",
            "sed -i '' '/#### OpenStack Auto Installation Start ####/,/#### OpenStack Auto Installation End ####/d' /etc/ctl.conf",
            "echo \"#### OpenStack Auto Installation Start ####\" >> /etc/ctl.conf",
            "if [ $PORTAL_GROUP_DEFINED = \"0\" ]; then",
            "  echo $PORTAL_GROUP_DEFINED >> /etc/ctl.conf",
            "  PORTAL_GROUP=\"pg0\"",
            "fi",
            "echo -n 'target ${var.iscsi_os_volume_target_name_controller_node} {",
            "    auth-group no-authentication",
            "    portal-group '\"$PORTAL_GROUP\"'",
            "    lun 0 {",
            "        path /dev/zvol/${var.iscsi_os_volume_clone_name_controller_node}",
            "        size ${var.iscsi_os_volume_size_controller_node}",
            "    }",
            "}",
            "' >> /etc/ctl.conf",
            "echo -n 'target ${var.iscsi_os_volume_target_name_compute_node} {",
            "    auth-group no-authentication",
            "    portal-group '\"$PORTAL_GROUP\"'",
            "    lun 0 {",
            "        path /dev/zvol/${var.iscsi_os_volume_clone_name_compute_node}",
            "        size ${var.iscsi_os_volume_size_compute_node}",
            "    }",
            "}",
            "' >> /etc/ctl.conf",
            "echo \"#### OpenStack Auto Installation End ####\" >> /etc/ctl.conf",
            "service ctld status | grep -i running",
            "STATUS=`echo $?`",
            "if [ $STATUS != \"0\" ]; then",
            "  service ctld start",
            "  STATUS=`echo $?`",
            "  if [ $STATUS != \"0\" ]; then",
            "    echo \"Failed to start ctld!\"",
            "    return 1",
            "  fi",
            "fi",
            "service ctld reload",
            "STATUS=`echo $?`",
            "if [ $STATUS != \"0\" ]; then",
            "  echo \"Failed to reload ctld!\"",
            "  return 1",
            "fi"
        ]
    }
}

##########################################
# DHCPD
##########################################
resource "null_resource" "dhcpd_check_isc_dhcp_server_installed" {
    depends_on = [
        null_resource.iscsi_configure_ctld
    ]

    for_each = {for key, val in local.dhcp_server_ip_address:
               key => val if var.enable_infra_configuration == true}

    connection {
        type     = "ssh"
        user     = "root"
        password = var.dhcp_server_ssh_root_password
        host     = each.key
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "dpkg -S isc-dhcp-server",
            "STATUS=`echo $?`",
            "if [ $STATUS != \"0\" ]; then",
            "  echo \"isc-dhcp-server package not found from the DHCP server!\"",
            "  return 1",
            "fi"
        ]
    }
}

resource "null_resource" "dhcpd_create_temp_folder" {
    depends_on = [
        null_resource.dhcpd_check_isc_dhcp_server_installed
    ]

    for_each = {for key, val in local.dhcp_server_ip_address:
               key => val if var.enable_infra_configuration == true}

    connection {
        type     = "ssh"
        user     = "root"
        password = var.dhcp_server_ssh_root_password
        host     = each.key
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "mkdir -p ${local.openstack_tmp_dir}/"
        ]
    }
}

resource "null_resource" "dhcpd_set_config" {
    depends_on = [
        null_resource.dhcpd_create_temp_folder
    ]

    for_each = {for key, val in local.dhcp_server_ip_address:
               key => val if var.enable_infra_configuration == true}

    connection {
        type     = "ssh"
        user     = "root"
        password = var.dhcp_server_ssh_root_password
        host     = each.key
    }

    provisioner "file" {
        source      = "${path.root}/utils"
        destination = "${local.openstack_tmp_dir}/"
    }

    provisioner "file" {
        source      = "${path.root}/dhcpd/subnet.tpl"
        destination = "/etc/dhcp/openstack_dhcpd_config.conf"
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "OPENSTACK_DHCPD_CONFIG_FILE=\"/etc/dhcp/openstack_dhcpd_config.conf\"",
            "sed -i '/openstack_dhcpd_config/d' /etc/dhcp/dhcpd.conf",
            "echo \"include \\\"$OPENSTACK_DHCPD_CONFIG_FILE\\\";\" >> /etc/dhcp/dhcpd.conf",
            ". ${local.openstack_tmp_dir}/utils/ip_util",
            "NETWORK_IP=`get_network_address ${var.controller_node_internal_ip_address} ${var.controller_node_internal_ip_address_prefix_length}`",
            "NETMASK=`cidr2mask ${var.controller_node_internal_ip_address_prefix_length}`",
            "sed -i 's@DHCPD_SUBNET@'\"$NETWORK_IP\"'@g' $OPENSTACK_DHCPD_CONFIG_FILE",
            "sed -i 's@DHCPD_NETMASK@'\"$NETMASK\"'@g' $OPENSTACK_DHCPD_CONFIG_FILE",
            "sed -i 's@DHCPD_DEFAULT_GATEWAY@'\"${var.dhcp_nodes_internal_gateway_ip_address}\"'@g' $OPENSTACK_DHCPD_CONFIG_FILE",
            "sed -i 's@DHCPD_TFTP_SERVER_ADDRESS@'\"${var.dhcp_tftp_server_ip_address}\"'@g' $OPENSTACK_DHCPD_CONFIG_FILE",
            "sed -i 's@DHCPD_CONTROLLER_MAC_ADDRESS@'\"${var.dhcp_mac_address_controller_node}\"'@g' $OPENSTACK_DHCPD_CONFIG_FILE",
            "sed -i 's@DHCPD_CONTROLLER_INTERNAL_IP@'\"${var.controller_node_internal_ip_address}\"'@g' $OPENSTACK_DHCPD_CONFIG_FILE",
            "sed -i 's@DHCPD_PXE_PATH_CONTROLLER@'\"${local.dhcp_pxe_file_path_controller}\"'@g' $OPENSTACK_DHCPD_CONFIG_FILE",
            "sed -i 's@DHCPD_COMPUTE_MAC_ADDRESS@'\"${var.dhcp_mac_address_compute_node}\"'@g' $OPENSTACK_DHCPD_CONFIG_FILE",
            "sed -i 's@DHCPD_COMPUTE_INTERNAL_IP@'\"${var.compute_node_internal_ip_address}\"'@g' $OPENSTACK_DHCPD_CONFIG_FILE",
            "sed -i 's@DHCPD_PXE_PATH_COMPUTE@'\"${local.dhcp_pxe_file_path_compute}\"'@g' $OPENSTACK_DHCPD_CONFIG_FILE",
            "service isc-dhcp-server restart"
        ]
    }
}

resource "null_resource" "dhcpd_tftp_server_create_pxe_folder" {
    depends_on = [
        null_resource.dhcpd_set_config
    ]

    for_each = {for key, val in local.dhcp_tftp_server_ip_address:
               key => val if var.enable_infra_configuration == true}

    connection {
        type     = "ssh"
        user     = "root"
        password = var.dhcp_tftp_server_ssh_root_password
        host     = each.key
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "rm -rf ${var.dhcp_tftp_server_exported_folder_location}/${var.dhcp_pxe_target_folder_name}",
            "mkdir -p ${var.dhcp_tftp_server_exported_folder_location}/${var.dhcp_pxe_target_folder_name}"
        ]
    }
}

resource "null_resource" "dhcpd_tftp_server_copy_pxe_files" {
    depends_on = [
        null_resource.dhcpd_tftp_server_create_pxe_folder
    ]

    for_each = {for key, val in local.dhcp_tftp_server_ip_address:
               key => val if var.enable_infra_configuration == true}

    connection {
        type     = "ssh"
        user     = "root"
        password = var.dhcp_tftp_server_ssh_root_password
        host     = each.key
    }

    provisioner "file" {
        source      = "${path.root}/pxe/pxe_files.tar.xz"
        destination = "${var.dhcp_tftp_server_exported_folder_location}/${var.dhcp_pxe_target_folder_name}/pxe_files.tar.xz"
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "tar xvf ${var.dhcp_tftp_server_exported_folder_location}/${var.dhcp_pxe_target_folder_name}/pxe_files.tar.xz -C ${var.dhcp_tftp_server_exported_folder_location}/${var.dhcp_pxe_target_folder_name}/",
            "chmod -R 755 ${var.dhcp_tftp_server_exported_folder_location}/${var.dhcp_pxe_target_folder_name}/"
        ]
    }
}

resource "null_resource" "dhcpd_tftp_server_create_pxe_config_controller_node" {
    depends_on = [
        null_resource.dhcpd_tftp_server_copy_pxe_files
    ]

    for_each = {for key, val in local.dhcp_tftp_server_ip_address:
               key => val if var.enable_infra_configuration == true}

    connection {
        type     = "ssh"
        user     = "root"
        password = var.dhcp_tftp_server_ssh_root_password
        host     = each.key
    }

    provisioner "file" {
        source      = "${path.root}/pxe/default"
        destination = "${local.dhcp_pxe_config_file_path_controller}"
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "PXE_CONFIG_FILE_CONTROLLER=\"${local.dhcp_pxe_config_file_path_controller}\"",
            "sed -i '' 's/OPENSTACK_AUTO_INSTALL_ISCSI_TARGET_NAME/'\"${var.iscsi_os_volume_target_name_controller_node}\"'/g' $PXE_CONFIG_FILE_CONTROLLER",
            "sed -i '' 's/OPENSTACK_AUTO_INSTALL_ISCSI_TARGET_IP/'\"${var.iscsi_server_ip_address}\"'/g' $PXE_CONFIG_FILE_CONTROLLER",
            "sed -i '' 's/OPENSTACK_AUTO_INSTALL_ISCSI_OS_VOLUME_ROOT_UUID/'\"${var.iscsi_os_volume_root_uuid_controller_node}\"'/g' $PXE_CONFIG_FILE_CONTROLLER"
        ]
    }
}

resource "null_resource" "dhcpd_tftp_server_create_pxe_config_compute_node" {
    depends_on = [
        null_resource.dhcpd_tftp_server_create_pxe_config_controller_node
    ]

    for_each = {for key, val in local.dhcp_tftp_server_ip_address:
               key => val if var.enable_infra_configuration == true}

    connection {
        type     = "ssh"
        user     = "root"
        password = var.dhcp_tftp_server_ssh_root_password
        host     = each.key
    }

    provisioner "file" {
        source      = "${path.root}/pxe/default"
        destination = "${local.dhcp_pxe_config_file_path_compute}"
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "PXE_CONFIG_FILE_COMPUTE=\"${local.dhcp_pxe_config_file_path_compute}\"",
            "sed -i '' 's/OPENSTACK_AUTO_INSTALL_ISCSI_TARGET_NAME/'\"${var.iscsi_os_volume_target_name_compute_node}\"'/g' $PXE_CONFIG_FILE_COMPUTE",
            "sed -i '' 's/OPENSTACK_AUTO_INSTALL_ISCSI_TARGET_IP/'\"${var.iscsi_server_ip_address}\"'/g' $PXE_CONFIG_FILE_COMPUTE",
            "sed -i '' 's/OPENSTACK_AUTO_INSTALL_ISCSI_OS_VOLUME_ROOT_UUID/'\"${var.iscsi_os_volume_root_uuid_compute_node}\"'/g' $PXE_CONFIG_FILE_COMPUTE"
        ]
    }
}

##########################################
# IPMI
##########################################
resource "null_resource" "ipmi_install_ipmitool" {
    depends_on = [
        null_resource.dhcpd_tftp_server_create_pxe_config_compute_node
    ]

    provisioner "local-exec" {
        command = <<-EOT
        /bin/bash -c '
        ENABLE_INFRA_CONFIGURATION=`echo "${var.enable_infra_configuration}" | tr '[:upper:]' '[:lower:]'`
        if [ "$ENABLE_INFRA_CONFIGURATION" = "false" ]; then
          exit 0
        fi
        IS_UBUNTU=`lsb_release -i | grep -i "ubuntu" > /dev/null 2>&1 ; echo $?`
        if [ $IS_UBUNTU = "0" ]; then
          apt install -y ipmitool
        else
          yum install -y ipmitool
        fi
        '
        EOT
  }
}

resource "null_resource" "ipmi_controller_node_off" {
    depends_on = [
        null_resource.ipmi_install_ipmitool
    ]

    provisioner "local-exec" {
        command = <<-EOT
        /bin/bash -c '
        ENABLE_INFRA_CONFIGURATION=`echo "${var.enable_infra_configuration}" | tr '[:upper:]' '[:lower:]'`
        if [ "$ENABLE_INFRA_CONFIGURATION" = "false" ]; then
          exit 0
        fi
        ipmitool -A PASSWORD -U ${var.ipmi_user_name_controller_node} -P ${var.ipmi_user_password_controller_node} -I lan -H ${var.ipmi_ip_address_controller_node} power off > /dev/null 2>&1
        sleep ${local.ipmi_node_wait_power_off_seconds}
        '
        EOT
  }
}

resource "null_resource" "ipmi_compute_node_off" {
    depends_on = [
        null_resource.ipmi_install_ipmitool
    ]

    provisioner "local-exec" {
        command = <<-EOT
        /bin/bash -c '
        ENABLE_INFRA_CONFIGURATION=`echo "${var.enable_infra_configuration}" | tr '[:upper:]' '[:lower:]'`
        if [ "$ENABLE_INFRA_CONFIGURATION" = "false" ]; then
          exit 0
        fi
        ipmitool -A PASSWORD -U ${var.ipmi_user_name_compute_node} -P ${var.ipmi_user_password_compute_node} -I lan -H ${var.ipmi_ip_address_compute_node} power off > /dev/null 2>&1
        sleep ${local.ipmi_node_wait_power_off_seconds}
        '
        EOT
  }
}

resource "null_resource" "ipmi_controller_node_set_bootdev_pxe" {
    depends_on = [
        null_resource.ipmi_controller_node_off
    ]

    provisioner "local-exec" {
        command = <<-EOT
        /bin/bash -c '
        ENABLE_INFRA_CONFIGURATION=`echo "${var.enable_infra_configuration}" | tr '[:upper:]' '[:lower:]'`
        if [ "$ENABLE_INFRA_CONFIGURATION" = "false" ]; then
          exit 0
        fi
        ipmitool -A PASSWORD -U ${var.ipmi_user_name_controller_node} -P ${var.ipmi_user_password_controller_node} -I lan -H ${var.ipmi_ip_address_controller_node} chassis bootparam set bootflag force_pxe
        '
        EOT
  }
}

resource "null_resource" "ipmi_compute_node_set_bootdev_pxe" {
    depends_on = [
        null_resource.ipmi_compute_node_off
    ]

    provisioner "local-exec" {
        command = <<-EOT
        /bin/bash -c '
        ENABLE_INFRA_CONFIGURATION=`echo "${var.enable_infra_configuration}" | tr '[:upper:]' '[:lower:]'`
        if [ "$ENABLE_INFRA_CONFIGURATION" = "false" ]; then
          exit 0
        fi
        ipmitool -A PASSWORD -U ${var.ipmi_user_name_compute_node} -P ${var.ipmi_user_password_compute_node} -I lan -H ${var.ipmi_ip_address_compute_node} chassis bootparam set bootflag force_pxe 
        '
        EOT
  }
}

resource "null_resource" "ipmi_controller_node_on" {
    depends_on = [
        null_resource.ipmi_compute_node_set_bootdev_pxe
    ]

    provisioner "local-exec" {
        command = <<-EOT
        /bin/bash -c '
        ENABLE_INFRA_CONFIGURATION=`echo "${var.enable_infra_configuration}" | tr '[:upper:]' '[:lower:]'`
        if [ "$ENABLE_INFRA_CONFIGURATION" = "false" ]; then
          exit 0
        fi
        ipmitool -A PASSWORD -U ${var.ipmi_user_name_controller_node} -P ${var.ipmi_user_password_controller_node} -I lan -H ${var.ipmi_ip_address_controller_node} power on
        '
        EOT
  }
}

resource "null_resource" "ipmi_compute_node_on" {
    depends_on = [
        null_resource.ipmi_compute_node_set_bootdev_pxe
    ]

    provisioner "local-exec" {
        command = <<-EOT
        /bin/bash -c '
        ENABLE_INFRA_CONFIGURATION=`echo "${var.enable_infra_configuration}" | tr '[:upper:]' '[:lower:]'`
        if [ "$ENABLE_INFRA_CONFIGURATION" = "false" ]; then
          exit 0
        fi
        ipmitool -A PASSWORD -U ${var.ipmi_user_name_compute_node} -P ${var.ipmi_user_password_compute_node} -I lan -H ${var.ipmi_ip_address_compute_node} power on
        '
        EOT
  }
}

resource "null_resource" "ipmi_install_telnet" {
    depends_on = [
        null_resource.ipmi_controller_node_on,
        null_resource.ipmi_compute_node_on
    ]

    provisioner "local-exec" {
        command = <<-EOT
        /bin/bash -c '
        IS_UBUNTU=`lsb_release -i | grep -i "ubuntu" > /dev/null 2>&1 ; echo $?`
        if [ $IS_UBUNTU = "0" ]; then
          apt install -y telnet
        else
          yum install -y telnet
        fi
        '
        EOT
  }
}

resource "null_resource" "ipmi_wait_controller_node" {
    depends_on = [
        null_resource.ipmi_install_telnet
    ]

    provisioner "local-exec" {
        command = <<-EOT
        /bin/bash -c '
        echo "[*] Waiting for SSH connection of controller node..."
        cnt=0
        while :
        do
           cnt=`expr $cnt + 1`
           echo -e "\x1dclose\x0d" | telnet ${var.controller_node_internal_ip_address} 22
           CONTROLLER_NODE_CONNECTION_STATUS=`echo $?`
           if [ "$CONTROLLER_NODE_CONNECTION_STATUS" = "0" ]; then
              break
           fi
           if [ "$cnt" = "${local.node_connection_check_retry_counts}" ]; then
              echo "Failed to connect to controller node!"
              exit 1
           fi
           sleep ${local.node_connection_check_retry_interval_seconds}
        done'
        EOT
  }
}

resource "null_resource" "ipmi_wait_compute_node" {
    depends_on = [
        null_resource.ipmi_install_telnet
    ]

    provisioner "local-exec" {
        command = <<-EOT
        /bin/bash -c '
        echo "[*] Waiting for SSH connection of compute node..."
        cnt=0
        while :
        do
           cnt=`expr $cnt + 1`
           echo -e "\x1dclose\x0d" | telnet ${var.compute_node_internal_ip_address} 22
           CONTROLLER_NODE_CONNECTION_STATUS=`echo $?`
           if [ "$CONTROLLER_NODE_CONNECTION_STATUS" = "0" ]; then
              break
           fi
           if [ "$cnt" = "${local.node_connection_check_retry_counts}" ]; then
              echo "Failed to connect to compute node!"
              exit 1
           fi
           sleep ${local.node_connection_check_retry_interval_seconds}
        done'
        EOT
  }
}

##########################################
# pre-check
##########################################
resource "null_resource" "pre_check_os" {
    depends_on = [
        null_resource.ipmi_wait_controller_node,
        null_resource.ipmi_wait_compute_node
    ]

    for_each = local.hosts_ips

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = each.key
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "CHECK_OS_ID=`lsb_release -i | grep -i \"ubuntu\" > /dev/null 2>&1 ; echo $?`",
            "CHECK_OS_RELEASE=`lsb_release -r | grep -i \"22.04\" > /dev/null 2>&1 ; echo $?`",
            "echo \"[*] Checking OS version...\"",
            "if [ $CHECK_OS_ID != \"0\" ] || [ $CHECK_OS_RELEASE != \"0\" ]; then",
            "  echo \"[!] This script only supports Ubuntu 22.04.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "pre_check_ipv6" {
    depends_on = [
        null_resource.pre_check_os
    ]

    for_each = local.hosts_ips

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = each.key
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "if [ ! -d \"/proc/sys/net/ipv6/\" ]; then",
            "  echo \"[!] IPv6 is not enabled! Please enable IPv6 and try again.\"",
            "  exit 1",
            "else",
            "  exit 0",
            "fi"
        ]
    }
}

resource "null_resource" "pre_check_compute_kvm" {
    depends_on = [
        null_resource.pre_check_ipv6
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.compute_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "HW_VIRTUALIZATION_AVAILABLE=`grep -o 'vmx\\|svm' /proc/cpuinfo 2>&1 > /dev/null ; echo $?`",
            "echo \"[*] Checking hardware virtualization from compute node...\"",
            "if [ $HW_VIRTUALIZATION_AVAILABLE != \"0\" ]; then",
            "  echo \"[!] Hardware virtualization is not available from compute node!\"",
            "  echo \" Hardware virtualization is needed for run instances with KVM enabled.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "pre_check_ssh_connection" {
    depends_on = [
        null_resource.pre_check_compute_kvm
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "check_ssh_connection_of_iface() {",
            "  NODE_IPS_WITH_CIDR=`ip addr | grep $1 | awk '{ print $2 }' | grep -v $1`",
            "  STATUS=`echo $?`",
            "  if [ $STATUS != \"0\" ]; then",
            "    return 0",
            "  fi",
            "  for IP_CIDR in $${NODE_IPS_WITH_CIDR[@]}; do",
            "    IP=`echo $IP_CIDR | cut -d'/' -f1`",
            "    SSH_CONNECTION_STATUS=`ss -tnpa -o state established src $IP | grep -i sshd > /dev/null ; echo $?`",
            "    if [ \"$SSH_CONNECTION_STATUS\" = \"0\" ]; then",
            "      echo \"[!] External SSH Connection Detected!!\"",
            "      echo \" External SSH connection will be disconnected while installing OpenStack!\"",
            "      echo \" Please exit external SSH connection and connect to SSH through internal interface.\"",
            "      echo \" You can check with 'sudo ss -tnpa -o state established | grep -i sshd' command.\"",
            "      exit 1",
            "    fi",
            "  done",
            "  return 0",
            "}",
            "echo \"[*] Checking SSH connection...\"",
            "check_ssh_connection_of_iface ${var.controller_node_external_interface}",
            "check_ssh_connection_of_iface br-ex"
        ]
    }
}

resource "null_resource" "pre_check_create_temp_folder" {
    depends_on = [
        null_resource.pre_check_ssh_connection
    ]

    for_each = local.hosts_ips

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = each.key
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "mkdir -p ${local.openstack_tmp_dir}/"
        ]
    }
}

resource "null_resource" "pre_check_iface_controller_node_internal_ip_prefix" {
    depends_on = [
        null_resource.pre_check_create_temp_folder
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "file" {
        source      = "${path.root}/utils"
        destination = "${local.openstack_tmp_dir}/"
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". ${local.openstack_tmp_dir}/utils/ip_util",
            "echo \"[*] Checking if controller node's configured internal IP address prefix length is matched...\"",
            "CIDR_INTERNAL=`get_cidr_from_iface_ip ${var.controller_node_internal_interface} ${var.controller_node_internal_ip_address}; echo $?`",
            "if [ $CIDR_INTERNAL = \"1\" ]; then",
            "  echo \"[!] Can't find IP address same with controller_node_internal_ip_address from Controller Node's internal interface.\"",
            "  exit 1",
            "elif [ $CIDR_INTERNAL != ${var.controller_node_internal_ip_address_prefix_length} ]; then",
            "  echo \"[!] ${var.controller_node_internal_ip_address_prefix_length} is not matched with Controller Node's internal interface.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "pre_check_iface_compute_node_internal_ip_prefix" {
    depends_on = [
        null_resource.pre_check_create_temp_folder
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.compute_node_internal_ip_address
    }

    provisioner "file" {
        source      = "${path.root}/utils"
        destination = "${local.openstack_tmp_dir}/"
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". ${local.openstack_tmp_dir}/utils/ip_util",
            "echo \"[*] Checking if compute node's configured internal IP address prefix length is matched...\"",
            "CIDR_INTERNAL=`get_cidr_from_iface_ip ${var.compute_node_internal_interface} ${var.compute_node_internal_ip_address}; echo $?`",
            "if [ $CIDR_INTERNAL = \"1\" ]; then",
            "  echo \"[!] Can't find IP address same with compute_node_internal_interface from Compute Node's internal interface.\"",
            "  exit 1",
            "elif [ $CIDR_INTERNAL != ${var.compute_node_internal_ip_address_prefix_length} ]; then",
            "  echo \"[!] ${var.compute_node_internal_ip_address_prefix_length} is not matched with Compute Node's internal interface.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "pre_check_iface_controller_node_internal_vip" {
    depends_on = [
        null_resource.pre_check_iface_controller_node_internal_ip_prefix,
        null_resource.pre_check_iface_compute_node_internal_ip_prefix
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". ${local.openstack_tmp_dir}/utils/ip_util",
            "echo \"[*] Checking if openstack_vip_internal is in range of controller node's internal network...\"",
            "INTERNAL_NETWORK_ADDRESS=`get_network_address ${var.controller_node_internal_ip_address} ${var.controller_node_internal_ip_address_prefix_length}`",
            "STATUS=`echo $?`",
            "if [ $STATUS = \"1\" ]; then",
            "  echo \"[!] Got wrong prefix length value of ${var.controller_node_internal_ip_address_prefix_length}.\"",
            "  exit 1",
            "elif [ $STATUS = \"2\" ]; then",
            "  echo \"[!] Got invalid IP address of ${var.controller_node_internal_ip_address}.\"",
            "  exit 1",
            "fi",
            "VIP_INTERNAL_NETWORK_ADDRESS=`get_network_address ${var.openstack_vip_internal} ${var.controller_node_internal_ip_address_prefix_length}`",
            "STATUS=`echo $?`",
            "if [ $STATUS = \"1\" ]; then",
            "  echo \"[!] Got wrong prefix length value of controller_node_internal_ip_address_prefix_length.\"",
            "  exit 1",
            "elif [ $STATUS = \"2\" ]; then",
            "  echo \"[!] Got invalid IP address of openstack_vip_internal.\"",
            "  exit 1",
            "fi",
            "if [ \"$INTERNAL_NETWORK_ADDRESS\" != \"$VIP_INTERNAL_NETWORK_ADDRESS\" ]; then",
            "  echo \"[!] openstack_vip_internal is not in range of controller node's internal network.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "pre_check_iface_controller_node_external_vip" {
    depends_on = [
        null_resource.pre_check_iface_controller_node_internal_vip
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". ${local.openstack_tmp_dir}/utils/ip_util",
            "echo \"[*] Checking if openstack_vip_external is in range of controller node's external network...\"",
            "EXTERNAL_NETWORK_ADDRESS=`get_network_address ${var.controller_node_external_ip_address} ${var.controller_node_external_ip_address_prefix_length}`",
            "STATUS=`echo $?`",
            "if [ $STATUS = \"1\" ]; then",
            "  echo \"[!] Got wrong prefix length value of controller_node_external_ip_address_prefix_length.\"",
            "  exit 1",
            "elif [ $STATUS = \"2\" ]; then",
            "  echo \"[!] Got invalid IP address of controller_node_external_ip_address.\"",
            "  exit 1",
            "fi",
            "VIP_EXTERNAL_NETWORK_ADDRESS=`get_network_address ${var.openstack_vip_external} ${var.controller_node_external_ip_address_prefix_length}`",
            "STATUS=`echo $?`",
            "if [ $STATUS = \"1\" ]; then",
            "  echo \"[!] Got wrong prefix length value of controller_node_external_ip_address_prefix_length.\"",
            "  exit 1",
            "elif [ $STATUS = \"2\" ]; then",
            "  echo \"[!] Got invalid IP address of openstack_vip_external.\"",
            "  exit 1",
            "fi",
            "if [ \"$EXTERNAL_NETWORK_ADDRESS\" != \"$VIP_EXTERNAL_NETWORK_ADDRESS\" ]; then",
            "  echo \"[!] openstack_vip_external is not in range of controller node's external network.\"",
            "  exit 1",
            "fi"
        ]
    }
}

##########################################
# install
##########################################

########### reconfigure_network ##########
data "template_file" "install_reconfigure_network_template_controller" {
    depends_on = [
        null_resource.pre_check_iface_controller_node_external_vip
    ]

    template = file("${path.root}/netplan/999-netplan_openstack.tpl")

    vars = {
        internal_interface = var.controller_node_internal_interface
        internal_ip_address = var.controller_node_internal_ip_address
        internal_ip_address_prefix_length = var.controller_node_internal_ip_address_prefix_length
        external_interface = var.controller_node_external_interface
        external_ip_address = var.controller_node_external_ip_address
        external_ip_address_prefix_length = var.controller_node_external_ip_address_prefix_length
        external_gateway_ip_address = var.openstack_external_subnet_pool_gateway
    }
}

data "template_file" "install_reconfigure_network_template_compute" {
    depends_on = [
        null_resource.pre_check_iface_controller_node_external_vip
    ]

    template = file("${path.root}/netplan/999-netplan_openstack.tpl")

    vars = {
        internal_interface = var.compute_node_internal_interface
        internal_ip_address = var.compute_node_internal_ip_address
        internal_ip_address_prefix_length = var.compute_node_internal_ip_address_prefix_length
        external_interface = var.compute_node_external_interface
        external_ip_address = var.compute_node_external_ip_address
        external_ip_address_prefix_length = var.compute_node_external_ip_address_prefix_length
        external_gateway_ip_address = var.openstack_external_subnet_pool_gateway
    }
}

resource "null_resource" "install_reconfigure_network_controller" {
    depends_on = [
        data.template_file.install_reconfigure_network_template_controller
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "file" {
        content     = data.template_file.install_reconfigure_network_template_controller.rendered
        destination = "/etc/netplan/999-netplan_openstack.yaml"
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "netplan apply"
        ]
    }

    provisioner "local-exec" {
        command = <<-EOT
        /bin/bash -c '
        sleep ${local.network_reconfigure_wait_time_seconds}
        '
        EOT
    }
}

resource "null_resource" "install_reconfigure_network_compute" {
    depends_on = [
        data.template_file.install_reconfigure_network_template_compute
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.compute_node_internal_ip_address
    }

    provisioner "file" {
        content     = data.template_file.install_reconfigure_network_template_compute.rendered
        destination = "/etc/netplan/999-netplan_openstack.yaml"
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "netplan apply"
        ]
    }

    provisioner "local-exec" {
        command = <<-EOT
        /bin/bash -c '
        sleep ${local.network_reconfigure_wait_time_seconds}
        '
        EOT
    }
}

############ Software Updates ############
resource "null_resource" "software_updates_stop_unattended_upgrades" {
    depends_on = [
        null_resource.install_reconfigure_network_controller,
        null_resource.install_reconfigure_network_compute
    ]

    for_each = local.hosts_ips

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = each.key
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "systemctl stop unattended-upgrades"
        ]
    }
}

resource "null_resource" "software_updates_apt_upgrade" {
    depends_on = [
        null_resource.software_updates_stop_unattended_upgrades
    ]

    for_each = local.hosts_ips

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = each.key
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "apt update",
            "apt upgrade -y",
            "apt dist-upgrade -y"
        ]
    }
}

############### hosts_init ###############
resource "null_resource" "install_hosts_init_setup_hostname_controller" {
    depends_on = [
        null_resource.software_updates_apt_upgrade
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Setting controller node's hostname...\"",
            "hostnamectl set-hostname ${var.controller_node_hostname}",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to set controller node's hostname.\"",
            "  exit 1",
            "fi",
            "sed -i '/'\"127.0.1.1\"'/d' /etc/hosts",
            "echo \"127.0.1.1 ${var.controller_node_hostname}\" >> /etc/hosts"
        ]
    }
}

resource "null_resource" "install_hosts_init_setup_hosts_file_controller" {
    depends_on = [
        null_resource.install_hosts_init_setup_hostname_controller
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Writing hosts file...\"",
            "sed -i '/'\"${var.compute_node_internal_ip_address}\"' '\"${var.compute_node_hostname}\"'/d' /etc/hosts",
            "echo \"${var.compute_node_internal_ip_address} ${var.compute_node_hostname}\" >> /etc/hosts",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to write hosts file.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "install_hosts_install_sshpass" {
    depends_on = [
        null_resource.install_hosts_init_setup_hosts_file_controller
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "apt update && apt install -y sshpass"
        ]
    }
}

resource "null_resource" "install_hosts_init_register_ssh_key" {
    depends_on = [
        null_resource.install_hosts_install_sshpass
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Getting SSH public key from compute node...\"",
            "echo \"y\" | ssh-keygen -t rsa -q -f \"$HOME/.ssh/id_rsa\" -N \"\"",
            "sed -i '/'\"${var.compute_node_hostname}\"'/d' ~/.ssh/known_hosts > /dev/null 2>&1",
            "sed -i '/'\"${var.compute_node_internal_ip_address}\"'/d' ~/.ssh/known_hosts > /dev/null 2>&1",
            "ssh-keyscan -t rsa ${var.compute_node_hostname} >> ~/.ssh/known_hosts",
            "ssh-keyscan -t rsa ${var.compute_node_internal_ip_address} >> ~/.ssh/known_hosts",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to get SSH public key from compute node.\"",
            "  exit 1",
            "fi",
            "echo \"[*] Registering controller node's SSH key to compute node...\"",
            "sshpass -p \"${var.openstack_nodes_ssh_root_password}\" ssh-copy-id root@${var.compute_node_hostname}",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to register controller node's SSH key to compute node.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "install_hosts_init_setup_hostname_compute" {
    depends_on = [
        null_resource.install_hosts_init_register_ssh_key
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.compute_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Setting compute node's hostname...\"",
            "hostnamectl set-hostname ${var.compute_node_hostname}",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to set compute node's hostname.\"",
            "  exit 1",
            "fi",
            "sed -i '/'\"127.0.1.1\"'/d' /etc/hosts",
            "echo \"127.0.1.1 ${var.compute_node_hostname}\" >> /etc/hosts"
        ]
    }
}

resource "null_resource" "install_hosts_init_setup_hosts_file_compute" {
    depends_on = [
        null_resource.install_hosts_init_setup_hostname_compute
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.compute_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Modifyting compute node's hosts file...\"",
            "sed -i '/'\"${var.controller_node_internal_ip_address}\"' '\"${var.controller_node_hostname}\"'/d' /etc/hosts",
            "echo \"${var.controller_node_internal_ip_address} ${var.controller_node_hostname}\" >> /etc/hosts",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to modify compute node's hosts file.\"",
            "  exit 1",
            "fi"
        ]
    }
}

############## Kolla Ansible #############
resource "null_resource" "install_kolla_ansible_install_needed_apt_packages" {
    depends_on = [
        null_resource.install_hosts_init_setup_hosts_file_compute
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Installing needed packages for Kolla Ansible...\"",
            "apt update && apt install -y python3-dev libffi-dev gcc libssl-dev python3-pip git",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to install needed packages for Kolla Ansible.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "install_kolla_ansible_install_needed_python_packages" {
    depends_on = [
        null_resource.install_kolla_ansible_install_needed_apt_packages
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Installing pip...\"",
            "pip3 install -U pip",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to install pip.\"",
            "  exit 1",
            "fi",
            "echo \"[*] Installing pbr...\"",
            "pip3 install -U pbr",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to install pbr.\"",
            "  exit 1",
            "fi",
            "echo \"[*] Installing Ansible...\"",
            "pip3 install ansible==8.7.0",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to install Ansible.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "install_kolla_ansible_install_kolla" {
    depends_on = [
        null_resource.install_kolla_ansible_install_needed_python_packages
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    # Use cloned kolla-ansible folder
    # Remote: https://opendev.org/openstack/kolla-ansible
    # Branch: stable/zed
    # Commit Hash: 033da7aa309aa25f3f4e6bdbb26f574c80819168

    # echo "[*] Cleaning Kolla Ansible folder..."
    # git clone --branch stable/zed https://opendev.org/openstack/kolla-ansible $RUN_PATH/kolla-ansible
    # STATUS=`echo $?`
    # if [ $STATUS != 0 ]; then
    #   echo "[!] Failed to clone Kolla Ansible."
    #   exit 1
    # fi

    provisioner "file" {
        source      = "${path.root}/kolla-ansible.tar.gz"
        destination = "${local.openstack_tmp_dir}/kolla-ansible.tar.gz"
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "if [ ! -d \"${local.openstack_tmp_dir}/kolla-ansible\" ]; then",
            "  tar xvf ${local.openstack_tmp_dir}/kolla-ansible.tar.gz -C ${local.openstack_tmp_dir}/",
            "fi",
            "git config --global --add safe.directory ${local.openstack_tmp_dir}/kolla-ansible",
            "pip3 install ${local.openstack_tmp_dir}/kolla-ansible",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to install Kolla Ansible.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "install_kolla_ansible_create_ansible_default_config_file" {
    depends_on = [
        null_resource.install_kolla_ansible_install_kolla
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Creating Ansible default configuration file...\"",
            "mkdir -p /etc/ansible/",
            "echo -n '[defaults]",
            "host_key_checking=False",
            "pipelining=True",
            "forks=100",
            "' > /etc/ansible/ansible.cfg",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to create Ansible default configuration file (/etc/ansible/ansible.cfg).\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "install_kolla_ansible_copy_kolla_ansible_configuration_files" {
    depends_on = [
        null_resource.install_kolla_ansible_create_ansible_default_config_file
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Setting Kolla Ansible configuration files...\"",
            "mkdir -p /etc/kolla",
            "cp -rf ${local.openstack_tmp_dir}/kolla-ansible/etc/kolla/* /etc/kolla",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Error occured while copying Kolla Ansible configuration files.\"",
            "  exit 1",
            "fi",
            "cp -f ${local.openstack_tmp_dir}/kolla-ansible/ansible/inventory/multinode ${local.openstack_tmp_dir}/",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Error occured while copying Kolla Ansible inventory files.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "install_kolla_ansible_configure_kolla_ansible_inventory_file" {
    depends_on = [
        null_resource.install_kolla_ansible_copy_kolla_ansible_configuration_files
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Setting Kolla Ansible inventory file...\"",
            "COMPUTE_NODE_WITH_SSH=\"${var.compute_node_hostname} ansible_connection=ssh\"",
            "sed -i \"/^#/d\" ${local.openstack_tmp_dir}/multinode",
            "sed -i \"/^$/N;/^\\n$/D\" ${local.openstack_tmp_dir}/multinode",
            "sed -i \"/\\[control\\]/,/\\[/{/^control[0-9]/d}\" ${local.openstack_tmp_dir}/multinode",
            "sed -i \"/\\[network\\]/,/\\[/{/^network[0-9]/d}\" ${local.openstack_tmp_dir}/multinode",
            "sed -i \"/\\[compute\\]/,/\\[/{/^compute[0-9]/d}\" ${local.openstack_tmp_dir}/multinode",
            "sed -i \"/\\[monitoring\\]/,/\\[/{/^monitoring[0-9]/d}\" ${local.openstack_tmp_dir}/multinode",
            "sed -i \"/\\[storage\\]/,/\\[/{/^storage[0-9]/d}\" ${local.openstack_tmp_dir}/multinode",
            "sed -i \"/\\[control\\]/a localhost\" ${local.openstack_tmp_dir}/multinode",
            "sed -i \"/\\[network\\]/a localhost\" ${local.openstack_tmp_dir}/multinode",
            "sed -i \"/\\[monitoring\\]/a localhost\" ${local.openstack_tmp_dir}/multinode",
            "sed -i \"/\\[storage\\]/a localhost\" ${local.openstack_tmp_dir}/multinode",
            "sed -i \"/\\[compute\\]/a $${COMPUTE_NODE_WITH_SSH}\" ${local.openstack_tmp_dir}/multinode",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Error occured while setting Kolla Ansible inventory file.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "deploy_openstack_generate_kolla_passwords" {
    depends_on = [
        null_resource.install_kolla_ansible_configure_kolla_ansible_inventory_file
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Generating Kolla Ansible password file...\"",
            "kolla-genpwd",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to generate Kolla Ansible password file.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "install_kolla_ansible_configure_kolla_ansible_password_file" {
    depends_on = [
        null_resource.deploy_openstack_generate_kolla_passwords
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Configuring Kolla Ansible password file...\"",
            "sed -i '/cinder_database_password/d' /etc/kolla/passwords.yml",
            "sed -i '/database_password/d' /etc/kolla/passwords.yml",
            "sed -i '/glance_database_password/d' /etc/kolla/passwords.yml",
            "sed -i '/heat_database_password/d' /etc/kolla/passwords.yml",
            "sed -i '/horizon_database_password/d' /etc/kolla/passwords.yml",
            "sed -i '/keystone_admin_password/d' /etc/kolla/passwords.yml",
            "sed -i '/keystone_database_password/d' /etc/kolla/passwords.yml",
            "sed -i '/neutron_database_password/d' /etc/kolla/passwords.yml",
            "sed -i '/nova_api_database_password/d' /etc/kolla/passwords.yml",
            "sed -i '/nova_database_password/d' /etc/kolla/passwords.yml",
            "sed -i '/placement_database_password/d' /etc/kolla/passwords.yml",
            "sed -i '/octavia_ca_password/d' /etc/kolla/passwords.yml",
            "sed -i '/octavia_client_ca_password/d' /etc/kolla/passwords.yml",
            "sed -i '/octavia_database_password/d' /etc/kolla/passwords.yml",
            "sed -i '/octavia_persistence_database_password/d' /etc/kolla/passwords.yml",
            "sed -i '/octavia_keystone_password/d' /etc/kolla/passwords.yml",
            "echo \"cinder_database_password: ${var.openstack_databases_password}\" >> /etc/kolla/passwords.yml",
            "echo \"database_password: ${var.openstack_databases_password}\" >> /etc/kolla/passwords.yml",
            "echo \"glance_database_password: ${var.openstack_databases_password}\" >> /etc/kolla/passwords.yml",
            "echo \"heat_database_password: ${var.openstack_databases_password}\" >> /etc/kolla/passwords.yml",
            "echo \"horizon_database_password: ${var.openstack_databases_password}\" >> /etc/kolla/passwords.yml",
            "echo \"keystone_admin_password: ${var.openstack_keystone_admin_password}\" >> /etc/kolla/passwords.yml",
            "echo \"keystone_database_password: ${var.openstack_databases_password}\" >> /etc/kolla/passwords.yml",
            "echo \"neutron_database_password: ${var.openstack_databases_password}\" >> /etc/kolla/passwords.yml",
            "echo \"nova_api_database_password: ${var.openstack_databases_password}\" >> /etc/kolla/passwords.yml",
            "echo \"nova_database_password: ${var.openstack_databases_password}\" >> /etc/kolla/passwords.yml",
            "echo \"placement_database_password: ${var.openstack_databases_password}\" >> /etc/kolla/passwords.yml",
            "echo \"octavia_ca_password: ${var.openstack_octavia_ca_password}\" >> /etc/kolla/passwords.yml",
            "echo \"octavia_client_ca_password: ${var.openstack_octavia_client_ca_password}\" >> /etc/kolla/passwords.yml",
            "echo \"octavia_database_password: ${var.openstack_databases_password}\" >> /etc/kolla/passwords.yml",
            "echo \"octavia_persistence_database_password: ${var.openstack_databases_password}\" >> /etc/kolla/passwords.yml",
            "echo \"octavia_keystone_password: ${var.openstack_octavia_keystone_password}\" >> /etc/kolla/passwords.yml",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to configure Kolla Ansible password file.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "install_kolla_ansible_configure_kolla_ansible_global_variables" {
    depends_on = [
        null_resource.install_kolla_ansible_configure_kolla_ansible_password_file
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Configuring Kolla Ansible global variables...\"",
            "mkdir -p /etc/kolla/globals.d/",
            "cp -f /etc/kolla/globals.yml /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^kolla_base_distro:.*/kolla_base_distro: \"ubuntu\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#kolla_base_distro:.*/kolla_base_distro: \"ubuntu\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^network_interface:.*/network_interface: '\"${var.controller_node_internal_interface}\"'/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#network_interface:.*/network_interface: '\"${var.controller_node_internal_interface}\"'/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^kolla_external_vip_interface::.*/kolla_external_vip_interface: '\"${var.controller_node_external_interface}\"'/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#kolla_external_vip_interface:.*/kolla_external_vip_interface: '\"${var.controller_node_external_interface}\"'/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^neutron_external_interface:.*/neutron_external_interface: '\"${var.controller_node_external_interface}\"'/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#neutron_external_interface:.*/neutron_external_interface: '\"${var.controller_node_external_interface}\"'/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^kolla_internal_vip_address:.*/kolla_internal_vip_address: '\"${var.openstack_vip_internal}\"'/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#kolla_internal_vip_address:.*/kolla_internal_vip_address: '\"${var.openstack_vip_internal}\"'/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^kolla_external_vip_address:.*/kolla_external_vip_address: '\"${var.openstack_vip_external}\"'/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#kolla_external_vip_address:.*/kolla_external_vip_address: '\"${var.openstack_vip_external}\"'/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^docker_registry_insecure:.*/docker_registry_insecure: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#docker_registry_insecure:.*/docker_registry_insecure: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^kolla_enable_tls_internal:.*/kolla_enable_tls_internal: \"no\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#kolla_enable_tls_internal:.*/kolla_enable_tls_internal: \"no\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^kolla_enable_tls_external:.*/kolla_enable_tls_external: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#kolla_enable_tls_external:.*/kolla_enable_tls_external: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^kolla_copy_ca_into_containers:.*/kolla_copy_ca_into_containers: \"no\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#kolla_copy_ca_into_containers:.*/kolla_copy_ca_into_containers: \"no\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^kolla_enable_tls_backend:.*/kolla_enable_tls_backend: \"no\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#kolla_enable_tls_backend:.*/kolla_enable_tls_backend: \"no\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^kolla_verify_tls_backend:.*/kolla_verify_tls_backend: \"no\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#kolla_verify_tls_backend:.*/kolla_verify_tls_backend: \"no\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^enable_cinder:.*/enable_cinder: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#enable_cinder:.*/enable_cinder: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^enable_cinder_backup:.*/enable_cinder_backup: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#enable_cinder_backup:.*/enable_cinder_backup: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^enable_cinder_backend_nfs:.*/enable_cinder_backend_nfs: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#enable_cinder_backend_nfs:.*/enable_cinder_backend_nfs: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^enable_neutron_provider_networks:.*/enable_neutron_provider_networks: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#enable_neutron_provider_networks:.*/enable_neutron_provider_networks: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^enable_octavia:.*/enable_octavia: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#enable_octavia:.*/enable_octavia: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^enable_openvswitch:.*/enable_openvswitch: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#enable_openvswitch:.*/enable_openvswitch: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^enable_ovn:.*/enable_ovn: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#enable_ovn:.*/enable_ovn: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^enable_redis:.*/enable_redis: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#enable_redis:.*/enable_redis: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^neutron_ovn_distributed_fip:.*/neutron_ovn_distributed_fip: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i 's/^#neutron_ovn_distributed_fip:.*/neutron_ovn_distributed_fip: \"yes\"/g' /etc/kolla/globals.d/globals.yml",
            "sed -i '/neutron_plugin_agent/d' /etc/kolla/globals.d/globals.yml",
            "echo 'neutron_plugin_agent: \"ovn\"' >> /etc/kolla/globals.d/globals.yml",
            "sed -i '/openstack_cacert/d' /etc/kolla/globals.d/globals.yml",
            "echo 'openstack_cacert: \"/etc/ssl/certs/ca-certificates.crt\"' >> /etc/kolla/globals.d/globals.yml",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to configure Kolla Ansible global variables...\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "install_kolla_ansible_generate_certificates" {
    depends_on = [
        null_resource.install_kolla_ansible_configure_kolla_ansible_global_variables
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Generating certificates...\"",
            "kolla-ansible certificates",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Kolla Ansible certificates failed.\"",
            "  exit 1",
            "fi"
        ]
    }
}

############ NFS Configuration ###########
resource "null_resource" "nfs_configuration_install_nfs_apt_packages" {
    depends_on = [
        null_resource.install_kolla_ansible_generate_certificates
    ]

    for_each = local.hosts_ips

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = each.key
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Setting NFS client...\"",
            "apt update && apt install -y nfs-common",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to install nfs-common.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "nfs_configuration_configure_controller_node" {
    depends_on = [
        null_resource.nfs_configuration_install_nfs_apt_packages
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Creating cinder NFS configuration file...\"",
            "mkdir -p /etc/kolla/config/",
            "echo \"${var.openstack_cinder_volumes_nfs_target}\" > /etc/kolla/config/nfs_shares",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to create cinder NFS configuration file.\"",
            "  exit 1",
            "fi",
            "echo \"[*] Adding Glance Images NFS target to fstab...\"",
            "sed -i '/glance/d' /etc/fstab",
            "echo \"${var.openstack_glance_images_nfs_target} /var/lib/docker/volumes/glance/_data/images nfs defaults,_netdev 0 0\" >> /etc/fstab",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to modify controller node's fstab file.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "nfs_configuration_configure_compute_node" {
    depends_on = [
        null_resource.nfs_configuration_configure_controller_node
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.compute_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Adding Nova Compute NFS target to fstab...\"",
            "sed -i '/nova_compute/d' /etc/fstab",
            "echo \"${var.openstack_nova_compute_instances_nfs_target} /var/lib/docker/volumes/nova_compute/_data/instances nfs defaults,_netdev 0 0\" >> /etc/fstab",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to modify compute node's fstab file.\"",
            "  exit 1",
            "fi"
        ]
    }
}

############# Deploy Openstack ###########
resource "null_resource" "deploy_openstack_bootstrap_servers" {
    depends_on = [
        null_resource.nfs_configuration_configure_compute_node
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Bootstrapping servers...\"",
            "kolla-ansible install-deps",
            "kolla-ansible -i ${local.openstack_tmp_dir}/multinode bootstrap-servers",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Kolla Ansible bootstrap failed.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "deploy_openstack_generate_octavia_certificates" {
    depends_on = [
        null_resource.deploy_openstack_bootstrap_servers
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Generating octavia certificates...\"",
            "kolla-ansible octavia-certificates",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Kolla Ansible octavia-certificates failed.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "deploy_openstack_run_prechecks" {
    depends_on = [
        null_resource.deploy_openstack_generate_octavia_certificates
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Running precheks...\"",
            "kolla-ansible -i ${local.openstack_tmp_dir}/multinode prechecks",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Kolla Ansible prechecks failed.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "deploy_openstack_run_pull" {
    depends_on = [
        null_resource.deploy_openstack_run_prechecks
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Running precheks...\"",
            "kolla-ansible -i ${local.openstack_tmp_dir}/multinode pull",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Kolla Ansible pull failed.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "deploy_openstack_run_deploy" {
    depends_on = [
        null_resource.deploy_openstack_run_pull
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Deploying OpenStack...\"",
            "kolla-ansible -i ${local.openstack_tmp_dir}/multinode deploy",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Kolla Ansible deploy failed.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "deploy_openstack_configure_external_interface_controller_node" {
    depends_on = [
        null_resource.deploy_openstack_run_deploy
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Configuring Controller Node's External Interface...\"",
            "sed -i 's/'\"${var.controller_node_external_interface}\"'/br-ex/g' /etc/netplan/*.yaml",
            "sed -i 's/'\"${var.openstack_vip_external}\"' dev '\"${var.controller_node_external_interface}\"'/'\"${var.openstack_vip_external}\"' dev br-ex/g' /etc/kolla/keepalived/keepalived.conf",
            "echo \"    ${var.controller_node_external_interface}: {}\" >> /etc/netplan/999-netplan_openstack.yaml",
            "netplan apply",
            "ip address del ${var.controller_node_external_ip_address}/${var.controller_node_external_ip_address_prefix_length} dev ${var.controller_node_external_interface} > /dev/null 2>&1 | true"
        ]
    }
}

resource "null_resource" "deploy_openstack_configure_external_interface_compute_node" {
    depends_on = [
        null_resource.deploy_openstack_configure_external_interface_controller_node
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.compute_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Configuring Compute Node's External Interface...\"",
            "sed -i 's/'\"${var.compute_node_external_interface}\"'/br-ex/g' /etc/netplan/*.yaml",
            "echo \"    ${var.compute_node_external_interface}: {}\" >> /etc/netplan/999-netplan_openstack.yaml",
            "netplan apply",
            "ip address del ${var.compute_node_external_ip_address}/${var.compute_node_external_ip_address_prefix_length} dev ${var.compute_node_external_interface} > /dev/null 2>&1 | true"
        ]
    }
}

############### Mount All ################
resource "null_resource" "mount_all_in_fstab" {
    depends_on = [
        null_resource.deploy_openstack_configure_external_interface_compute_node
    ]

    for_each = local.hosts_ips

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = each.key
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Mounting all of filesystems in /etc/fstab...\"",
            "mount -a",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] WARNING: Error occurred while mounting filesystems in /etc/fstab.\"",
            "  echo \"Please check your connection of the NFS server!\"",
            "fi"
        ]
    }
}

##########################################
# Fix issues
##########################################

####### Fix NFS Mount on Boot Issue ######
resource "null_resource" "fix_issues_nfs_mount_on_boot_issue" {
    depends_on = [
        null_resource.mount_all_in_fstab
    ]

    for_each = local.hosts_ips

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = each.key
    }

    provisioner "file" {
        source      = "${path.root}/post-install/rc.local/rc-local.service"
        destination = "/lib/systemd/system/rc-local.service"
    }

    provisioner "file" {
        source      = "${path.root}/post-install/rc.local/rc.local"
        destination = "/etc/rc.local"
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "chmod 755 /etc/rc.local",
            "systemctl daemon-reload",
            "systemctl enable rc-local.service",
            "systemctl restart rc-local.service"
        ]
    }
}

####### Fix Instance Create Timeout Issue ######
resource "null_resource" "fix_issues_instance_create_timeout_issue" {
    depends_on = [
        null_resource.fix_issues_nfs_mount_on_boot_issue
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.compute_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "sed -i '/block_device_allocate_retries/d' /etc/kolla/nova-compute/nova.conf",
            "sed -i '/block_device_allocate_retries_interval/d' /etc/kolla/nova-compute/nova.conf",
            "sed -i 's/\\[DEFAULT\\]/& \\nblock_device_allocate_retries = 1800\\nblock_device_allocate_retries_interval = 6/' /etc/kolla/nova-compute/nova.conf",
            "docker restart nova_compute"
        ]
    }
}

resource "null_resource" "fix_issues_glance_cors" {
    depends_on = [
        null_resource.fix_issues_instance_create_timeout_issue
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.compute_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "sed -i '/allowed_origin/d' /etc/kolla/glance-api/glance-api.conf",
            "sed -i 's/\\[cors\\]/& \\nallowed_origin = \\*/' /etc/kolla/glance-api/glance-api.conf",
            "docker restart glance_api"
        ]
    }
}

##########################################
# post-install
##########################################

######## Install OpenStack Client ########
resource "null_resource" "post_install_openstack_client_openstackclient" {
    depends_on = [
        null_resource.fix_issues_glance_cors
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Installing openstackclient...\"",
            "pip3 install python-openstackclient",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to install openstackclient.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "post_install_openstack_client_neutronclient" {
    depends_on = [
        null_resource.post_install_openstack_client_openstackclient
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Installing neutronclient...\"",
            "pip3 install python-neutronclient",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to install neutronclient.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "post_install_openstack_client_glanceclient" {
    depends_on = [
        null_resource.post_install_openstack_client_neutronclient
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Installing glanceclient...\"",
            "pip3 install python-glanceclient",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to install glanceclient.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "post_install_openstack_client_cryptography" {
    depends_on = [
        null_resource.post_install_openstack_client_glanceclient
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Installing cryptography...\"",
            "pip3 install cryptography==2.7.0",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to install cryptography.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "post_install_openstack_client_post_deploy" {
    depends_on = [
        null_resource.post_install_openstack_client_cryptography
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Running post-deploy...\"",
            "kolla-ansible post-deploy",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Kolla Ansible post-deploy failed.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "post_install_openstack_client_register_initialize_script" {
    depends_on = [
        null_resource.post_install_openstack_client_post_deploy
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Registering OpenStack client initialize script to '.bashrc'...\"",
            "sed -i '/source \\/etc\\/kolla\\/admin-openrc.sh/d' ~/.bashrc",
            "echo \"source /etc/kolla/admin-openrc.sh\" >> ~/.bashrc",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Failed to register OpenStack client initialize script to '.bashrc'.\"",
            "  exit 1",
            "fi"
        ]
    }
}

############## Hosts Cleanup #############
resource "null_resource" "post_install_hosts_cleanup_controller" {
    depends_on = [
        null_resource.post_install_openstack_client_register_initialize_script
    ]

    for_each = local.hosts_ips

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = each.key
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "echo \"[*] Cleaning up hosts file ...\"",
            "sed -i '/^#*.*ANSIBLE GENERATED*.*/d' /etc/hosts",
            "sed -i '/'\"${var.controller_node_internal_ip_address}\"'/d' /etc/hosts",
            "sed -i '/'\"${var.controller_node_hostname}\"'/d' /etc/hosts",
            "sed -i '/'\"${var.compute_node_internal_ip_address}\"'/d' /etc/hosts",
            "sed -i '/'\"${var.compute_node_hostname}\"'/d' /etc/hosts",
            "echo \"${var.controller_node_internal_ip_address} ${var.controller_node_hostname}\" >> /etc/hosts",
            "echo \"${var.compute_node_internal_ip_address} ${var.compute_node_hostname}\" >> /etc/hosts"
        ]
    }
}



######### Setup OpenStack Network ########
resource "null_resource" "post_install_setup_openstack_network_create_external_network" {
    depends_on = [
        null_resource.post_install_hosts_cleanup_controller
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". /etc/kolla/admin-openrc.sh",
            "echo \"[*] Creating OpenStack external network...\"",
            "openstack network create --project admin --external --provider-network-type flat --provider-physical-network physnet1 external",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Error occurred while creating OpenStack external network.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "post_install_setup_openstack_network_create_external_subnet" {
    depends_on = [
        null_resource.post_install_setup_openstack_network_create_external_network
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". /etc/kolla/admin-openrc.sh",
            "echo \"[*] Creating OpenStack external subnet...\"",
            "openstack subnet create --network external --no-dhcp --allocation-pool start=${var.openstack_external_subnet_pool_start_ip_address},end=${var.openstack_external_subnet_pool_end_ip_address} --subnet-range ${var.openstack_external_subnet_range} --gateway=${var.openstack_external_subnet_pool_gateway} external_subnet",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Error occurred while creating OpenStack external subnet.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "post_install_setup_openstack_network_create_internal_network" {
    depends_on = [
        null_resource.post_install_setup_openstack_network_create_external_subnet
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". /etc/kolla/admin-openrc.sh",
            "echo \"[*] Creating OpenStack internal network...\"",
            "openstack network create --internal internal",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Error occurred while creating OpenStack internal network.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "post_install_setup_openstack_network_create_internal_subnet" {
    depends_on = [
        null_resource.post_install_setup_openstack_network_create_internal_network
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". /etc/kolla/admin-openrc.sh",
            "echo \"[*] Creating OpenStack internal subnet...\"",
            "openstack subnet create --dhcp --subnet-range ${var.openstack_internal_subnet_range} --gateway ${var.openstack_internal_subnet_gateway} --network internal internal_subnet",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Error occurred while creating OpenStack internal subnet.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "post_install_setup_openstack_network_create_openstack_router" {
    depends_on = [
        null_resource.post_install_setup_openstack_network_create_internal_subnet
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". /etc/kolla/admin-openrc.sh",
            "echo \"[*] Creating OpenStack router...\"",
            "openstack router create external-router",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Error occurred while creating OpenStack router.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "post_install_setup_openstack_network_setting_openstack_router" {
    depends_on = [
        null_resource.post_install_setup_openstack_network_create_openstack_router
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". /etc/kolla/admin-openrc.sh",
            "echo \"[*] Setting OpenStack router...\"",
            "ROUTER_SNAT_OPTION=\"--disable-snat\"",
            "ENABLE_ROUTER_SNAT=`echo \"${var.openstack_router_enable_snat}\" | tr '[:upper:]' '[:lower:]'`",
            "if [ \"$ENABLE_ROUTER_SNAT\" = \"true\" ]; then",
            "  ROUTER_SNAT_OPTION=\"--enable-snat\"",
            "fi",
            "openstack router set --external-gateway external $${ROUTER_SNAT_OPTION} external-router",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Error occurred while setting OpenStack router.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "post_install_setup_openstack_network_add_internal_subnet_to_openstack_router" {
    depends_on = [
        null_resource.post_install_setup_openstack_network_setting_openstack_router
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". /etc/kolla/admin-openrc.sh",
            "echo \"[*] Adding internal subnet to OpenStack router...\"",
            "openstack router add subnet external-router internal_subnet",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] Error occurred while setting OpenStack router.\"",
            "  exit 1",
            "fi"
        ]
    }
}

resource "null_resource" "post_install_setup_openstack_network_create_ssh_security_group" {
    depends_on = [
        null_resource.post_install_setup_openstack_network_add_internal_subnet_to_openstack_router
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". /etc/kolla/admin-openrc.sh",
            "echo \"[*] Creating SSH security group...\"",
            "openstack security group create SSH",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] WARN: Error occurred while creating SSH security group.\"",
            "fi"
        ]
    }
}

resource "null_resource" "post_install_setup_openstack_network_create_ssh_ingress_rule_to_ssh_security_group" {
    depends_on = [
        null_resource.post_install_setup_openstack_network_create_ssh_security_group
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". /etc/kolla/admin-openrc.sh",
            "echo \"[*] Creating SSH ingress rule to SSH security group...\"",
            "openstack security group rule create --protocol tcp --dst-port 22 --ingress SSH",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] WARN: Error occurred while creating SSH ingress rule to SSH security group.\"",
            "fi"
        ]
    }
}

resource "null_resource" "post_install_setup_openstack_network_create_icmp_ingress_rule_to_ssh_security_group" {
    depends_on = [
        null_resource.post_install_setup_openstack_network_create_ssh_ingress_rule_to_ssh_security_group
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". /etc/kolla/admin-openrc.sh",
            "echo \"[*] Creating ICMP ingress rule to SSH security group...\"",
            "openstack security group rule create --protocol icmp --ingress SSH",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] WARN: Error occurred while creating ICMP ingress rule to SSH security group.\"",
            "fi"
        ]
    }
}

############ Create Test Image ###########
resource "null_resource" "post_install_create_test_image" {
    depends_on = [
        null_resource.post_install_setup_openstack_network_create_icmp_ingress_rule_to_ssh_security_group
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            "if [ \"${var.openstack_create_cirros_test_image}\" = \"false\" ]; then",
            "  exit 0",
            "fi",
            "echo \"[*] Downloading CirrOS image (Version: ${var.openstack_cirros_test_image_version})...\"",
            "wget http://download.cirros-cloud.net/${var.openstack_cirros_test_image_version}/cirros-${var.openstack_cirros_test_image_version}-x86_64-disk.img -c -O ${local.openstack_tmp_dir}/cirros-${var.openstack_cirros_test_image_version}-x86_64-disk.img",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] WARNING: Failed to download cirros image.\"",
            "fi",
            ". /etc/kolla/admin-openrc.sh",
            "echo \"[*] Creating CirrOS image in OpenStack...\"",
            "openstack image create \"cirros\" --file ${local.openstack_tmp_dir}/cirros-${var.openstack_cirros_test_image_version}-x86_64-disk.img --disk-format qcow2 --container-format bare --public",
            "STATUS=`echo $?`",
            "if [ $STATUS != 0 ]; then",
            "  echo \"[!] WARNING: Failed to create CirrOS image in OpenStack.\"",
            "fi"
        ]
    }
}

############# Create Flavors #############
resource "null_resource" "post_install_create_flavors" {
    depends_on = [
        null_resource.post_install_create_test_image
    ]

    connection {
        type     = "ssh"
        user     = "root"
        password = var.openstack_nodes_ssh_root_password
        host     = var.controller_node_internal_ip_address
    }

    provisioner "remote-exec" {
        inline = [
            "#!/bin/bash",
            ". /etc/kolla/admin-openrc.sh",
            "echo \"[*] Creating OpenStack flavors...\"",
            "openstack flavor create m1.tiny --id m1.tiny --ram 1024 --disk 10 --vcpus 1",
            "openstack flavor create m1.small --id m1.small --ram 2048 --disk 20 --vcpus 1",
            "openstack flavor create m1.medium --id m1.medium --ram 4096 --disk 40 --vcpus 2",
            "openstack flavor create m1.large --id m1.large --ram 8192 --disk 80 --vcpus 4",
            "openstack flavor create m1.xlarge --id m1.xlarge --ram 16384 --disk 160 --vcpus 8"
        ]
    }
}
