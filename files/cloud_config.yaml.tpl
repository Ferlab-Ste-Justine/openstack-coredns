#cloud-config
users:
  - default
  - name: node-exporter
    system: true
    lock_passwd: true
  - name: coredns
    system: true
    lock_passwd: true
write_files:
  #Prometheus node exporter systemd configuration
  - path: /etc/systemd/system/node-exporter.service
    owner: root:root
    permissions: "0444"
    content: |
      [Unit]
      Description="Prometheus Node Exporter"
      Wants=network-online.target
      After=network-online.target
      StartLimitIntervalSec=0

      [Service]
      User=node-exporter
      Group=node-exporter
      Type=simple
      Restart=always
      RestartSec=1
      ExecStart=/usr/local/bin/node_exporter

      [Install]
      WantedBy=multi-user.target
  #coredns corefile
  - path: /opt/coredns/Corefile
    owner: root:root
    permission: "0444"
    content: |
      ${indent(6, corefile)}
  #Coredns systemd configuration
  - path: /etc/systemd/system/coredns.service
    owner: root:root
    permissions: "0444"
    content: |
      [Unit]
      Description="DNS Service"
      Wants=network-online.target
      After=network-online.target
      StartLimitIntervalSec=0

      [Service]
      User=root
      Group=root
      Type=simple
      Restart=always
      RestartSec=1
      ExecStart=/usr/local/bin/coredns -conf /opt/coredns/Corefile

      [Install]
      WantedBy=multi-user.target
  #Zonefiles refresher code
  - path: /usr/local/bin/zonefiles-refresher
    owner: root:root
    permissions: "0555"
    content: |
      ${indent(6, zonefiles_refresher)}
  #Zonefiles refresher systemd configuration
  - path: /etc/systemd/system/zonefiles-refresher.service
    owner: root:root
    permissions: "0444"
    content: |
      [Unit]
      Description="Zonefiles Updating Service"
      Wants=network-online.target
      After=network-online.target
      StartLimitIntervalSec=0

      [Service]
      Environment=ZONEFILES_CONTAINER=${zonefiles_container}
      Environment=OS_AUTH_TYPE=v3applicationcredential
      Environment=OS_IDENTITY_API_VERSION=3
      Environment=OS_INTERFACE=public
      Environment=OS_AUTH_URL=${openstack_auth_url}
      Environment=OS_REGION_NAME="${openstack_region_name}"
      Environment=OS_APPLICATION_CREDENTIAL_ID=${openstack_application_id}
      Environment=OS_APPLICATION_CREDENTIAL_SECRET=${openstack_application_secret}
      User=root
      Group=root
      Type=simple
      Restart=always
      RestartSec=1
      WorkingDirectory=/opt/coredns/zonefiles
      ExecStart=/usr/local/bin/zonefiles-refresher

      [Install]
      WantedBy=multi-user.target
packages:
  - curl
  - python3-pip
runcmd:
  #Setup zonefiles refresher service
  - pip3 install python-swiftclient==3.10.0 
  - pip3 install python-keystoneclient==4.1.0
  - pip3 install prometheus-client==0.8.0
  - mkdir - p /opt/coredns/zonefiles
  - systemctl enable zonefiles-refresher
  - systemctl start zonefiles-refresher
  #Setup coredns service
  - curl -L https://github.com/coredns/coredns/releases/download/v${coredns_version}/coredns_${coredns_version}_linux_amd64.tgz -o /tmp/coredns_${coredns_version}_linux_amd64.tgz
  - tar xzvf /tmp/coredns_${coredns_version}_linux_amd64.tgz -C /usr/local/bin
  - rm -f /tmp/binaries/coredns_${coredns_version}_linux_amd64.tgz
  - systemctl enable coredns
  - systemctl start coredns
  #Install prometheus node exporter as a binary managed as a systemd service
  - wget -O /opt/node_exporter.tar.gz https://github.com/prometheus/node_exporter/releases/download/v1.0.1/node_exporter-1.0.1.linux-amd64.tar.gz
  - mkdir -p /opt/node_exporter
  - tar zxvf /opt/node_exporter.tar.gz -C /opt/node_exporter
  - cp /opt/node_exporter/node_exporter-1.0.1.linux-amd64/node_exporter /usr/local/bin/node_exporter
  - chown node-exporter:node-exporter /usr/local/bin/node_exporter
  - rm -r /opt/node_exporter && rm /opt/node_exporter.tar.gz
  - systemctl enable node-exporter
  - systemctl start node-exporter