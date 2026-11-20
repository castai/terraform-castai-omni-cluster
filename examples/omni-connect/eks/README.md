# omni-connect EKS demo

## Prerequisites

- `terraform` >= 1.5
- `aws` authenticated (`aws sso login` or credentials)
- `kubectl`, `ssh` and `helm` (for the controller chart) on your PATH

The chart and images come from the demo registry
(`us-central1-docker.pkg.dev/localenv-andzej/omninet`). To build and push
your own, run `OMNI_TAG=1.0.0-demo ./tools/build.sh` from the repository root
and point `var.registry` and `var.chart_version` at the result.

## Run

```sh
terraform init
terraform apply
```

The apply creates everything, joins the edge VM (watch for `running the join
command on the edge VM...`) and deploys the demo workload. It takes roughly
20-30 minutes, most of it the EKS cluster and nodegroup.

## Inspect

### Nodes

You should have 3 nodes in total. In this example `ip-172-31-194-10` is edge node from another region.
```
NAME                          STATUS   ROLES    AGE    VERSION               INTERNAL-IP   EXTERNAL-IP      OS-IMAGE                        KERNEL-VERSION                            CONTAINER-RUNTIME
ip-10-40-0-243.ec2.internal   Ready    <none>   100m   v1.36.5-eks-9adbfea   10.40.0.243   100.48.22.31     Amazon Linux 2023.12.20261118   6.18.62-127.179.amzn2023.x86_64 (amd64)   containerd://2.3.7+unknown
ip-10-40-1-29.ec2.internal    Ready    <none>   100m   v1.36.5-eks-9adbfea   10.40.1.29    13.218.192.112   Amazon Linux 2023.12.20261118   6.18.62-127.179.amzn2023.x86_64 (amd64)   containerd://2.3.7+unknown
ip-172-31-194-10              Ready    <none>   35m    v1.36.5               10.40.1.152   <none>           Ubuntu 24.04.5 LTS              7.0.0-1017-aws (amd64)                    containerd://2.2.1
```

### Omni-connect pods

Omni connect requires cluster-agent, omni-controlplane, omni-node-agent and omni-postgres components in self hosted setup.
In sass hosted setup omni-controlplane and omni-postgres are not needed.

```
kgp -n castai-omni
NAME                                          READY   STATUS    RESTARTS      AGE   IP            NODE                          NOMINATED NODE   READINESS GATES
omni-cluster-agent-5b5fbc9b69-g87p4           1/1     Running   0             40m   10.40.1.100   ip-10-40-1-29.ec2.internal    <none>           <none>
omni-controlplane-65d56bcffd-r6jvj            1/1     Running   0             40m   10.40.0.60    ip-10-40-0-243.ec2.internal   <none>           <none>
omni-controlplane-65d56bcffd-vgjcb            1/1     Running   0             40m   10.40.1.129   ip-10-40-1-29.ec2.internal    <none>           <none>
omni-edge-proxy-ip-172-31-194-10              1/1     Running   0             36m   10.40.1.152   ip-10-40-1-29.ec2.internal    <none>           <none>
omni-local-path-596887977d-8cvc8              1/1     Running   0             40m   10.40.1.251   ip-10-40-1-29.ec2.internal    <none>           <none>
omni-node-agent-ip-10-40-0-243.ec2.internal   1/1     Running   0             39m   10.40.0.243   ip-10-40-0-243.ec2.internal   <none>           <none>
omni-node-agent-ip-10-40-1-29.ec2.internal    1/1     Running   0             39m   10.40.1.29    ip-10-40-1-29.ec2.internal    <none>           <none>
omni-node-agent-ip-172-31-194-10              1/1     Running   0             33m   10.40.1.152   ip-172-31-194-10              <none>           <none>
omni-node-local-dns-9qn89                     1/1     Running   0             33m   10.40.1.152   ip-172-31-194-10              <none>           <none>
omni-postgres-0                               1/1     Running   0             40m   10.40.0.205   ip-10-40-0-243.ec2.internal   <none>           <none>
```

### Demo pods

Greeting-reader runs on edge nodes and can read s3 bucket content using EKS pod identity. Check it's logs to see it in action.

```
kgp -n omni-demo           
NAME                               READY   STATUS    RESTARTS   AGE   IP            NODE                         NOMINATED NODE   READINESS GATES
greeting-reader-7697cc86d7-svh2f   1/1     Running   0          13m   100.127.3.2   ip-172-31-194-10             <none>           <none>
greeting-writer-86bfdbc8b5-kfqz5   1/1     Running   0          13m   10.40.1.140   ip-10-40-1-29.ec2.internal   <none>           <none>
```

## Teardown

```sh
terraform destroy
```

The join request is single-use: if the edge VM reboots and the join command
is stale, re-run `terraform apply -target=module.edge_join`.

## Notes

- The omninet overlay is `100.127.0.0/16` (a slice of the shared address
  space) - the mesh the edges and gateways build between themselves.
  Nothing of it is routed in the VPC; the gateway masquerades edge-bound
  traffic instead.
- The edge kubelet joins with the forwarding pod's IP as its node IP. If
  the forwarding pod is ever rescheduled, the edge agent notices the new
  address through the netmap, re-issues the kubelet's serving certificate
  for it and restarts the kubelet - exec and logs recover on their own.
- NodePort and host-network services on the edge are not reachable
  through the node IP in this mode; pod-to-pod traffic is unaffected.
