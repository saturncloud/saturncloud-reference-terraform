MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: text/x-shellscript

#!/bin/bash -xe
${pre_userdata}

--BOUNDARY
Content-Type: application/node.eks.aws

# NodeConfig consumed by nodeadm on AL2023
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${cluster_name}
    apiServerEndpoint: ${endpoint}
    certificateAuthority: ${cluster_auth_base64}
    cidr: ${service_ipv4_cidr}
  kubelet:
    # Convert your single string of flags into discrete flags.
    # nodeadm expects a list; each item is one flag string.
    flags:
%{ for f in split(" ", trimspace(kubelet_extra_args)) ~}
      - "${f}"
%{ endfor ~}

--BOUNDARY
Content-Type: text/x-shellscript

#!/bin/bash -xe
# Any post-config shell you previously ran after bootstrap
${additional_userdata}

--BOUNDARY--
