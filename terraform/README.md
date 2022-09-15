# Task 3: Terraform

## Exercise Goals

* Create a Terraform script named `main.tf` to:
  * Use the local backend;
  * Use the [Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest);
  * Connect to your `minikube` context, using your local `.kube/config`;
  * Load the `app.yaml` from your last task in this module and apply it to your `minukube` context;
* Init your terraform script;
* Apply your terraform script;

## Expected Output

Please, provide us with the `main.tf` you created. Your `main.yaml` is supposed to:

* Use local backend;
* Use the Kubernetes Provider mentioned before;
* Apply your `app.yaml` to your minikube;

Please, provide us with the `terraform.state` file that was created when you ran `terraform apply`;

[Optional] You can also share screenshots of your progress.

## Next steps?

Once you complete this task, you can proceed to the [Linux](../linux) task;

## Annotations

* https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template

### Commands

#### Minikube multi nodes start

```bash
K8S_VERSION=1.24.3; nodes=3; k8s_version=v${K8S_VERSION} && minikube start --driver=hyperkit --memory=16384 --cpus=4 --disk-size=100g --kubernetes-version=${k8s_version} --bootstrapper=kubeadm --install-addons=true --nodes=${nodes} --addons=helm-tiller --addons=metrics-server --addons=dashboard --addons=pod-security-policy --vm=true --delete-on-failure
minikube delete --purge --all
```

#### Minikube single node start

```bash
minikube start --driver=hyperkit
```

#### Minikube delete

```bash
minikube delete --purge --all
```
