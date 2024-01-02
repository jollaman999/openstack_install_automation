network:
  version: 2
  renderer: networkd
  ethernets:
    ${internal_interface}:
      addresses:
      - ${internal_ip_address}/${internal_ip_address_prefix_length}
    ${external_interface}: {}
    br-ex:
      addresses:
      - ${external_ip_address}/${external_ip_address_prefix_length}
      routes:
        - to: default
          via: ${external_gateway_ip_address}
      nameservers:
        addresses:
        - 1.1.1.1
        - 1.0.0.1
        search: []
