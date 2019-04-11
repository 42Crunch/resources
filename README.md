# 42Crunch API Firewall Deployment Setup

This document describes how to deploy 42Crunch API firewall. It uses the Pixi API  (a **vulnerable** API created as part of the [DevSlop OWASP](https://devslop.co/Home/Pixi) project as a base for the guide. 

We recommend you install this sample API in a dedicated Kubernetes cluster and delete it once your tests are completed: do not leave the <u>unprotected</u> Pixi API running as it is vulnerable (it was built on purpose to demonstrate common API issues).  Since 42Crunch API firewall and Pixi require minimal resources, you can use the smallest type of nodes available on your cloud provider for this test.

This setup has been tested on the following public clouds Kubernetes engine: Azure, DigitalOcean, Google  and IBM.

## Prerequisites

The deployment steps assume you already have a Kubernetes cluster running and you have proper credentials to deploy apps into that cluster.

Before deploying the artifacts, ensure `kubectl` is properly configured to point to the cluster you want to use. You can do this by running:

```shell
eagle$ kubectl config current-context
```

For example, if you're running a GKE cluster, you should see an answer like:

```shell
eagle$ kubectl config current-context
gke_pixi-deploy_europe-west6-a_xxxx
```

## Scripts configuration

Before running the scripts, you need to:

- Provide your DockerHub credentials:

  - Edit the *etc/secret-docker-registry* file

  - Provide values for username and password

    ```shell
    REGISTRY_USERNAME=<your_user>
    REGISTRY_PASSWORD=<your_password>
    ```

> Note that you need to have been registered as a user on the platform to get access to our API firewall Docker image. If you don't have access, send a mail to: support@42crunch.com.

* Provide a Protection Token, as generated from the platform UI (see Testing Steps)

  * Edit the *etc/secret-protection-token* file

  * Replace *<your_token_value>* by the one available on the API protection tab  

    ```shell
    PROTECTION_TOKEN=<your_token_value>
    ```

## Configuration Artifacts

The following configuration artifacts are created when you execute the scripts:

* A docker-registry secret containing the docker hub connection information (to pull images)
* A tls secret containing the key/cert pair for the firewall listening interface setup. The key/cert pair is signed with an ephemeral CA and has been created for the **pixi-secured.42crunch.test** hostname. Keys and certs are located under etc/tls.
* A generic secret containing the protection token.
* A config map populated from the deployment.properties file

## Runtime Artifacts

Two deployments are used:

* Pixiapp, which exposes the original pixi app so that you can directly invoke the vulnerable API. This deployment is fronted by a load balancer.
* PixiSecured, which exposes the protected API (all calls go through our firewall deployed as sidecar). This deployment is fronted by a load balancer.

Both deployments point a mongo database, which is deployed in a pod call pixidb and fronted by a service.

![](/images/Deployment.jpg)

## Deployment Steps

> Our deployment uses a specific namespace (**42crunch**), so that you can deploy the artifacts in an existing Kubernetes cluster without overlapping with other artifacts. If you want to change this name, edit the `etc/env file` before running the script.

1. Log in onto the 42Crunch platform at https://42crunch.platform.com

2. Create a PixiTest Collection 

3. Import the Pixi API using the *OASFiles/Pixi-v2.0.json file

4. You should obtain an Audit score of 82/100 : this OAS file has been optimised to incorporate detailed description of the API contract, in particular for data definition (inbound headers, query params, access tokens and responses JSON schemas)

5. Go to the Protection tab and press the Enable button

6. Copy the protection token that was generated and use it as the protection token secret value.

7. Execute the `pixi-create-demo.sh` or `pixi-create-demo.bat` scripts depending of your platform to deploy the sample configuration.

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

8. Check all pods are successful running: `kubectl get pods -n 42crunch`.

   ```shell
   NAME                            READY   STATUS    RESTARTS   AGE
   pixi-8c94b66b5-hq8js            1/1     Running   0          1h
   pixi-secured-54d957c8bc-h867f   2/2     Running   0          1h
   pixidb-755f648d47-k5pm9         1/1     Running   0          1h
   ```

Once the deployment is complete, you can test the deployment by using the Postman collection located in this project (you can of course also use tools such as curl or the Advanced REST Google Chrome plugin).

1. Get the public API of the pixisecured deployment using: `kubectl get svc -n 42crunch` 

   ```shell
   NAME          TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                         
   pixiapp       LoadBalancer   10.3.240.197   <pixi-app-ip>   8000:30540/TCP,8090:30893/TCP   
   pixidb        ClusterIP      10.3.242.155   <none>          27017/TCP                       
   pixisecured   LoadBalancer   10.3.245.43    <pixi-secu-ip>  443:31316/TCP                   
   ```

2. Edit your hosts file and add the following entry to it , replacing <pixi-secu-ip> but the external IP returned by the command above.

   ```shell
   <pixi-secu-ip> pixi-secured.42crunch.test
   <pixi-app-ip> pixi-direct.42crunch.test
   ```

3. Import the Postman/Pixi_collection.json file in Postman and go to the newly imported Pixi project. 

4. Create an environment variable called **42c_url** and set its value to: https://pixi-secured.42crunch.test to invoke the protected API or to http://pixi-direct.42crunch.test:8090 to invoke the API directly.

5. Invoke POST  /api/register operation with the following contents 

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
   For example, you can use the 'curl' command as below  : 
   ```shell
   curl -k -H "Content-Type:application/json" --data "{\"id\": 50, \"user\": \"42crunch@getme.in\", \"pass\": \"hellopixi\", \"name\": \"42Crunch\", \"is_admin\": false, \"account_balance\": 1000}" https://pixi-secured.42crunch.test/api/register
   ```

6. If all goes well, you should see a response similar to this. This x-access-token is a JWT , which needs to be injected in a x-access-token header for all API calls (except login and register).

   ```json
   {
       "message": "x-access-token: ",
       "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxxx"
   }
   ```

## Testing the API firewall

The 42Crunch API firewall validates API requests and responses according to the API's OpenAPI definition. You can test the firewall behavior with the following requests:

1. Using the wrong verb : the Register operation is defined to use POST, try calling it with GET or other verbs and see requests being blocked.

2. Specifying the wrong path: any request to a path not defined in the OAS definition is blocked (try /api/foo for example)

3. Removing/altering Content Type: the OpenAPI definition states that the /api/register operation requires an application/json input. If the value is different or if the Content-Type header is not specified, the request is blocked. 

4. Removing the name from the input JSON structure: the schema for the /api/register operation specifies that user, name, email, and password are mandatory. Not specifying any of those will invalidate the request. 

5. Specifying wrong format of the values: if the values format (such as email format) does not match the schema, the request will be blocked

6. MongoDB injection such as : **[$ne]=1** instead of the password value for the login method will block the login.

7. Reflected XSS attacks such as: 

   ```script
   <script>alert('hi')</script>
   ```

   
