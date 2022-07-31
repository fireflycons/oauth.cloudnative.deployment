# Cloud Native Deployment

Resources for deploying an End-to-End SPA and API code sample to Kubernetes.\
The goal is to demonstrate a real world deployed setup on a development computer.

## External URLs

Scripts will spin up a number of components for the Final SPA, and these URLs will be callable from browsers:

| Component | External URL | Description |
| --------- | ------------ | ----------- |
| Web Host | https://web.mycluster.com/spa | A development host to serve web static content for the SPA |
| API Gateway | https://tokenhandler.mycluster.com | The base URL for the API gateway that is hosted in front of APIs |
| OAuth Agent | https://tokenhandler.mycluster.com/oauth-agent | The SPA calls the OAuth Agent via the API gateway to perform OAuth work |
| Business API | https://api.mycluster.com/api | The public URL of the business API |
| Log Query UI | https://logs.mycluster.com/app/dev_tools#/console | The Kibana UI used to analyze technical support logs |

## Prerequisites

- The Docker Engine, eg [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Kubernetes in Docker](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [openssl](https://www.openssl.org/)
- [jq](https://github.com/stedolan/jq)
- [envsubst](https://github.com/a8m/envsubst)

## Networking

The networking is equivalent to that in a cloud system, with the load balancer in front of the Kubernetes cluster.\
The load balancer assigns a static IP address to the ingress controller:

![Cluster Networking](doc/cluster.png)

The ingress controller then receives HTTPS requests for multiple host names and routes to the correct component.\
The ingress controller can also perform jobs such as cookie to token translation.

## Deploy the System

First create the cluster:

```bash
./1-create-cluster.sh
```

Then create external SSL certificates and set up a Private PKI for inside the cluster:

```bash
./2-create-certs.sh
```

Then build apps into Docker containers:

```bash
./3-build.sh
```

Then deploy apps to the Kubernetes cluster:

```bash
./4-deploy.sh
```

Optionally deploy Elastic Stack components in order to use end-to-end API logging:

```bash
./5-deploy-elasticstack.sh
```

Later you can free all resources when required via this script:

```bash
./6-teardown.sh
```

## Enable Development URLs

Get the static IP address of the ingress controller:

```bash
kubectl get svc/ingress-nginx-controller -n ingress-nginx -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
```

In the system hosts file, associate the IP address with these development domain names:

```text
172.29.255.1 web.mycluster.com tokenhandler.mycluster.com logs.mycluster.com
```

Then trust the root certification authority at `certs\mycluster.ca.pem` on the local computer.\
This is done by adding it to the local computer's certificate store as explained in [Configuring SSL Trust](https://authguidance.com/developer-ssl-setup#os-ssl-trust).

## Use the System

Then sign in to the Single Page Application with these details:

| Field | Value |
| ----- | ----- |
| SPA URL | https://web.mycluster.com/spa |
| User Name | guestuser@mycluster.com |
| User Password | GuestPassword1 |

Also sign into Kibana with these details, and run queries from the [Technical Support Analysis](https://authguidance.com/2019/08/02/intelligent-api-platform-analysis/) blog post:

| Field | Value |
| ---------- | ----- |
| Kibana URL | https://logs.mycluster.com/app/dev_tools#/console |
| User Name | elastic |
| User Password | Password1 |

## View Kubernetes Resources

The deployment provides multiple worker nodes for hosting applications:

```text
kubectl get nodes -o wide

NAME                  STATUS   ROLES                  AGE   VERSION   INTERNAL-IP
oauth-control-plane   Ready    control-plane,master   15m   v1.24.0   172.29.0.4
oauth-worker          Ready    <none>                 15m   v1.24.0   172.29.0.2
oauth-worker2         Ready    <none>                 15m   v1.24.0   172.29.0.3
```

Each worker node hosts application containers within a `deployed` namespace:

```text
kubectl get pods -o wide -n deployed

NAME                           READY   STATUS    RESTARTS   AGE   IP           NODE
finalapi-77b44bf64-gh646       1/1     Running   0          86s   10.244.1.6   oauth-worker
finalapi-77b44bf64-kqnql       1/1     Running   0          86s   10.244.2.7   oauth-worker2
kong-proxy-57d5fcd47f-6blc4    1/1     Running   0          83s   10.244.1.8   oauth-worker
network-multitool-9zmcx        1/1     Running   0          13m   10.244.2.3   oauth-worker2
network-multitool-mf5mn        1/1     Running   0          13m   10.244.1.3   oauth-worker
oauthagent-9fc86d5cc-lhqrs     1/1     Running   0          84s   10.244.1.7   oauth-worker
oauthagent-9fc86d5cc-s8wws     1/1     Running   0          84s   10.244.2.8   oauth-worker2
webhost-5f76fdcf46-lwsdb       1/1     Running   0          87s   10.244.2.6   oauth-worker2
webhost-5f76fdcf46-zsxr9       1/1     Running   0          87s   10.244.1.5   oauth-worker
```

Each worker node also hosts Elastic Stack containers within an `elasticstack` namespace:

```text
kubectl get pods -o wide -n elasticstack

NAME                             READY   STATUS              RESTARTS   AGE     IP            NODE
elasticsearch-67f7d45c6f-khbmp   1/1     Running             0          2m43s   10.244.2.16   oauth-worker
es-initdata-job-lbnqv            0/1     Completed           0          2m42s   10.244.1.12   oauth-worker2
filebeat-q5xw8                   1/1     Running             0          2m41s   172.29.0.2    oauth-worker
filebeat-skwbs                   1/1     Running             0          2m41s   172.29.0.3    oauth-worker2
kibana-67fb658898-t2jdb          1/1     Running             0          2m42s   10.244.2.17   oauth-worker
```
