# Self-hosted Kubernetes

The self-hosted Kubernetes example shows how to use matchbox to network boot and provision a 3 node "self-hosted" Kubernetes v1.6.4 cluster. [bootkube](https://github.com/kubernetes-incubator/bootkube) is run once on a controller node to bootstrap Kubernetes control plane components as pods before exiting.

## Requirements

Follow the getting started [tutorial](../../../Documentation/getting-started.md) to learn about matchbox and set up an environment that meets the requirements:

* Matchbox v0.6+ [installation](../../../Documentation/deployment.md) with gRPC API enabled
* Matchbox provider credentials `client.crt`, `client.key`, and `ca.crt`
* PXE [network boot](../../../Documentation/network-setup.md) environment
* Terraform v0.9+ and [terraform-provider-matchbox](https://github.com/coreos/terraform-provider-matchbox) installed locally on your system
* Machines with known DNS names and MAC addresses

If you prefer to provision QEMU/KVM VMs on your local Linux machine, set up the matchbox [development environment](../../../Documentation/getting-started-rkt.md).

```sh
sudo ./scripts/devnet create
```

## Usage

Clone the [matchbox](https://github.com/coreos/matchbox) project and take a look at the cluster examples.

```sh
$ git clone https://github.com/coreos/matchbox.git
$ cd matchbox/examples/terraform/bootkube-install
```

Copy the `terraform.tfvars.example` file to `terraform.tfvars`. Ensure `provider.tf` references your matchbox credentials.

```hcl
matchbox_http_endpoint = "http://matchbox.example.com:8080"
matchbox_rpc_endpoint = "matchbox.example.com:8081"

cluster_name = "demo"
container_linux_version = "1298.7.0"
container_linux_channel = "stable"
ssh_authorized_key = "ADD ME"
```

Provide an ordered list of controller names, MAC addresses, and domain names. Provide an ordered list of worker names, MAC addresses, and domain names.

```
controller_names = ["node1"]
controller_macs = ["52:54:00:a1:9c:ae"]
controller_domains = ["node1.example.com"]
worker_names = ["node2", "node3"]
worker_macs = ["52:54:00:b2:2f:86", "52:54:00:c3:61:77"]
worker_domains = ["node2.example.com", "node3.example.com"]
```

Finally, provide an `assets_dir` for generated manifests and a DNS name which you've setup to resolves to controller(s) (e.g. round-robin). Worker nodes and your kubeconfig will communicate via this endpoint.

```
k8s_domain_name = "cluster.example.com"
asset_dir = "assets"
```

You may set `experimental_self_hosted_etcd = "true"` to deploy "self-hosted" etcd atop Kubernetes instead of running etcd on hosts directly. Warning, this is experimental and potentially dangerous.

## Apply

Fetch the [bootkube](../README.md#modules) Terraform [module](https://www.terraform.io/docs/modules/index.html) for bare-metal, which is maintained in the in the matchbox repo.

```sh
$ terraform get
```

Plan and apply to create the resources on Matchbox.

```sh
$ terraform plan
Plan: 37 to add, 0 to change, 0 to destroy.
```

Terraform will configure matchbox with profiles (e.g. `cached-container-linux-install`, `bootkube-controller`, `bootkube-worker`) and add groups to match machines by MAC address to a profile. These resources declare that each machine should PXE boot and install Container Linux to disk. `node1` will provision itself as a controller, while `node2` and `noe3` provision themselves as workers.

The module referenced in `cluster.tf` will also generate bootkube assets to `assets_dir` (exactly like the [bootkube](https://github.com/kubernetes-incubator/bootkube) binary would). These assets include Kubernetes bootstrapping and control plane manifests as well as a kubeconfig you can use to access the cluster. 

```sh
$ terraform apply
module.cluster.null_resource.copy-kubeconfig.0: Still creating... (5m0s elapsed)
module.cluster.null_resource.copy-kubeconfig.1: Still creating... (5m0s elapsed)
module.cluster.null_resource.copy-kubeconfig.2: Still creating... (5m0s elapsed)
...
module.cluster.null_resource.bootkube-start: Still creating... (8m40s elapsed)
...
Apply complete! Resources: 37 added, 0 changed, 0 destroyed.
```

You can now move on to the "Machines" section. Apply will loop until it can successfully copy the kubeconfig to each node and start the one-time Kubernetes bootstrapping process on a controller. In practice, you may see `apply` fail if it connects before the disk install has completed. Run terraform apply until it reconciles successfully.

Note: The `cached-container-linux-install` profile will PXE boot and install Container Linux from matchbox [assets](https://github.com/coreos/matchbox/blob/master/Documentation/api.md#assets). If you have not populated the assets cache, use the `container-linux-install` profile to use public images (slower).

## Machines

Power on each machine (with PXE boot device on next boot). Machines should network boot, install Container Linux to disk, reboot, and provision themselves as bootkube controllers or workers.

```sh
$ ipmitool -H node1.example.com -U USER -P PASS chassis bootdev pxe
$ ipmitool -H node1.example.com -U USER -P PASS power on
```

For local QEMU/KVM development, create the QEMU/KVM VMs.

```sh
$ sudo ./scripts/libvirt create
$ sudo ./scripts/libvirt [start|reboot|shutdown|poweroff|destroy]
```

## Verify

[Install kubectl](https://coreos.com/kubernetes/docs/latest/configure-kubectl.html) on your laptop. Use the generated kubeconfig to access the Kubernetes cluster. Verify that the cluster is accessible and that the apiserver, scheduler, and controller-manager are running as pods.

```sh
$ KUBECONFIG=assets/auth/kubeconfig
$ kubectl get nodes
NAME                STATUS    AGE
node1.example.com   Ready     3m
node2.example.com   Ready     3m
node3.example.com   Ready     3m

$ kubectl get pods --all-namespaces
NAMESPACE     NAME                                       READY     STATUS    RESTARTS   AGE
kube-system   checkpoint-installer-p8g8r                 1/1       Running   1          13m
kube-system   kube-apiserver-s5gnx                       1/1       Running   1          41s
kube-system   kube-controller-manager-3438979800-jrlnd   1/1       Running   1          13m
kube-system   kube-controller-manager-3438979800-tkjx7   1/1       Running   1          13m
kube-system   kube-dns-4101612645-xt55f                  4/4       Running   4          13m
kube-system   kube-flannel-pl5c2                         2/2       Running   0          13m
kube-system   kube-flannel-r9t5r                         2/2       Running   3          13m
kube-system   kube-flannel-vfb0s                         2/2       Running   4          13m
kube-system   kube-proxy-cvhmj                           1/1       Running   0          13m
kube-system   kube-proxy-hf9mh                           1/1       Running   1          13m
kube-system   kube-proxy-kpl73                           1/1       Running   1          13m
kube-system   kube-scheduler-694795526-1l23b             1/1       Running   1          13m
kube-system   kube-scheduler-694795526-fks0b             1/1       Running   1          13m
kube-system   pod-checkpointer-node1.example.com         1/1       Running   2          10m
```

Try restarting machines or deleting pods to see that the cluster is resilient to failures.

## Going Further

Learn more about [matchbox](../../../Documentation/matchbox.md) or explore the other [example](../) clusters.
