# eks

This directory contains configuration for creating an EKS cluster using terraform.

It creates a Kubernetes cluster managed by EKS using Cilium as the network
overlay.

Blimp doesn't depend directly on Cilium -- you're free to use any networking
approach you prefer. This guide uses Cilium to get around AWS's limits
on ENIs per machine, and to enforce network isolation between namespaces.

_Note:_ The terraform state is stored locally. For non-demo usage, you should
probably store the state in S3.

### Dependencies

* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [terraform](https://www.terraform.io/downloads.html)
* [helm](https://helm.sh/docs/helm/helm_install/)

## Creating the cluster

1. `cd` into the `terraform` directory and  run `terraform apply`. Note that
   this takes awhile (10-15 mins) to complete.
   1. Add the outputted kubeconfig to your local kubeconfig. If you don't have
      any existing Kube clusters setup, just save the contents to
      `~/.kube/config`.
   1. Save the `config_map_aws_auth` output to `node-configmap.yaml` for the next step.
1. Run `kubectl apply -f node-configmap.yaml` to add the nodes to your Kubernetes cluster.
1. As a sanity check, run `kubectl get nodes`. You should see something like the following in a couple seconds.
   ```
   NAME                                       STATUS     ROLES    AGE   VERSION
   ip-10-0-0-198.us-west-2.compute.internal   NotReady   <none>   3s    v1.16.13-eks-2ba888
   ip-10-0-0-84.us-west-2.compute.internal    NotReady   <none>   4s    v1.16.13-eks-2ba888
   ```
1. Setup networking and volumes by running the following command.
   ```
   helm plugin install https://github.com/databus23/helm-diff
   helm repo add cilium https://helm.cilium.io/
   ./kubernetes/setup-volumes-and-cilium.sh
   ```
1. As a sanity check, run `kubectl get pods --all-namespaces`. You should eventually see something like this.
   ```
   NAMESPACE     NAME                              READY   STATUS    RESTARTS   AGE
   cni-cilium    cilium-jbh7p                      1/1     Running   0          2m48s
   cni-cilium    cilium-njnkh                      1/1     Running   0          2m48s
   cni-cilium    cilium-node-init-cgrl9            1/1     Running   0          2m48s
   cni-cilium    cilium-node-init-nz9qx            1/1     Running   0          2m48s
   cni-cilium    cilium-operator-95999cf55-cvz79   1/1     Running   2          2m48s
   kube-system   coredns-5946c5d67c-n9j4v          1/1     Running   0          8m38s
   kube-system   coredns-5946c5d67c-rz68n          1/1     Running   0          101s
   kube-system   kube-proxy-6mfqc                  1/1     Running   0          3m22s
   kube-system   kube-proxy-vqbxl                  1/1     Running   0          3m20s
   ```

## Destroying the cluster

It seems like if there are LoadBalancer services in the Kube cluster when
destroying, then Terraform will be unable to delete subnets. So if you
remember, delete the `blimp-system`, `manager`, and `registry` namespaces
before running `terraform destroy`.

If you forget, you'll see messages like:

```
aws_subnet.customer[1]: Still destroying... [id=subnet-07f9999dbdfcdc5a5, 19m40s elapsed]
aws_subnet.customer[1]: Still destroying... [id=subnet-07f9999dbdfcdc5a5, 19m50s elapsed]
```

If this happens, manually delete the load balancers at
https://us-west-2.console.aws.amazon.com/ec2/v2/home?region=us-west-2#LoadBalancers:sort=loadBalancerName,
and run `terraform destroy` again.
