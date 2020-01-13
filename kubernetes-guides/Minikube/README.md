![42crunch.com](/kubernetes-guides/graphics/42c_logo.png?raw=true "42Crunch")
![Minikube](/kubernetes-guides/graphics/MinikubeLogo.png?raw=true "Minikube")

# Deploying 42Crunch API Firewall on Minikube

## Introduction

This document describes how to deploy and test [42Crunch](https://42crunch.com/) API Firewall in [Minikube](https://minikube.sigs.k8s.io/) (a local Kubernetes cluster on macOS, Linux, and Windows). For more information on [42Crunch Platform](https://platform.42crunch.com) and [42Crunch API Firewall](https://docs.42crunch.com/latest/content/concepts/api_protection.htm#Firewall), take a look at the [platform documentation](https://docs.42crunch.com/).

The example setup in this document uses the Pixi API, a deliberately **vulnerable** API created as part of the [OWASP DevSlop](https://devslop.co/Home/Pixi) project to demonstrate common API issues. **We recommend that you install the Pixi API in a dedicated Kubernetes cluster, and delete the cluster once your tests are completed.** Do not leave the unprotected Pixi API running, it is vulnerable!

You also need basic understanding of [Kubernetes concepts](https://kubernetes.io/docs/concepts/) before running this guide.

## Goals

This document guides you through:

1. Getting Minikube ready for deployment.
2. Deploying the unsecured API (Pixi API).
3. Deploying the 42Crunch API firewall protecting the unsecured API.
4. Seeing the [42Crunch Platform](https://platform.42crunch.com) in action.

## Prerequisites
Before you start, ensure you have the following.

### 42Crunch platform account

You must be a registered user on the [42Crunch Platform](https://platform.42crunch.com) to follow this guide. If you do not have an account, contact us at sales@42crunch.com.

### Access to 42Crunch API firewall Docker image
The 42Crunch API firewall image is located on a private DockerHub repository: an access to this repository must have been granted to you. If you are an existing platform user but cannot access the Docker image, send a mail to: support@42crunch.com.

### Minikube

You must have Minikube running to deploy the artifacts. You can get started with Minikube in three easy steps:

1. Install Kubectl
2. Install [Minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/).
3. Run the command `minikube start` to start your minikube VM. The default Kubernetes node setup (2 vCPUS, 2 Gb RAM) is enough to run through those instructions.

You should get something similar to:

>   ```txt
>  😄  minikube v1.0.0 on ...
>  🤹  Downloading Kubernetes v1.14.0 images in the background ...
>  🔥  Creating virtualbox VM (CPUs=2, Memory=2048MB, Disk=20000MB) ...
>  📶  "minikube" IP address is 192.168.99.102
>  🐳  Configuring Docker as the container runtime ...
>  🐳  Version of container runtime is 18.06.2-ce
>  ⌛  Waiting for image downloads to complete ...
>  ✨  Preparing Kubernetes environment ...
>  🚜  Pulling images required by Kubernetes v1.14.0 ...
>  🚀  Launching Kubernetes v1.14.0 using kubeadm ...
>  ⌛  Waiting for pods: apiserver proxy etcd scheduler controller dns
>  🔑  Configuring cluster permissions ...
>  🤔  Verifying component health .....
>  💗  kubectl is now configured to use "minikube"
>  🏄  Done! Thank you for using minikube!
>   ```

You should now have a Kubernetes environment ready for testing. You can verify this by running `minikube status`. You should obtain something similar to this:

>```text
> host: Running
> kubelet: Running
> apiserver: Running
> kubectl: Correctly Configured: pointing to minikube-vm at 192.168.99.102
>```

## Deployment artifacts

The deployment involves two types of artifacts: configuration artifacts and runtime artifacts. The scripts and conf files for minikube deployment are located under `minikube-artifacts`.

### Configuration artifacts

The following configuration artifacts are created when you execute the deployment scripts:

- A Docker registry secret that contains the information for the DockerHub connection to pull the API firewall image.
- A TLS secret that contains the key-cert pair to protect the listening interface of the firewall. The key-cert pair is signed with an ephemeral CA and has been created for the hostname `pixi-secured.42crunch.test`. You can find the keys and certs under `etc/tls`.
- A generic secret that contains the protection token identifying the API firewall configuration to run.
- A config map that is populated from the file `deployment.properties`.

### Runtime artifacts

The scripts create two deployments:

- `PixiSecured`, which exposes the protected Pixi API (all API calls go through the API Firewall deployed in a sidecar mode)
- `Pixiapp`, which exposes the original, unprotected Pixi API so that you can directly invoke the vulnerable API

Both deployments are fronted by load balancers and point to a [MongoDB](https://www.mongodb.com/what-is-mongodb) deployed behind a service named `pixidb`.

![Demo architecture](/kubernetes-guides/graphics/42cMinikube-Pixi.png?raw=true "Demo architecture")

## Deployment steps

In this guide, we explain the deployment using plain YAML files. You can also deploy the artifacts using helm charts, available at [42Crunch/resources](https://github.com/42Crunch/resources/tree/master/helm/charts).

### Step 1 - Import Pixi API and generate a firewall configuration

1. Log in to 42Crunch Platform at <https://platform.42crunch.com>

2. Create an API collection called `PixiTest`.

3. Import the Pixi API definition from the file `OASFiles/Pixi-v2.0.json`.![Import API definition](/kubernetes-guides/graphics/42c_ImportOAS.png?raw=true "Import API definition")

   The API should score around 87/100 in API Contract Security Audit: the API contract description in this file has been optimized, in particular for data definition quality (such as inbound headers, query params, access tokens, and responses JSON schema).

4. In the main menu on the left, click **Protection** to create a firewall configuration for the API.

5. Select the `PixiTest` API collection, and the Pixi API, and enter a name for the protection token.
   This unique token tells the API Firewall instance which firewall configuration to run.
    ![Create protection configuration](/kubernetes-guides/graphics/42c_CreateProtection.png?raw=true "Create protection configuration")

6. Copy the protection token value to the clipboard. **Do not close this dialog** until you have safely saved the value (in the next step).
   ![Token value](/kubernetes-guides/graphics/42c_TokenToClipboard.png?raw=true "token value")

### Step 2- Configure the deployment scripts

You must configure the deployment scripts located under `minikube-artifacts` to use the API firewall configuration you just created and to successfully authenticate to DockerHub.

1. Go to edit the file `etc/secret-protection-token`.

2. Replace the placeholder `<your_token_value>` with the protection token you copied, and save the file:

    ```shell
        PROTECTION_TOKEN=<your_token_value>
    ```

3. Go to edit the file `etc/secret-docker-registry`.

4. Provide your credentials for DockerHub, and save the file - We recommend you use [Personal Access Tokens](https://docs.docker.com/docker-hub/access-tokens/) instead of passwords.

    ```shell
        REGISTRY_USERNAME=<your_user>
        REGISTRY_PASSWORD=<your_access_token>
    ```

    >Remember that **only registered users** on [42Crunch Platform](https://platform.42crunch.com) have the access to download the Docker images. If you have access to the 42Crunch platform but cannot access the Docker image, please open a ticket at : https://support.42crunch.com.

### Step 3 - Deploy the API Firewall

By default, the artifacts are deployed to a namespace called `42crunch`. If you want to change the namespace, edit the `etc/env` file and change the namespace before you run the script.

1. Before deploying the artifacts, ensure that `kubectl` is properly configured to point to the cluster you want to use. You can confirm this by running the command `kubectl config current-context`. The output should be similar to:

  ```text
  $ kubectl config current-context
  minikube
  ```

3. Depending on your operation system, run either the `pixi-create-demo.sh` or `pixi-create-demo.bat` script located under `minikube-artifacts`  to deploy the sample configuration. The script executes the following commands:

    ```shell
    # Create namespace
    kubectl create namespace $RUNTIME_NS
    ```
# Create secrets
    echo "===========> Creating Secrets"
    kubectl create --namespace=$RUNTIME_NS secret docker-registry docker-registry-creds --docker-server=$REGISTRY_SERVER --docker-username=$REGISTRY_USERNAME --docker-password=$REGISTRY_PASSWORD --docker-email=$REGISTRY_EMAIL
    kubectl create --namespace=$RUNTIME_NS secret tls firewall-certs --key ./etc/tls/private.key --cert ./etc/tls/cert-fullchain.pem
    kubectl create --namespace=$RUNTIME_NS secret generic generic-pixi-protection-token --from-env-file='./etc/secret-protection-token'
# Config Map creation
    echo "===========> Creating ConfigMap"
    kubectl create --namespace=$RUNTIME_NS configmap firewall-props --from-env-file='./etc/deployment.properties'
# Deployment (Required App/DB + storage)
    echo "===========> Deploying unsecured pixi and database"
    kubectl apply --namespace=$RUNTIME_NS -f pixi-basic-deployment.yaml
# Deployment (Pixi + FW)
    echo "===========> Deploying secured API firewall"
    kubectl apply --namespace=$RUNTIME_NS -f pixi-secured-deployment.yaml
    ```

> Should the scripts fail for any reason, you can start from a clean situation using the deletion scripts.
>

4. Once the deployment is complete, run `kubectl get pods -n 42crunch` to check that all pods are successfully running:

    ```shell
    NAME                            READY   STATUS    RESTARTS   AGE
    pixi-8c94b66b5-hq8js            1/1     Running   0          5m
    pixi-secured-54d957c8bc-h867f   2/2     Running   0          5m
    pixidb-755f648d47-k5pm9         1/1     Running   0          5m
    ```

    You can launch the Kubernetes default dashboard to see the list of services and deployments created in the 42crunch namespace:

    ![Kubernetes console - Overview](/kubernetes-guides/graphics/42c-ArtifactsUp.png?raw=true "Kubernetes console - Overview")

### Step 4 - Getting ready to test the firewall

You can test API Firewall using the Postman collection in this repository, or other tools like cURL or the Advanced REST Google Chrome plugin. This example uses the provided Postman collection.

1. Run `minikube service list -n 42crunch`.

   ```shell
   |-----------|--------------|-----------------------------|
   | NAMESPACE |     NAME     |             URL             |
   |-----------|--------------|-----------------------------|
   | 42crunch  | pixi-open    | http://192.168.99.103:30090 |
   | 42crunch  | pixi-secured | http://192.168.99.103:30443 |
   | 42crunch  | pixidb       | No node port                |
   |-----------|--------------|-----------------------------|                  
   ```

2. Edit your `hosts` file, and add the `pixi-secured` deployment to it. Replace the placeholder `<pixi-secu-ip>` below with the actual IP returned by the command above (in our case `192.168.99.103`).

   ```shell
   <pixi-secured-ip> 	pixi-secured.42crunch.test
   ```

3. Test that the setup is working by invoking http://pixi-secured.42crunch.test:30443 - You should receive a message like this one, indicating the firewall has blocked the request.

   `{"status":400,"title":"request fetching","detail":"Bad Request","instance":"https://pixi-secured.42crunch.test/","uuid":"227cc698-e60d-11e9-9b1c-55b33823ae8d"}`

4. Import the file `postman-collection/Pixi.postman_collection.json` in Postman, and go to the newly imported Pixi project.

5. Create  an [environment variable](https://learning.getpostman.com/docs/postman/variables-and-environments/variables/) called **42c_url** (inside an existing or new Postman environment), and set its value to https://pixi-secured.42crunch.test:30443 to invoke the protected API.

6. From Postman, invoke the operation `POST  /api/register` with the following contents

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

You should see a response similar to this. The `x-access-token` is a JWT that you must inject in an `x-access-token` header for all API calls (except login and register):

```json
{
    "message": "x-access-token: ",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxxx"
}
```

### Step 5 - Test API Firewall in action

42Crunch API Firewall validates API requests and responses according to the OpenAPI definition of the protected API. You can test the firewall behavior with the following requests:

1. Wrong verb: the operation `Register` is defined to use `POST`, try calling it with `GET` or other verbs, and see how requests are blocked.

    ![Postman wrong verb](/kubernetes-guides/graphics/42c_PostmanTest01-WrongVerb.png?raw=true "Postman wrong verb")

2. Wrong path: any request to a path _not_ defined in the OAS definition is blocked, try `/api/foo`, for example.

3. Wrong `Content-Type`: the OpenAPI definition states that the operation `/api/register` requires input in the form of `application/json`. If you use a different value or if you do not specify the `Content-Type`, the request is blocked.

4. Missing a parameter that the input JSON structure requires: the schema for the operation `/api/register` specifies that the parameters `user`, `name`, `email`, and `password` are mandatory. If you leave out any of these parameters, the request is blocked.

5. Wrong format for values: if you specify a value (such as email) in a format that does not match the schema, the request is blocked. For example, try to register a user with email `user@acme.com@presidence@elysee.fr` (you can read how this was exploited by hackers [here](https://apisecurity.io/issue-28-breaches-tchap-shopify-justdial/) ).

6. Injecting a negative balance: the 42Crunch API firewall also validates integer boundaries. If you try to invoke `api/register` using a negative balance (-100 for example), the request is blocked.

7. The Pixi API has a MongoDB injection vulnerability that allows logging into the application without specifying a password. You can try this by using the raw parameters `user=42crunch@getme.in&pass[$ne]=` in Postman for a login request. You will see that you can log in to the unprotected API, but the request is blocked by API Firewall on the protected API.

8. Reflected XSS attack: If you introduce a XSS attack like the example below, the request is blocked:

   ```script
   <script>alert('hi')</script>
   ```

### Step 6 - Viewing Transaction Logs

Whenever a request/response is blocked, transaction logs are automatically published to the 42Crunch platform. You can access the transaction logs viewer from the API protection tab. For each entry, you can view details information about the request and response step, as well as each step latency.

![](/kubernetes-guides/graphics/42c_logging.jpeg)

## Clean up

To delete all the artifacts you created, you can just delete the whole namespace with the command `kubectl delete namespace NAMESPACE`. If you used the default namespace, the command is:

 ```shell
    kubectl delete namespace 42crunch
 ```

If you want to delete the whole minikube environment, just execute

```shell
    minikube stop
    minikube delete
```
