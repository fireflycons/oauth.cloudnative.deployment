# OAuth Cloud Native Local

The second repository in the following set, focused on productive development setups:

| Repository | Role |
| ---------- | ---- |
| [oauth.cloudnative.base](https://github.com/gary-archer/oauth.cloudnative.base) | An initial infrastructure setup on a development computer |
| oauth.cloudnative.local | An end-to-end infrastructure and application setup on a development computer |
| [oauth.cloudnative.aws](https://github.com/gary-archer/oauth.cloudnative.aws) | An end-to-end infrastructure and application setup in the AWS cloud |

This repo extends the base deployment to cover deployment of applications and to use SSL for all URLs.\
It also covers some advanced behaviour, such as running Kong plugins during ingress.

## Architecture

My code samples and best of breed third party components are deployed, and accessed over these URLs:

| Component | URL | Description |
| --------- | --- | ----------- |
| Web Host | https://web.mycluster.com | A content delivery network that serves web static content |
| APIs | https://api.mycluster.com | The entry point for APIs called by native apps |
| Token Handler | https://tokenhandler.mycluster.com | The backend for frontend used by the SPA |
| Logs | https://logs.mycluster.com | A URL for querying backend logs |

## Prerequisites

Install these tools:

- A Docker Engine such as [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Kubernetes in Docker (KIND)](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [Helm](https://helm.sh/docs/intro/install/)
- [openssl](https://www.openssl.org/)
- [envsubst](https://github.com/a8m/envsubst)

On a Windows host, ensure that Google's DNS server is configured against the internet connection.\
This prevents problems resolving AWS URLs from inside the cluster once the installation is complete.

![Windows DNS](./images/dns.png)

## Deploy the System

First create the cluster's base infrastructure:

```bash
./1-create-cluster.sh
```

Then build apps into Docker containers:

```bash
./2-build.sh
```

Then deploy apps to the Kubernetes cluster:

```bash
./3-deploy.sh
```

Optionally deploy Elastic Stack components in order to use end-to-end API logging:

```bash
./4-deploy-elasticstack.sh
```

Later you can free all resources when required via this script:

```bash
./5-teardown.sh
```

## Enable Development URLs

Look for this line in logs after step 1 above.\
This will be the loopack URL on macOS and Windows, or a load balancer assigned IP address on Linux:

```text
The cluster's external IP address is 127.0.0.1 ...
```

Add it to the hosts file on the local computer, mapped to these external URLs:

```text
127.0.0.1 web.mycluster.com api.mycluster.com tokenhandler.mycluster.com logs.mycluster.com dashboard.mycluster.com
```

Then trust the root certificate at `certs/mycluster.ca.pem` on the local computer.\
This is done by adding it to the host's certificate store as explained in [Configuring SSL Trust](https://authguidance.com/developer-ssl-setup#os-ssl-trust).

## Use the System

Then sign in to the Single Page Application with these details:

| Field | Value |
| ----- | ----- |
| SPA URL | https://web.mycluster.com/spa |
| User Name | guestuser@mycompany.com |
| User Password | GuestPassword1 |

To [Query API Logs](https://authguidance.com/2019/08/02/intelligent-api-platform-analysis/), sign into Kibana with these details:

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

The worker nodes host application containers within an `applications` namespace:

```text
kubectl get pods -o wide -n applications

NAME                           READY   STATUS    RESTARTS   AGE   IP           NODE
finalapi-77b44bf64-gh646       1/1     Running   0          86s   10.244.1.6   oauth-worker
finalapi-77b44bf64-kqnql       1/1     Running   0          86s   10.244.2.7   oauth-worker2
oauthagent-9fc86d5cc-lhqrs     1/1     Running   0          84s   10.244.1.7   oauth-worker
oauthagent-9fc86d5cc-s8wws     1/1     Running   0          84s   10.244.2.8   oauth-worker2
webhost-5f76fdcf46-lwsdb       1/1     Running   0          87s   10.244.2.6   oauth-worker2
webhost-5f76fdcf46-zsxr9       1/1     Running   0          87s   10.244.1.5   oauth-worker
```

The worker nodes also host Elastic Stack containers within an `elasticstack` namespace:

```text
kubectl get pods -o wide -n elasticstack

NAME                             READY   STATUS              RESTARTS   AGE     IP            NODE
elasticsearch-67f7d45c6f-khbmp   1/1     Running             0          2m43s   10.244.2.16   oauth-worker
es-initdata-job-lbnqv            0/1     Completed           0          2m42s   10.244.1.12   oauth-worker2
filebeat-q5xw8                   1/1     Running             0          2m41s   172.29.0.2    oauth-worker
filebeat-skwbs                   1/1     Running             0          2m41s   172.29.0.3    oauth-worker2
kibana-67fb658898-t2jdb          1/1     Running             0          2m42s   10.244.2.17   oauth-worker
```
