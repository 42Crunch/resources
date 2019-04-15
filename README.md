# 42Crunch API Firewall Deployment Setup
This document describes how to deploy 42Crunch API Firewall. Formore information on 42Crunch Platform and API Firewall, see [42Crunch Platform documentation](https://docs.42crunch.com/latest/content/home.htm).

The example setup in this document uses the Pixi API, a deliberately **vulnerable** API created as part of the [OWASP DevSlop](https://devslop.co/Home/Pixi) project to demonstrate common API issues.

We recommend that you install the Pixi API in a dedicated Kubernetes cluster, and delete the cluster once your tests are completed. Do not leave the unprotected Pixi API running, it is vulnerable! 

42Crunch API Firewall and Pixi require minimal resources, so you can use the smallest type of nodes your cloud provider offers. This setup has been tested on the Kubernetes engine of the following public clouds: 
- Azure
- DigitalOcean
- Google
- IBM

## Created artifacts
The deployment involves two types of artifacts: configuration artifacts and runtime artifacts.

### Configuration artifacts
The following configuration artifacts are created when you execute the deployment scripts:
- A Docker registry secret that contains the information for the DockerHub connection to pull firewall images.
- A TLS secret that contains the key-cert pair to protect the listening interface of the firewall. The key-cert pair is signed with an ephemeral CA and has been created for the hostname `pixi-secured.42crunch.test`. You can find the keys and certs under `etc/tls`.
- A generic secret that contains the protection token identifying the firewall configuration to run.
- A config map that is populated from the file `deployment.properties`.

### Runtime artifacts
The deployment scripts create two deployments:
- `PixiSecured`, which exposes the protected Pixi API (all API calls go through the API Firewall deployed in a sidecar mode)
- `Pixiapp`, which exposes the original, unprotected Pixi API so that you can directly invoke the vulnerable API

Both deployments are fronted by load balancers and point a Mongo database deployed in a pod called `pixidb`, fronted by a service.

![](/images/Deployment.jpg)

## Prerequisites
Before you start, ensure you have done the following:

### Kubernetes cluster
This example assumes that you already have a Kubernetes cluster running and you have proper credentials to deploy apps into that cluster.

Before deploying the artifacts, ensure that `kubectl` is properly configured to point to the cluster you want to use. To do this, run the following:

```shell
eagle$ kubectl config current-context
```

For example, if you're running a GKE cluster, you should get an answer like:

```shell
eagle$ kubectl config current-context
gke_pixi-deploy_europe-west6-a_xxxx
```
### 42Crunch user account
You also need to be registered as a user on the 42Crunch Platform to get access to the Docker image of our API Firewall. If you are an existing user but cannot access the Docker image, send a mail to: support@42crunch.com.

## Deployment steps

This deployment uses a specific namespace called `42crunch`. This means that you can deploy the artifacts in an existing Kubernetes cluster without overlapping other existing artifacts. If you want to change this name, edit the `etc/env` file and change the namespace before you run the script.

## Import Pixi API and generate a firewall configuration
1. Log in to 42Crunch Platform at https://42crunch.platform.com.

2. Create an API collection called `PixiTest`. 

3. Import the Pixi API definition from the file `OASFiles/Pixi-v2.0.json`. 
The API should score 82/100 in API Contract Security Audit: the detailing of API contract description in this file has been optimised, in particular for data definition quality (such as inbound headers, query params, access tokens, and responses JSON schemas).

4. Go to the **Protection** tab, and click **Enable**.

5. Copy the generated protection token to clipboard.

## Configure the deployment scripts
You must configure the deployment scripts to use the firewall configuration you just created and to succesfully authenticate to DockerHub.

1. Go to edit the file `etc/secret-protection-token`.

2. Replace the placeholder `<your_token_value>` with the protection token you copied on the Protection tab, and save the file:

    ```shell
    PROTECTION_TOKEN=<your_token_value>
    ```
    
3. Go to edit the file `etc/secret-docker-registry`.

4. Provide your credentials for DockerHub, and save the file:

    ```shell
    REGISTRY_USERNAME=<your_user>
    REGISTRY_PASSWORD=<your_password>
    ```  
## Run API Firewall
1. Depending on your platform, run either the `pixi-create-demo.sh` or `pixi-create-demo.bat` script to deploy the sample configuration:

   ```shell
   # Create the 42crunch namespace - Edit the env file is you want to change it
   kubectl create namespace $RUNTIME_NS
   # Create secrets
   kubectl create --namespace=$RUNTIME_NS secret docker-registry docker-registry-creds --docker-server=$REGISTRY_SERVER --docker-username=$REGISTRY_USERNAME --docker-password=$REGISTRY_PASSWORD --docker-email=$REGISTRY_EMAIL
   kubectl create --namespace=$RUNTIME_NS secret tls guardiancerts --key ../etc/tls/private.key --cert ../etc/tls/cert-fullchain.pem
   kubectl create --namespace=$RUNTIME_NS secret generic protection-token --from-env-file=../etc/secret-protection-token
   # Config Map creation
   kubectl create --namespace=$RUNTIME_NS configmap firewall-props --from-env-file='./deployment.properties'
   # Deployment (Required App/DB + storage)
   kubectl apply --namespace=$RUNTIME_NS -f pixi-basic-deployment.yaml
   # Deployment (Pixi + FW as sidecar pod)
   kubectl apply --namespace=$RUNTIME_NS -f pixi-secured-deployment.yaml
   ```

2. Once the deployment is complete, run `kubectl get pods -n 42crunch` to check that all pods are successful running:

   ```shell
   NAME                            READY   STATUS    RESTARTS   AGE
   pixi-8c94b66b5-hq8js            1/1     Running   0          1h
   pixi-secured-54d957c8bc-h867f   2/2     Running   0          1h
   pixidb-755f648d47-k5pm9         1/1     Running   0          1h
   ```
## Configure testing tools
You can test API Firewall using the Postman collection in this repository, or other tools like cURL or the Advanced REST Google Chrome plugin. This example uses the provided Postman collection.

1. Run `kubectl get svc -n 42crunch` to get the external IP of the `pixisecured` deployment (values shown here are placeholders): 

   ```shell
   NAME          TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                         
   pixiapp       LoadBalancer   10.3.240.197   <pixi-app-ip>   8000:30540/TCP,8090:30893/TCP   
   pixidb        ClusterIP      10.3.242.155   <none>          27017/TCP                       
   pixisecured   LoadBalancer   10.3.245.43    <pixi-secu-ip>  443:31316/TCP                   
   ```

2. Go to edit your `hosts` file, and add the `pixisecured` deployment to it. Replace the placeholder `<pixi-secu-ip>` with the actual external IP returned by the command above:

   ```shell
   <pixi-secu-ip> pixi-secured.42crunch.test
   <pixi-app-ip> pixi-direct.42crunch.test
   ```
   
3. Import the file `Postman/Pixi_collection.json` in Postman, and go to the newly imported Pixi project.

4. Create an environment variable called **42c_url**, and set its value to https://pixi-secured.42crunch.test to invoke the protected API, or to http://pixi-direct.42crunch.test:8090 to invoke the unprotected API directly.

5. From Postman, invoke the operation `POST  /api/register` with the following contents 

   ```json
   {
     "id": 50,
     "user": "42crunch@getme.in",
     "pass": "hellopixi",
     "name": "42Crunch",
     "is_admin": false,
     "account_balance": 1000
   }
   ```
   Alternatively, you can use the following cURL command: 
   ```shell
   curl -k -H "Content-Type:application/json" --data "{\"id\": 50, \"user\": \"42crunch@getme.in\", \"pass\": \"hellopixi\", \"name\": \"42Crunch\", \"is_admin\": false, \"account_balance\": 1000}" https://pixi-secured.42crunch.test/api/register
   ```

You should see a response similar to this. This `x-access-token` is a JWT that you must inject in a `x-access-token` header for all API calls (except login and register):

   ```json
   {
       "message": "x-access-token: ",
       "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxxx"
   }
   ```

## Test API Firewall in action

42Crunch API Firewall validates API requests and responses according to the OpenAPI definition of the protected API. You can test  the firewall behavior with the following requests:

1. Wrong verb: the opertion `Register` is defined to use `POST`, try calling it with `GET` or other verbs, and see how requests are blocked.

2. Wrong path: any request to a path _not_ defined in the OAS definition is blocked, try `/api/foo`, for example.

3. Wrong `Content-Type`: the OpenAPI definition states that the operation `/api/register` requires input in the form of `application/json`. If you use a different value or if you do not specify the `Content-Type`, the request is blocked. 

4. Missing a parameter that the input JSON structure requires: the schema for the operation `/api/register` specifies that the parameters `user`, `name`, `email`, and `password` are mandatory. If you do not specify all of these parameters, the requests is blocked. 

5. Wrong format for values: if you specify a value (such as email) in a format that does not match the schema, the request is blocked.

6. MongoDB injection: If you introduce a MongoDB injection like `[$ne]=1` instead of the password value when calling the login method, the request and login are blocked.

7. Reflected XSS attack: If you introduce a XSS attack like the example below, the request is blocked: 

   ```script
   <script>alert('hi')</script>
   ```

   
