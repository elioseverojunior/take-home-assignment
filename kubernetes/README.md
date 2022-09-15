# Task 2: Kubernetes

## Exercise Goals

* Install minikube;
* Create namespace;
* Create deployment;
  * Use the golang webserver image you built in the previous step;
  * Add `readiness/liveness` probe;
  * Add `prestophook`;
  * add init container that sleep for 30 seconds;
* Create service to expose your pod;

## Expected Output

Please, provide us with a file named `namespace.yaml` you are going to create. Your `namespace.yaml` is supposed to:

* Contain the following Kubernetes Resources you are going to create in your `minikube` cluster:
  * Namespace specification;

Please, provide us with a file named `app.yaml` you are going to create. Your `app.yaml` is supposed to:

* Contain the following Kubernetes Resources you are going to create in your `minikube` cluster:
  * Deployment specification;
    * Use your new image created on the [Task 1](../dockerize) in your deployment;
  * Service specification;

[Optional] You can also share screenshots of your progress.

[namespace.yaml](./namespace.yaml)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: webserver-assessment
spec: {}
```

[app.yaml](./app.yaml)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dockerize
  namespace: webserver-assessment
  labels:
    app: dockerize
spec:
  progressDeadlineSeconds: 300
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: dockerize
  revisionHistoryLimit: 10
  replicas: 2
  template:
    metadata:
      labels:
        app: dockerize
    spec:
      terminationGracePeriodSeconds: 60
      initContainers:
        - name: init
          image: busybox
          imagePullPolicy: IfNotPresent
          command: ['/bin/sh', '-c', '/app/init.sh']
          volumeMounts:
            - name: database-secrets
              mountPath: /app/server.config
              subPath: server.config
              readOnly: true
            - name: dockerize-scripts
              mountPath: /app/init.sh
              subPath: init.sh
              readOnly: true
            - name: dockerize-sql
              mountPath: /app/init.sql
              subPath: init.sql
              readOnly: true
      containers:
        - name: dockerize
          image: elioseverojunior/dockerize:latest
          imagePullPolicy: IfNotPresent
          envFrom:
            - secretRef:
                name: database-secrets
          ports:
            - containerPort: 8080
          lifecycle:
            preStop:
              exec:
                command: ["sh", "-c", "/app/scripts/prestop.sh"]
          livenessProbe:
            httpGet:
              path: /
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 2
            successThreshold: 1
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 2
            successThreshold: 1
            failureThreshold: 3
          resources:
            limits:
              cpu: 100m
              memory: 128Mi
            requests:
              cpu: 100m
              memory: 128Mi
          volumeMounts:
            - name: database-secrets
              mountPath: /app/server.config
              subPath: server.config
              readOnly: true
            - name: dockerize-scripts
              mountPath: /app/scripts/prestop.sh
              subPath: prestop.sh
              readOnly: true
      volumes:
        - name: database-secrets
          secret:
            secretName: database-secrets
            items:
              - key: server.config
                path: server.config
        - name: dockerize-scripts
          configMap:
            name: dockerize-scripts
            items:
              - key: init.sh
                path: init.sh
              - key: prestop.sh
                path: prestop.sh
            defaultMode: 0755
        - name: dockerize-sql
          configMap:
            name: dockerize-sql
            items:
              - key: init.sql
                path: init.sql
            defaultMode: 0755
      dnsPolicy: ClusterFirst
```

### Share Screenshots

![Creating Resources into Kubernetes](.images/creating_resources.png "Creating Resources")

![Deployments](.images/deployments.png "Deployments")

![Services](.images/services.png "Services")

![Pods](.images/pods.png "Pods")

![ConfigMaps](.images/configmaps.png "ConfigMaps")

![Secrets](.images/secrets.png "Secrets")

![Workloads](.images/workloads.png "Workloads")

### Commands

```bash
minikube start --driver=hyperkit --addons=helm-tiller --addons=metrics-server --addons=metallb --addons=dashboard
minikube service dockerize -n webserver-assessment
```

### Getting Events
```bash
kubectl get events --sort-by='.metadata.creationTimestamp' --namespace webserver-assessment
```

### Load Generator
```bash
kubectl run -i --tty -n webserver-assessment load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://dockerize/api/articles; done"
```

### Application Running

![Article Home Page](.images/article.png "Article Home Page")

![Article 1](.images/article-1.png "Article 1")

![Article 2](.images/article-2.png "Article 2")

![Article 3](.images/article-3.png "Article 3")

![Article 4](.images/article-4.png "Article 4")

![Article 5](.images/article-5.png "Article 5")

![Articles API](.images/articles-api.png "Articles API")

## Next steps?

Once you complete this task, you can proceed to the [Terraform](../terraform) task;
