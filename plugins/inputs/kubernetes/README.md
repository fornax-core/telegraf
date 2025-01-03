# Kubernetes Input Plugin

The Kubernetes plugin talks to the Kubelet API and gathers metrics about the
running pods and containers for a single host. It is assumed that this plugin
is running as part of a `daemonset` within a kubernetes installation. This
means that telegraf is running on every node within the cluster. Therefore, you
should configure this plugin to talk to its locally running kubelet.

Kubernetes is a fast moving project, with a new minor release every 3 months. As
such, this plugin aims to maintain support only for versions that are supported
by the major cloud providers, namely, 4 release over 2 years.

## Host IP

To find the ip address of the host you are running on you can issue a command
like the following:

```sh
curl -s $API_URL/api/v1/namespaces/$POD_NAMESPACE/pods/$HOSTNAME \
  --header "Authorization: Bearer $TOKEN" \
  --insecure | jq -r '.status.hostIP'
```

This example uses the downward API to pass in the `$POD_NAMESPACE` and
`$HOSTNAME` is the hostname of the pod which is set by the kubernetes API.
See the [Kubernetes docs][] for a full example of generating a bearer token to
explore the Kubernetes API.

[Kubernetes docs]: https://kubernetes.io/docs/tasks/administer-cluster/access-cluster-api/#without-kubectl-proxy

## Series Cardinality Warning

This plugin may produce a high number of series which, when not controlled
for, will cause high load on your database. Use the following techniques to
avoid cardinality issues:

- Use [metric filtering][] options to exclude unneeded measurements and tags.
- Write to a database with an appropriate [retention policy][].
- Consider using the [Time Series Index][tsi].
- Monitor your databases [series cardinality][].
- Consult the [InfluxDB documentation][influx-docs] for the most up-to-date techniques.

## Global configuration options <!-- @/docs/includes/plugin_config.md -->

In addition to the plugin-specific configuration settings, plugins support
additional global and plugin configuration settings. These settings are used to
modify metrics, tags, and field or create aliases and configure ordering, etc.
See the [CONFIGURATION.md][CONFIGURATION.md] for more details.

[CONFIGURATION.md]: ../../../docs/CONFIGURATION.md#plugins

## Configuration

```toml @sample.conf
# Read metrics from the kubernetes kubelet api
[[inputs.kubernetes]]
  ## URL for the kubelet, if empty read metrics from all nodes in the cluster
  url = "http://127.0.0.1:10255"

  ## Use bearer token for authorization. ('bearer_token' takes priority)
  ## If both of these are empty, we'll use the default serviceaccount:
  ## at: /var/run/secrets/kubernetes.io/serviceaccount/token
  ##
  ## To re-read the token at each interval, please use a file with the
  ## bearer_token option. If given a string, Telegraf will always use that
  ## token.
  # bearer_token = "/var/run/secrets/kubernetes.io/serviceaccount/token"
  ## OR
  # bearer_token_string = "abc_123"

  ## Kubernetes Node Metric Name
  ## The default Kubernetes node metric name (i.e. kubernetes_node) is the same
  ## for the kubernetes and kube_inventory plugins. To avoid conflicts, set this
  ## option to a different value.
  # node_metric_name = "kubernetes_node"

  ## Pod labels to be added as tags.  An empty array for both include and
  ## exclude will include all labels.
  # label_include = []
  # label_exclude = ["*"]

  ## Set response_timeout (default 5 seconds)
  # response_timeout = "5s"

  ## Optional TLS Config
  # tls_ca = /path/to/cafile
  # tls_cert = /path/to/certfile
  # tls_key = /path/to/keyfile
  ## Use TLS but skip chain & host verification
  # insecure_skip_verify = false

  ## Node labels will be added as tags using the same include
  ## exlude filter as Pod labels.
  # node_labels = false

  ## Convert characters in label names that don't match the regex [a-zA-Z0-9.]
  ## into underbars, so the field names don't require quoting in SQL queries.
  # convert_labels = false
```

## DaemonSet

For recommendations on running Telegraf as a DaemonSet see [Monitoring
Kubernetes Architecture][k8s-telegraf] or view the Helm charts:

- [Telegraf][]
- [InfluxDB][]
- [Chronograf][]
- [Kapacitor][]

## Metrics

- kubernetes_node
  - tags:
    - node_name
  - fields:
    - cpu_usage_nanocores
    - cpu_usage_core_nanoseconds
    - memory_available_bytes
    - memory_usage_bytes
    - memory_working_set_bytes
    - memory_rss_bytes
    - memory_page_faults
    - memory_major_page_faults
    - network_rx_bytes
    - network_rx_errors
    - network_tx_bytes
    - network_tx_errors
    - fs_available_bytes
    - fs_capacity_bytes
    - fs_used_bytes
    - runtime_image_fs_available_bytes
    - runtime_image_fs_capacity_bytes
    - runtime_image_fs_used_bytes

- kubernetes_pod_container
  - tags:
    - container_name
    - namespace
    - node_name
    - pod_name
  - fields:
    - cpu_usage_nanocores
    - cpu_usage_core_nanoseconds
    - memory_usage_bytes
    - memory_working_set_bytes
    - memory_rss_bytes
    - memory_page_faults
    - memory_major_page_faults
    - rootfs_available_bytes
    - rootfs_capacity_bytes
    - rootfs_used_bytes
    - logsfs_available_bytes
    - logsfs_capacity_bytes
    - logsfs_used_bytes

- kubernetes_pod_volume
  - tags:
    - volume_name
    - namespace
    - node_name
    - pod_name
  - fields:
    - available_bytes
    - capacity_bytes
    - used_bytes

- kubernetes_pod_network
  - tags:
    - namespace
    - node_name
    - pod_name
  - fields:
    - rx_bytes
    - rx_errors
    - tx_bytes
    - tx_errors

## Example Output

```text
kubernetes_node
kubernetes_pod_container,container_name=deis-controller,namespace=deis,node_name=ip-10-0-0-0.ec2.internal,pod_name=deis-controller-3058870187-xazsr cpu_usage_core_nanoseconds=2432835i,cpu_usage_nanocores=0i,logsfs_available_bytes=121128271872i,logsfs_capacity_bytes=153567944704i,logsfs_used_bytes=20787200i,memory_major_page_faults=0i,memory_page_faults=175i,memory_rss_bytes=0i,memory_usage_bytes=0i,memory_working_set_bytes=0i,rootfs_available_bytes=121128271872i,rootfs_capacity_bytes=153567944704i,rootfs_used_bytes=1110016i 1476477530000000000
kubernetes_pod_network,namespace=deis,node_name=ip-10-0-0-0.ec2.internal,pod_name=deis-controller-3058870187-xazsr rx_bytes=120671099i,rx_errors=0i,tx_bytes=102451983i,tx_errors=0i 1476477530000000000
kubernetes_pod_volume,volume_name=default-token-f7wts,namespace=default,node_name=ip-172-17-0-1.internal,pod_name=storage-7 available_bytes=8415240192i,capacity_bytes=8415252480i,used_bytes=12288i 1546910783000000000
kubernetes_system_container
```

[metric filtering]: https://github.com/influxdata/telegraf/blob/master/docs/CONFIGURATION.md#metric-filtering
[retention policy]: https://docs.influxdata.com/influxdb/latest/guides/downsampling_and_retention/
[tsi]: https://docs.influxdata.com/influxdb/latest/concepts/time-series-index/
[series cardinality]: https://docs.influxdata.com/influxdb/latest/query_language/spec/#show-cardinality
[influx-docs]: https://docs.influxdata.com/influxdb/latest/
[k8s-telegraf]: https://www.influxdata.com/blog/monitoring-kubernetes-architecture/
[telegraf]: https://github.com/helm/charts/tree/master/stable/telegraf
[influxdb]: https://github.com/helm/charts/tree/master/stable/influxdb
[chronograf]: https://github.com/helm/charts/tree/master/stable/chronograf
[kapacitor]: https://github.com/helm/charts/tree/master/stable/kapacitor
