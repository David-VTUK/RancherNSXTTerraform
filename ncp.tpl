apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: nsxerrors.nsx.vmware.com
spec:
  group: nsx.vmware.com
  versions:
    - name: v1
      served: true
      storage: true
  version: v1
  scope: Cluster
  names:
    plural: nsxerrors
    singular: nsxerror
    kind: NSXError
    shortNames:
    - ne
  additionalPrinterColumns:
    - name: Messages
      type: string
      description: NSX error messages. Messages are sorted by timestamp on which the error occurs.
      JSONPath: .spec.message
    - name: ErrorObjectID
      type: string
      description: The identifier of the k8s object which has the errors.
      JSONPath: .spec.error-object-id
    - name: ErrorObjectType
      type: string
      description: The type of the k8s object which has the errors.
      JSONPath: .spec.error-object-type
    - name: ErrorObjectName
      type: string
      description: The name of the k8s object which has the errors.
      JSONPath: .spec.error-object-name
    - name: ErrorObjectNamespace
      type: string
      description: The namespace of the k8s object if it is namespaced. None by default
      JSONPath: .spec.error-object-ns

---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: loadbalancers.vmware.com
spec:
  group: vmware.com
  versions:
    - name: v1alpha1
      served: true
      storage: true
  scope: Cluster
  names:
    plural: loadbalancers
    singular: loadbalancer
    kind: LoadBalancer
    shortNames:
    - lb
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: nsxlbmonitors.vmware.com
spec:
  group: vmware.com
  versions:
    - name: v1alpha1
      served: true
      storage: true
  scope: Cluster
  names:
    plural: nsxlbmonitors
    singular: nsxlbmonitor
    kind: NSXLoadBalancerMonitor
    shortNames:
    - lbm

---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: nsxlocks.nsx.vmware.com
spec:
  group: nsx.vmware.com
  versions:
    - name: v1
      served: true
      storage: true
  version: v1
  scope: Cluster
  names:
    plural: nsxlocks
    singular: nsxlock
    kind: NSXLock
    shortNames:
    - nsxlo

---

# Create Namespace for NSX owned resources
kind: Namespace
apiVersion: v1
metadata:
 name: nsx-system

---

# Create a ServiceAccount for NCP namespace
apiVersion: v1
kind: ServiceAccount
metadata:
 name: ncp-svc-account
 namespace: nsx-system
---

# Create ClusterRole for NCP
kind: ClusterRole
# Set the apiVersion to rbac.authorization.k8s.io/v1beta1 when k8s < v1.8
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 name: ncp-cluster-role
rules:
 - apiGroups:
   - ""
   - extensions
   - networking.k8s.io
   resources:
     - deployments
     - endpoints
     - pods
     - pods/log
     - networkpolicies
     - nodes
     - replicationcontrollers
     # Remove 'secrets' if not using Native Load Balancer.
     - secrets

   verbs:
     - get
     - watch
     - list

---

# Create ClusterRole for NCP to edit resources
kind: ClusterRole
# Set the apiVersion to rbac.authorization.k8s.io/v1beta1 when k8s < v1.8
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 name: ncp-patch-role
rules:
 - apiGroups:
   - ""
   - extensions
   resources:
     # NCP needs to annotate the SNAT errors on namespaces
     - namespaces
     - ingresses
     - services

   verbs:
     - get
     - watch
     - list
     - update
     - patch
 # NCP needs permission to CRUD custom resource nsxerrors
 - apiGroups:
   # The api group is specified in custom resource definition for nsxerrors
   - nsx.vmware.com
   resources:
     - nsxerrors

     - nsxlocks
   verbs:
     - create
     - get
     - list
     - patch
     - delete

     - update
 - apiGroups:
   - ""
   - extensions

   resources:
     - ingresses/status
     - services/status


   verbs:
     - replace
     - update
     - patch

 - apiGroups:
   - vmware.com
   resources:
     - loadbalancers
     - loadbalancers/status
     - nsxlbmonitors
     - nsxlbmonitors/status
   
   verbs:
     - create
     - get
     - list
     - patch
     - delete
     - watch
     - update


---

# Bind ServiceAccount created for NCP to its ClusterRole
kind: ClusterRoleBinding
# Set the apiVersion to rbac.authorization.k8s.io/v1beta1 when k8s < v1.8
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 name: ncp-cluster-role-binding
roleRef:

 # Comment out the apiGroup while using OpenShift
 apiGroup: rbac.authorization.k8s.io

 kind: ClusterRole
 name: ncp-cluster-role
subjects:

 - kind: ServiceAccount
   name: ncp-svc-account
   namespace: nsx-system


---

# Bind ServiceAccount created for NCP to the patch ClusterRole
kind: ClusterRoleBinding
# Set the apiVersion to rbac.authorization.k8s.io/v1beta1 when k8s < v1.8
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 name: ncp-patch-role-binding
roleRef:

 apiGroup: rbac.authorization.k8s.io

 kind: ClusterRole
 name: ncp-patch-role
subjects:

 - kind: ServiceAccount
   name: ncp-svc-account
   namespace: nsx-system


---

# Create a ServiceAccount for nsx-node-agent
apiVersion: v1
kind: ServiceAccount
metadata:
 name: nsx-node-agent-svc-account
 namespace: nsx-system
---

# Create ClusterRole for nsx-node-agent
kind: ClusterRole
# Set the apiVersion to rbac.authorization.k8s.io/v1beta1 when k8s < v1.8
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 name: nsx-node-agent-cluster-role
rules:
 - apiGroups:
   - ""
   resources:
     - endpoints
     - services
   verbs:
     - get
     - watch
     - list

---

# Bind ServiceAccount created for nsx-node-agent to its ClusterRole
kind: ClusterRoleBinding
# Set the apiVersion to rbac.authorization.k8s.io/v1beta1 when k8s < v1.8
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 name: nsx-node-agent-cluster-role-binding
roleRef:

 apiGroup: rbac.authorization.k8s.io

 kind: ClusterRole
 name: nsx-node-agent-cluster-role
subjects:

 - kind: ServiceAccount
   name: nsx-node-agent-svc-account
   namespace: nsx-system

---
# Client certificate and key used for NSX authentication
#kind: Secret
#metadata:
#  name: nsx-secret
#  namespace: nsx-system
#type: kubernetes.io/tls
#apiVersion: v1
#data:
#  # Fill in the client cert and key if using cert based auth with NSX
#  tls.crt:
#  tls.key:
---
# Certificate and key used for TLS termination in HTTPS load balancing
#kind: Secret
#metadata:
#  name: lb-secret
#  namespace: nsx-system
#type: kubernetes.io/tls
#apiVersion: v1
#data:
#  # Fill in the server cert and key for TLS termination
#  tls.crt:
#  tls.key:


---
# Yaml template for NCP Deployment
# Proper kubernetes API and NSX API parameters, and NCP Docker image
# must be specified.
# This yaml file is part of NCP 2.5.1 release.

# ConfigMap for ncp.ini
apiVersion: v1
kind: ConfigMap
metadata:
  name: nsx-ncp-config
  namespace: nsx-system
  labels:
    version: v1
data:
  ncp.ini: |
    
    [DEFAULT]

    # If set to true, the logging level will be set to DEBUG instead of the
    # default INFO level.
    #debug = False

    # If set to true, log output to standard error.
    #use_stderr = True

    # If set to true, use syslog for logging.
    #use_syslog = False

    # The base directory used for relative log_file paths.
    #log_dir = <None>

    # Name of log file to send logging output to.
    #log_file = <None>

    # max MB for each compressed file. Defaults to 100 MB.
    #log_rotation_file_max_mb = 100

    # Total number of compressed backup files to store. Defaults to 5.
    #log_rotation_backup_count = 5




    [nsx_v3]

    # Set NSX API adaptor to NSX Policy API adaptor. If unset, NSX adaptor will
    # be set to the NSX Manager based adaptor.
    policy_nsxapi = True

    nsx_api_user = ${nsx_api_user} 
    nsx_api_password = ${nsx_api_password}



    # Path to NSX client certificate file. If specified, the nsx_api_user and
    # nsx_api_password options will be ignored. Must be specified along with
    # nsx_api_private_key_file option
    #nsx_api_cert_file = <None>

    # Path to NSX client private key file. If specified, the nsx_api_user and
    # nsx_api_password options will be ignored. Must be specified along with
    # nsx_api_cert_file option
    #nsx_api_private_key_file = <None>

    # IP address of one or more NSX managers separated by commas. The IP
    # address should be of the form:
    # [<scheme>://]<ip_adress>[:<port>]
    # If
    # scheme is not provided https is used. If port is not provided port 80 is
    # used for http and port 443 for https.
    nsx_api_managers = ${nsx_api_managers}

    # If True, skip fatal errors when no endpoint in the NSX management cluster
    # is available to serve a request, and retry the request instead
    #cluster_unavailable_retry = False

    # Maximum number of times to retry API requests upon stale revision errors.
    #retries = 10

    # Specify one or a list of CA bundle files to use in verifying the NSX
    # Manager server certificate. This option is ignored if "insecure" is set
    # to True. If "insecure" is set to False and ca_file is unset, the system
    # root CAs will be used to verify the server certificate.
    #ca_file = []

    # If true, the NSX Manager server certificate is not verified. If false the
    # CA bundle specified via "ca_file" will be used or if unset the default
    # system root CAs will be used.
    insecure = True

    # The time in seconds before aborting a HTTP connection to a NSX manager.
    #http_timeout = 10

    # The time in seconds before aborting a HTTP read response from a NSX
    # manager.
    #http_read_timeout = 180

    # Maximum number of times to retry a HTTP connection.
    #http_retries = 3

    # Maximum concurrent connections to each NSX manager.
    #concurrent_connections = 10

    # The amount of time in seconds to wait before ensuring connectivity to the
    # NSX manager if no manager connection has been used.
    #conn_idle_timeout = 10

    # Number of times a HTTP redirect should be followed.
    #redirects = 2

    # Subnet prefix of IP block.
    subnet_prefix = 24

    # Indicates whether distributed firewall DENY rules are logged.
    #log_dropped_traffic = False


    # Option to use native load balancer or not
    use_native_loadbalancer = True


    # Option to auto scale layer 4 load balancer or not. If set to True, NCP
    # will create additional LB when necessary upon K8s Service of type LB
    # creation/update.
    #l4_lb_auto_scaling = True

    # Option to use native load balancer or not when ingress class annotation
    # is missing. Only effective if use_native_loadbalancer is set to true
    #default_ingress_class_nsx = True

    # Path to the default certificate file for HTTPS load balancing. Must be
    # specified along with lb_priv_key_path option
    #lb_default_cert_path = <None>

    # Path to the private key file for default certificate for HTTPS load
    # balancing. Must be specified along with lb_default_cert_path option
    #lb_priv_key_path = <None>

    # Option to set load balancing algorithm in load balancer pool object.
    # Choices: ROUND_ROBIN LEAST_CONNECTION IP_HASH WEIGHTED_ROUND_ROBIN
    pool_algorithm = ROUND_ROBIN

    # Option to set load balancer service size. MEDIUM Edge VM (4 vCPU, 8GB)
    # only supports SMALL LB. LARGE Edge VM (8 vCPU, 16GB) only supports MEDIUM
    # and SMALL LB. Bare Metal Edge (IvyBridge, 2 socket, 128GB) supports
    # LARGE, MEDIUM and SMALL LB
    # Choices: SMALL MEDIUM LARGE
    service_size = SMALL

    # Option to set load balancer persistence option. If cookie is selected,
    # cookie persistence will be offered.If source_ip is selected, source IP
    # persistence will be offered for ingress traffic through L7 load balancer
    # Choices: <None> cookie source_ip
    #l7_persistence = <None>

    # An integer for LoadBalancer side timeout value in seconds on layer 7
    # persistence profile, if the profile exists.
    #l7_persistence_timeout = 10800

    # Option to set load balancer persistence option. If source_ip is selected,
    # source IP persistence will be offered for ingress traffic through L4 load
    # balancer
    # Choices: <None> source_ip
    #l4_persistence = <None>




    # Name or UUID of the container ip blocks that will be used for creating
    # subnets. If name, it must be unique. If policy_nsxapi is enabled, it also
    # support automatically creating the IP blocks. The definition is a comma
    # separated list: CIDR,CIDR,... Mixing different formats (e.g. UUID,CIDR)
    # is not supported.
    container_ip_blocks =  ${container_ip_blocks}

    # Name or UUID of the container ip blocks that will be used for creating
    # subnets for no-SNAT projects. If specified, no-SNAT projects will use
    # these ip blocks ONLY. Otherwise they will use container_ip_blocks
    #no_snat_ip_blocks = []

    # Name or UUID of the external ip pools that will be used for allocating IP
    # addresses which will be used for translating container IPs via SNAT
    # rules. If policy_nsxapi is enabled, it also support automatically
    # creating the ip pools. The definition is a comma separated list:
    # CIDR,IP_1-IP_2,... Mixing different formats (e.g. UUID, CIDR&IP_Range) is
    # not supported.
    # external_ip_pools =  external_ip_pools

    # Name or UUID of the top-tier router for the container cluster network,
    # which could be either tier0 or tier1. If policy_nsxapi is enabled, should
    # be ID of a tier0/tier1 gateway.
    top_tier_router = ${top_tier_router}
    #tier0_gateway = ${top_tier_router}

    # Option to use single-tier router for the container cluster network
    single_tier_topology = True

    # Name or UUID of the external ip pools that will be used only for
    # allocating IP addresses for Ingress controller and LB service. If
    # policy_nsxapi is enabled, it also supports automatically creating the ip
    # pools. The definition is a comma separated list: CIDR,IP_1-IP_2,...
    # Mixing different formats (e.g. UUID, CIDR&IP_Range) is not supported.
    external_ip_pools_lb = ${external_ip_pools_lb}

    # Name or UUID of the NSX overlay transport zone that will be used for
    # creating logical switches for container networking. It must refer to an
    # already existing resource on NSX and every transport node where VMs
    # hosting containers are deployed must be enabled on this transport zone
    overlay_tz = ${overlay_tz}

    # Name or UUID of the lb service that can be attached by virtual servers
    #lb_service = <None>

    # Name or UUID of the IPSet containing the IPs of all the virtual servers
    #lb_vs_ip_set = <None>

    # Enable X_forward_for for ingress. Available values are INSERT or REPLACE.
    # When this config is set, if x_forwarded_for is missing, LB will add
    # x_forwarded_for in the request header with value client ip. When
    # x_forwarded_for is present and its set to REPLACE, LB will replace
    # x_forwarded_for in the header to client_ip. When x_forwarded_for is
    # present and its set to INSERT, LB will append client_ip to
    # x_forwarded_for in the header. If not wanting to use x_forwarded_for,
    # remove this config
    # Choices: <None> INSERT REPLACE
    #x_forwarded_for = <None>


    # Name or UUID of the firewall section that will be used to create firewall
    # sections below this mark section
    top_firewall_section_marker = ${top_firewall_section_marker}

    # Name or UUID of the firewall section that will be used to create firewall
    # sections above this mark section
    bottom_firewall_section_marker = ${bottom_firewall_section_marker}

    # Replication mode of container logical switch, set SOURCE for cloud as it
    # only supports head replication mode
    # Choices: MTEP SOURCE
    #ls_replication_mode = MTEP



    # The resource which NCP will search tag 'node_name' on, to get parent VIF
    # or transport node uuid for container LSP API context field. For HOSTVM
    # mode, it will search tag on LSP. For BM mode, it will search tag on LSP
    # then search TN. For CLOUD mode, it will search tag on VM. For WCP_WORKER
    # mode, it will search TN by hostname.
    # Choices: tag_on_lsp tag_on_tn tag_on_vm hostname_on_tn
    #search_node_tag_on = tag_on_lsp

    # Determines which kind of information to be used as VIF app_id. Defaults
    # to pod_resource_key. In WCP mode, pod_uid is used.
    # Choices: pod_resource_key pod_uid
    #vif_app_id_type = pod_resource_key


    # If this value is not empty, NCP will append it to nameserver list
    #dns_servers = []

    # Set this to True to enable NCP to report errors through NSXError CRD.
    #enable_nsx_err_crd = False

    # Maximum number of virtual servers allowed to create in cluster for
    # LoadBalancer type of services.
    #max_allowed_virtual_servers = 9223372036854775807

    # Edge cluster ID needed when creating Tier1 router for loadbalancer
    # service. Information could be retrieved from Tier0 router
    edge_cluster = ${edge_cluster}






    [ha]


    # Time duration in seconds of mastership timeout. NCP instance will remain
    # master for this duration after elected. Note that the heartbeat period
    # plus the update timeout must not be greater than this period. This is
    # done to ensure that the master instance will either confirm liveness or
    # fail before the timeout.
    #master_timeout = 18

    # Time in seconds between heartbeats for elected leader. Once an NCP
    # instance is elected master, it will periodically confirm liveness based
    # on this value.
    #heartbeat_period = 6

    # Timeout duration in seconds for update to election resource. The default
    # value is calculated by subtracting heartbeat period from master timeout.
    # If the update request does not complete before the timeout it will be
    # aborted. Used for master heartbeats to ensure that the update finishes or
    # is aborted before the master timeout occurs.
    #update_timeout = <None>


    [coe]

    # Container orchestrator adaptor to plug in.
    adaptor = kubernetes

    # Specify cluster for adaptor.
    cluster = ${cluster}

    # Log level for NCP operations
    # Choices: NOTSET DEBUG INFO WARNING ERROR CRITICAL
    loglevel = DEBUG

    # Log level for NSX API client operations
    # Choices: NOTSET DEBUG INFO WARNING ERROR CRITICAL
    #nsxlib_loglevel = <None>

    # Enable SNAT for all projects in this cluster
    #enable_snat = True

    # Option to enable profiling
    #profiling = False

    # The interval of reporting performance metrics (0 means disabled)
    #metrics_interval = 0

    # Name of log file for outputting metrics only (if not defined, use default
    # logging facility)
    #metrics_log_file = <None>

    # The type of container host node
    # Choices: HOSTVM BAREMETAL CLOUD WCP_WORKER
    node_type = HOSTVM

    # The time in seconds for NCP/nsx_node_agent to recover the connection to
    # NSX manager/container orchestrator adaptor/Hyperbus before exiting. If
    # the value is 0, NCP/nsx_node_agent won't exit automatically when the
    # connection check fails
    #connect_retry_timeout = 0


    # Enable system health status report for SHA
    #enable_sha = True


    [k8s]

    # Kubernetes API server IP address.
    apiserver_host_ip = ${apiserver_host_ip}

    # Kubernetes API server port.
    apiserver_host_port = ${apiserver_host_port}

    # Full path of the Token file to use for authenticating with the k8s API
    # server.
    client_token_file = /var/run/secrets/kubernetes.io/serviceaccount/token

    # Full path of the client certificate file to use for authenticating with
    # the k8s API server. It must be specified together with
    # "client_private_key_file".
    #client_cert_file = <None>

    # Full path of the client private key file to use for authenticating with
    # the k8s API server. It must be specified together with
    # "client_cert_file".
    #client_private_key_file = <None>

    # Specify a CA bundle file to use in verifying the k8s API server
    # certificate.
    ca_file = /var/run/secrets/kubernetes.io/serviceaccount/ca.crt

    # Specify whether ingress controllers are expected to be deployed in
    # hostnework mode or as regular pods externally accessed via NAT
    # Choices: hostnetwork nat
    ingress_mode = nat

    # Log level for the kubernetes adaptor
    # Choices: NOTSET DEBUG INFO WARNING ERROR CRITICAL
    #loglevel = <None>

    # The default HTTP ingress port
    #http_ingress_port = 80

    # The default HTTPS ingress port
    #https_ingress_port = 443


    # Specify thread pool size to process resource events
    #resource_watcher_thread_pool_size = 1

    # User specified IP address for HTTP and HTTPS ingresses
    #http_and_https_ingress_ip = <None>

    # Set this to True to enable NCP to create tier1 router, first segment and
    # default SNAT IP for VirtualNetwork CRD, and then create segment port for
    # VM through NsxNetworkInterface CRD.
    #enable_vnet_crd = False

    # Set this to True to enable NCP to create LoadBalancer on a Tier-1 for
    # LoadBalancer CRD. This option does not support LB autoscaling.
    #enable_lb_crd = False

    # Option to set the type of baseline cluster policy. ALLOW_CLUSTER creates
    # an explicit baseline policy to allow any pod to communicate any other pod
    # within the cluster. ALLOW_NAMESPACE creates an explicit baseline policy
    # to allow pods within the same namespace to communicate with each other.
    # By default, no baseline rule will be created and the cluster will assume
    # the default behavior as specified by the backend.
    # Choices: <None> allow_cluster allow_namespace
    #baseline_policy_type = <None>

    # Maximum number of endpoints allowed to create for a service.
    #max_allowed_endpoints = 1000

    # Set this to True to enable NCP reporting NSX backend error to k8s object
    # using k8s event
    #enable_ncp_event = False



    #[nsx_v3]
    # Deprecated option: tier0_router
    # Replaced by [nsx_v3] top_tier_router


    #[k8s]
    # Deprecated option: enable_nsx_netif_crd
    # Replaced by [k8s] enable_vnet_crd


---
apiVersion: apps/v1
kind: Deployment
metadata:
  # VMware NSX Container Plugin
  name: nsx-ncp
  namespace: nsx-system
  labels:
    tier: nsx-networking
    component: nsx-ncp
    version: v1
spec:
  # Active-Standby is supported from NCP 2.4.0 release,
  # so replica can be more than 1 if NCP HA is enabled.
  # replica *must be* 1 if NCP HA is disabled.
  selector:
    matchLabels:
      tier: nsx-networking
      component: nsx-ncp
      version: v1
  replicas: 1
  template:
    metadata:
      labels:
        tier: nsx-networking
        component: nsx-ncp
        version: v1
    spec:
      # NCP shares the host management network.
      hostNetwork: true
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
      # If configured with ServiceAccount, update the ServiceAccount
      # name below.
      serviceAccountName: ncp-svc-account
      containers:
        - name: nsx-ncp
          # Docker image for NCP
          image: ${ncp_image_location}
          imagePullPolicy: IfNotPresent
          env:
            - name: NCP_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: NCP_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          livenessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - timeout 5 check_pod_liveness nsx-ncp
            initialDelaySeconds: 5
            timeoutSeconds: 5
            periodSeconds: 10
            failureThreshold: 5
          volumeMounts:
          - name: projected-volume
            mountPath: /etc/nsx-ujo
            readOnly: true
      volumes:
        - name: projected-volume
          projected:
            sources:
              # ConfigMap nsx-ncp-config is expected to supply ncp.ini
              - configMap:
                  name: nsx-ncp-config
                  items:
                    - key: ncp.ini
                      path: ncp.ini
              # To use cert based auth, uncomment and update the secretName,
              # then update ncp.ini with the mounted cert and key file paths
              #- secret:
              #    name: nsx-secret
              #    items:
              #      - key: tls.crt
              #        path: nsx-cert/tls.crt
              #      - key: tls.key
              #        path: nsx-cert/tls.key
              #- secret:
              #    name: lb-secret
              #    items:
              #      - key: tls.crt
              #        path: lb-cert/tls.crt
              #      - key: tls.key
              #        path: lb-cert/tls.key


---
# Yaml template for nsx-node-agent and nsx-kube-proxy DaemonSet
# Proper kubernetes API parameters and NCP Docker image must be
# specified.
# This yaml file is part of NCP 2.5.1 release.

# ConfigMap for ncp.ini
apiVersion: v1
kind: ConfigMap
metadata:
  name: nsx-node-agent-config
  namespace: nsx-system
  labels:
    version: v1
data:
  ncp.ini: |
    
    [DEFAULT]

    # If set to true, the logging level will be set to DEBUG instead of the
    # default INFO level.
    debug = true

    # If set to true, log output to standard error.
    use_stderr = True

    # If set to true, use syslog for logging.
    #use_syslog = False

    # The base directory used for relative log_file paths.
    #log_dir = <None>

    # Name of log file to send logging output to.
    #log_file = <None>

    # max MB for each compressed file. Defaults to 100 MB.
    #log_rotation_file_max_mb = 100

    # Total number of compressed backup files to store. Defaults to 5.
    #log_rotation_backup_count = 5




    [k8s]

    # Kubernetes API server IP address.
    apiserver_host_ip = ${apiserver_host_ip}

    # Kubernetes API server port.
    apiserver_host_port = ${apiserver_host_port}

    # Full path of the Token file to use for authenticating with the k8s API
    # server.
    client_token_file = /var/run/secrets/kubernetes.io/serviceaccount/token

    # Full path of the client certificate file to use for authenticating with
    # the k8s API server. It must be specified together with
    # "client_private_key_file".
    #client_cert_file = <None>

    # Full path of the client private key file to use for authenticating with
    # the k8s API server. It must be specified together with
    # "client_cert_file".
    #client_private_key_file = <None>

    # Specify a CA bundle file to use in verifying the k8s API server
    # certificate.
    ca_file = /var/run/secrets/kubernetes.io/serviceaccount/ca.crt

    # Specify whether ingress controllers are expected to be deployed in
    # hostnework mode or as regular pods externally accessed via NAT
    # Choices: hostnetwork nat
    ingress_mode = nat

    # Log level for the kubernetes adaptor
    # Choices: NOTSET DEBUG INFO WARNING ERROR CRITICAL
    #loglevel = <None>

    # The default HTTP ingress port
    #http_ingress_port = 80

    # The default HTTPS ingress port
    #https_ingress_port = 443


    # Specify thread pool size to process resource events
    #resource_watcher_thread_pool_size = 1

    # User specified IP address for HTTP and HTTPS ingresses
    #http_and_https_ingress_ip = <None>

    # Set this to True to enable NCP to create tier1 router, first segment and
    # default SNAT IP for VirtualNetwork CRD, and then create segment port for
    # VM through NsxNetworkInterface CRD.
    #enable_vnet_crd = False

    # Set this to True to enable NCP to create LoadBalancer on a Tier-1 for
    # LoadBalancer CRD. This option does not support LB autoscaling.
    #enable_lb_crd = False

    # Option to set the type of baseline cluster policy. ALLOW_CLUSTER creates
    # an explicit baseline policy to allow any pod to communicate any other pod
    # within the cluster. ALLOW_NAMESPACE creates an explicit baseline policy
    # to allow pods within the same namespace to communicate with each other.
    # By default, no baseline rule will be created and the cluster will assume
    # the default behavior as specified by the backend.
    # Choices: <None> allow_cluster allow_namespace
    #baseline_policy_type = <None>

    # Maximum number of endpoints allowed to create for a service.
    #max_allowed_endpoints = 1000

    # Set this to True to enable NCP reporting NSX backend error to k8s object
    # using k8s event
    enable_ncp_event = True


    [coe]

    # Container orchestrator adaptor to plug in.
    adaptor = kubernetes

    # Specify cluster for adaptor.
    cluster = ${cluster}

    # Log level for NCP operations
    # Choices: NOTSET DEBUG INFO WARNING ERROR CRITICAL
    #loglevel = <None>

    # Log level for NSX API client operations
    # Choices: NOTSET DEBUG INFO WARNING ERROR CRITICAL
    #nsxlib_loglevel = <None>

    # Enable SNAT for all projects in this cluster
    #enable_snat = True

    # Option to enable profiling
    #profiling = False

    # The interval of reporting performance metrics (0 means disabled)
    #metrics_interval = 0

    # Name of log file for outputting metrics only (if not defined, use default
    # logging facility)
    #metrics_log_file = <None>

    # The type of container host node
    # Choices: HOSTVM BAREMETAL CLOUD WCP_WORKER
    node_type = HOSTVM

    # The time in seconds for NCP/nsx_node_agent to recover the connection to
    # NSX manager/container orchestrator adaptor/Hyperbus before exiting. If
    # the value is 0, NCP/nsx_node_agent won't exit automatically when the
    # connection check fails
    #connect_retry_timeout = 0


    # Enable system health status report for SHA
    #enable_sha = True


    [nsx_kube_proxy]

    # The way to process service configuration, set into OVS flow or write to
    # nestdb,
    # Choices: ovs nestdb
    #config_handler = ovs



    [nsx_node_agent]

    # Prefix of node /proc path to mount on nsx_node_agent DaemonSet
    #proc_mount_path_prefix = /host




    # The log level of NSX RPC library
    # Choices: NOTSET DEBUG INFO WARNING ERROR CRITICAL
    nsxrpc_loglevel = DEBUG

    # OVS bridge name
    ovs_bridge = br-int

    # The time in seconds for nsx_node_agent to wait CIF config from HyperBus
    # before returning to CNI
    #config_retry_timeout = 300

    # The time in seconds for nsx_node_agent to backoff before re-using an
    # existing cached CIF to serve CNI request. Must be less than
    # config_retry_timeout.
    #config_reuse_backoff_time = 15


    # The OVS uplink OpenFlow port where to apply the NAT rules to.
    ovs_uplink_port = ${ovs_uplink_port}



    #[k8s]
    # Deprecated option: enable_nsx_netif_crd
    # Replaced by [k8s] enable_vnet_crd


---
# nsx-ncp-bootstrap DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nsx-ncp-bootstrap
  namespace: nsx-system
  labels:
    tier: nsx-networking
    component: nsx-ncp-bootstrap
    version: v1
spec:
  selector:
    matchLabels:
      tier: nsx-networking
      component: nsx-ncp-bootstrap
      version: v1
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        tier: nsx-networking
        component: nsx-ncp-bootstrap
        version: v1
    spec:
      hostNetwork: true
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
        - key: node.kubernetes.io/not-ready
          effect: NoSchedule
        - key: node.kubernetes.io/unreachable
          effect: NoSchedule
      hostPID: true
      # If configured with ServiceAccount, update the ServiceAccount
      # name below.
      serviceAccountName: nsx-node-agent-svc-account
      initContainers:
        - name: nsx-ncp-bootstrap
          # Docker image for NCP
          image: ${ncp_image_location}
          imagePullPolicy: IfNotPresent
          # override NCP image entrypoint
          command: ["init_k8s_node"]

          securityContext:
            # privilege mode required to load apparmor on ubuntu
            privileged: true
            runAsUser: 0


          volumeMounts:
          # required to read the ovs_uplink_port
          - name: projected-volume
            mountPath: /etc/nsx-ujo
          # mounts to which NSX-CNI are copied BEGIN
          - name: host-etc
            mountPath: /host/etc
          - name: host-opt
            mountPath: /host/opt
          - name: host-var
            mountPath: /host/var
          # mounts to which NSX-CNI are copied END
          # mount host's OS info to identify host OS
          - name: host-os-release
            mountPath: /host/etc/os-release
          # mount host lib modules to install OVS kernel module if needed
          - name: host-modules
            mountPath: /lib/modules
          # mount openvswitch database
          - name: host-config-openvswitch
            mountPath: /etc/openvswitch
          # mount ovs runtime files
          - name: openvswitch
            mountPath: /var/run/openvswitch
          - name: dir-tmp-usr-ovs-kmod-backup
          # we move the usr kmod files to this dir temporarily before installing
          # new OVS kmod and/or backing up existing OVS kmod backup
            mountPath: /tmp/nsx_usr_ovs_kmod_backup

          # mount apparmor files to load the node-agent-apparmor
          - name: app-armor-cache
            mountPath: /var/cache/apparmor
            subPath: apparmor
          - name: apparmor-d
            mountPath: /etc/apparmor.d
          # mount linux headers for compiling OVS kmod
          - name: host-usr-src
            mountPath: /usr/src
          # mount host's deb package database to remove nsx-cni if installed
          - name: dpkg-lib
            mountPath: /host/var/lib/dpkg
          # mount for uninstalling NSX-CNI old doc
          - name: usr-share-doc
            mountPath: /usr/share/doc
          - name: snap-confine
            mountPath: /var/lib/snapd/apparmor/snap-confine


      containers:
        - name: nsx-dummy
          # This container is of no use.
          # Docker image for NCP
          image: ${ncp_image_location}
          imagePullPolicy: IfNotPresent
          # override NCP image entrypoint
          command: ["/bin/bash", "-c", "while true; do sleep 5; done"]
      volumes:
        - name: projected-volume
          projected:
            sources:
              - configMap:
                  name: nsx-node-agent-config
                  items:
                    - key: ncp.ini
                      path: ncp.ini
        - name: host-etc
          hostPath:
            path: /etc
        - name: host-opt
          hostPath:
            path: /opt
        - name: host-var
          hostPath:
            path: /var
        - name: host-os-release
          hostPath:
            path: /etc/os-release
        - name: host-modules
          hostPath:
            path: /lib/modules
        - name: host-config-openvswitch
          hostPath:
            path: /etc/openvswitch
        - name: openvswitch
          hostPath:
            path: /var/run/openvswitch
        - name: dir-tmp-usr-ovs-kmod-backup
          hostPath:
            path: /tmp/nsx_usr_ovs_kmod_backup

        - name: app-armor-cache
          hostPath:
            path: /var/cache/apparmor
        - name: apparmor-d
          hostPath:
            path: /etc/apparmor.d
        - name: host-usr-src
          hostPath:
            path: /usr/src
        - name: dpkg-lib
          hostPath:
            path: /var/lib/dpkg
        - name: usr-share-doc
          hostPath:
            path: /usr/share/doc
        - name: snap-confine
          hostPath:
            path: /var/lib/snapd/apparmor/snap-confine


---
# nsx-node-agent DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nsx-node-agent
  namespace: nsx-system
  labels:
    tier: nsx-networking
    component: nsx-node-agent
    version: v1
spec:
  selector:
    matchLabels:
      tier: nsx-networking
      component: nsx-node-agent
      version: v1
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:

      annotations:
        container.apparmor.security.beta.kubernetes.io/nsx-node-agent: localhost/node-agent-apparmor

      labels:
        tier: nsx-networking
        component: nsx-node-agent
        version: v1
    spec:
      hostNetwork: true
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
        - key: node.kubernetes.io/not-ready
          effect: NoSchedule
        - key: node.kubernetes.io/unreachable
          effect: NoSchedule
      # If configured with ServiceAccount, update the ServiceAccount
      # name below.
      serviceAccountName: nsx-node-agent-svc-account
      containers:

        - name: nsx-node-agent
          # Docker image for NCP
          image: ${ncp_image_location}
          imagePullPolicy: IfNotPresent
          # override NCP image entrypoint
          command: ["start_node_agent"]
          livenessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - timeout 5 check_pod_liveness nsx-node-agent
            initialDelaySeconds: 60
            timeoutSeconds: 5
            periodSeconds: 10
            failureThreshold: 5
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
                - SYS_ADMIN
                - SYS_PTRACE
                - DAC_READ_SEARCH
          volumeMounts:
          # ncp.ini
          - name: projected-volume
            mountPath: /etc/nsx-ujo
            readOnly: true
          # mount openvswitch dir
          - name: openvswitch
            mountPath: /var/run/openvswitch
          # mount CNI socket path
          - name: var-run-ujo
            mountPath: /var/run/nsx-ujo
          # mount container namespace
          - name: netns
            mountPath: /var/run/netns
          # mount host proc
          - name: proc
            mountPath: /host/proc
            readOnly: true

        - name: nsx-kube-proxy
          # Docker image for NCP
          image: ${ncp_image_location}
          imagePullPolicy: IfNotPresent
          # override NCP image entrypoint
          command: ["start_kube_proxy"]
          livenessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - timeout 5 check_pod_liveness nsx-kube-proxy
            initialDelaySeconds: 5
            periodSeconds: 5
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
                - SYS_ADMIN
                - SYS_PTRACE
                - DAC_READ_SEARCH

          volumeMounts:
          # ncp.ini
          - name: projected-volume
            mountPath: /etc/nsx-ujo
            readOnly: true

          # mount openvswitch dir
          - name: openvswitch
            mountPath: /var/run/openvswitch


        # nsx-ovs is not needed on BAREMETAL
        - name: nsx-ovs
          # Docker image for NCP
          image: ${ncp_image_location}
          imagePullPolicy: IfNotPresent
          # override NCP image entrypoint
          command: ["start_ovs"]
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
                - SYS_ADMIN
                - SYS_NICE
                - SYS_MODULE
          livenessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                # You must pass --allowOVSOnHost if you are running OVS on the
                # host before the installation. This allows livelinessProbe to
                # succeed and container won't restart frequently.
                - timeout 5 check_pod_liveness nsx-ovs
            initialDelaySeconds: 5
            periodSeconds: 5
          volumeMounts:
          # ncp.ini
          - name: projected-volume
            mountPath: /etc/nsx-ujo
            readOnly: true
          # mount openvswitch-db dir
          - name: var-run-ujo
            mountPath: /etc/openvswitch
            subPath: openvswitch-db
          # mount openvswitch dir
          - name: openvswitch
            mountPath: /var/run/openvswitch
          # mount host sys dir
          - name: host-sys
            mountPath: /sys
            readOnly: true
          # mount host config openvswitch dir
          - name: host-original-ovs-db
            mountPath: /host/etc/openvswitch
          # mount host lib modules to insert OVS kernel module if needed
          - name: host-modules
            mountPath: /lib/modules
            readOnly: true
          # mount host's OS info to identify host OS
          - name: host-os-release
            mountPath: /host/etc/os-release
            readOnly: true
          # OVS puts logs into this mountPath by default
          - name: host-var-log-ujo
            mountPath: /var/log/openvswitch
            subPath: openvswitch


      volumes:
        - name: projected-volume
          projected:
            sources:
              - configMap:
                  name: nsx-node-agent-config
                  items:
                    - key: ncp.ini
                      path: ncp.ini

        - name: openvswitch
          hostPath:
            path: /var/run/openvswitch
        - name: var-run-ujo
          hostPath:
            path: /var/run/nsx-ujo
        - name: netns
          hostPath:
            path: /var/run/netns
        - name: proc
          hostPath:
            path: /proc


        - name: host-sys
          hostPath:
            path: /sys
        - name: host-modules
          hostPath:
            path: /lib/modules
        # This is the directory where OVS that runs on the host stores
        # its conf.db file. OVS uses this directory by default but if
        # you had a it configured differently, please update it here
        - name: host-original-ovs-db
          hostPath:
            path: /etc/openvswitch
        - name: host-os-release
          hostPath:
            path: /etc/os-release
        - name: host-var-log-ujo
          hostPath:
            path: /var/log/nsx-ujo
            type: DirectoryOrCreate