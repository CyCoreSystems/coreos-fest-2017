// Install Container Linux to disk
resource "matchbox_group" "container-linux-install" {
  count = "${length(var.controller_names) + length(var.worker_names)}"

  name    = "${format("container-linux-install-%s", element(concat(var.controller_names, var.worker_names), count.index))}"
  profile = "${module.profiles.cached-container-linux-install}"

  selector {
    mac = "${element(concat(var.controller_macs, var.worker_macs), count.index)}"
  }

  metadata {
    container_linux_channel = "${var.container_linux_channel}"
    container_linux_version = "${var.container_linux_version}"
    container_linux_oem     = "${var.container_linux_oem}"
    root_disk               = "${var.root_disk}"
    ignition_endpoint       = "${var.matchbox_http_endpoint}/ignition"
    baseurl                 = "${var.matchbox_http_endpoint}/assets/coreos"
    ssh_authorized_key      = "${var.ssh_authorized_key}"
  }
}

resource "matchbox_group" "controller" {
  count   = "${length(var.controller_names)}"
  name    = "${format("%s-%s", var.cluster_name, element(var.controller_names, count.index))}"
  profile = "${module.profiles.bootkube-controller}"

  selector {
    mac = "${element(var.controller_macs, count.index)}"
    os  = "installed"
  }

  metadata {
    domain_name          = "${element(var.controller_domains, count.index)}"
    etcd_name            = "${element(var.controller_names, count.index)}"
    etcd_initial_cluster = "${join(",", formatlist("%s=http://%s:2380", var.controller_names, var.controller_domains))}"
    etcd_on_host         = "${var.experimental_self_hosted_etcd ? "false" : "true"}"
    k8s_dns_service_ip   = "${module.bootkube.kube_dns_service_ip}"
    k8s_etcd_service_ip  = "${module.bootkube.etcd_service_ip}"
    root_disk            = "${var.root_disk}"
    root_part            = "${var.root_part}"
    ssh_authorized_key   = "${var.ssh_authorized_key}"
  }
}

resource "matchbox_group" "worker" {
  count   = "${length(var.worker_names)}"
  name    = "${format("%s-%s", var.cluster_name, element(var.worker_names, count.index))}"
  profile = "${module.profiles.bootkube-worker}"

  selector {
    mac = "${element(var.worker_macs, count.index)}"
    os  = "installed"
  }

  metadata {
    domain_name         = "${element(var.worker_domains, count.index)}"
    etcd_endpoints      = "${join(",", formatlist("%s:2379", var.controller_domains))}"
    etcd_on_host        = "${var.experimental_self_hosted_etcd ? "false" : "true"}"
    k8s_dns_service_ip  = "${module.bootkube.kube_dns_service_ip}"
    k8s_etcd_service_ip = "${module.bootkube.etcd_service_ip}"
    root_disk           = "${var.root_disk}"
    root_part           = "${var.root_part}"
    ssh_authorized_key  = "${var.ssh_authorized_key}"
  }
}
