![42Crunch](/kubernetes-guides/graphics/42c_logo_lighta.png?raw=true "42Crunch")

# Deploying 42Crunch API Firewall on Azure Kubernetes Service (AKS)

## Introduction

This document describes how to deploy and test [42Crunch](https://42crunch.com/) API Firewall in [Azure Kubernetes Service (AKS)](https://azure.microsoft.com/en-us/services/kubernetes-service/). For more information on [42Crunch Platform](https://platform.42crunch.com) and [42Crunch API Firewall](https://docs.42crunch.com/latest/content/concepts/api_protection.htm#Firewall), take a look at the [platform documentation](https://docs.42crunch.com/).

The example setup in this document uses the Pixi API, a deliberately **vulnerable** API created as part of the [OWASP DevSlop](https://devslop.co/Home/Pixi) project to demonstrate common API issues. **We recommend that you install the Pixi API in a dedicated Kubernetes cluster, and delete the cluster once your tests are completed.** Do not leave the unprotected Pixi API running, it is vulnerable!

## Goals

The goals for this guide are to help you:

1. Get an AKS cluster running.
2. Deploy unsecured API (Pixi API).
3. Deploy the 42Crunch API firewall protecting the unsecured API.
4. Test [42Crunch Platform](https://platform.42crunch.com) in action.

## Prerequisites

Before you start, ensure you have the following.

### 42Crunch platform account

You must be a registered user on the [42Crunch Platform](https://platform.42crunch.com) to follow this guide. If you do not have an account, contact us at sales@42crunch.com.

### Access to 42Crunch API firewall Docker image
The 42Crunch API firewall image is located on a private DockerHub repository: an access to this repository must have been granted to you. If you are an existing platform user but cannot access the Docker image, send a mail to: support@42crunch.com.

### AKS Kubernetes cluster

You must have an AKS Kubernetes cluster running, and proper credentials to deploy the artifacts to tha cluster. If you don't already have one, you can create one in 3 easy steps:

1. Install [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest).

2. Run the command `az login` to log into your Azure account.

3. Run the following commands to generate a minimal K8s cluster and connect to it. You must have sufficient privileges to run those commands!

    ```shell
        az group create --name rg-42crunch --location eastus
        az aks create \
            --resource-group rg-42crunch \
            --name aks-42crunch \
            --node-count 1 \
            --enable-addons monitoring \
            --generate-ssh-keys
    ```
    

 You can use the command `az account list-locations` to list all the locations for your Azure cluster, and change the value to the one that suits you best. After a few minutes, we should have a Kubernetes environment ready for testing. 
    
4. Setup kubectl to point to your newly created cluster

4. ```shell
az aks get-credentials --resource-group rg-42crunch --name aks-42crunch
  ```

5. Check kubectl is properly configured by running `kubectl get nodes`

   ```shell
   NAME                       STATUS   ROLES   AGE     VERSION
   aks-nodepool1-XXXXXXXX-0   Ready    agent   5h43m   v1.13.10
   ```

### Also recommended

- [Postman](https://www.getpostman.com/downloads/) for testing the deployment.
- Basic understanding of [Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/) and [Kubernetes concepts](https://kubernetes.io/docs/concepts/).

## Deployment artifacts

The deployment involves two types of artifacts: configuration artifacts and runtime artifacts.

### Configuration artifacts

The following configuration artifacts are created when you execute the deployment scripts:

- A Docker registry secret that contains the information for the DockerHub connection to pull firewall images.
- A TLS secret that contains the key-cert pair to protect the listening interface of the firewall. The key-cert pair is signed with an ephemeral CA and has been created for the hostname `pixi-secured.42crunch.test`. You can find the keys and certs under `etc/tls`.
- A generic secret that contains the protection token identifying the firewall configuration to run.
- A config map that is populated from the file `deployment.properties`.

All artifacts are stored under the kubernetes-artifacts folder.

### Runtime artifacts

The deployment scripts create two deployments:

- `PixiSecured`, which exposes the protected Pixi API (all API calls go through the API Firewall deployed in a sidecar mode)
- `Pixiapp`, which exposes the original, unprotected Pixi API so that you can directly invoke the vulnerable API

Both deployments are fronted by load balancers and point to a [MongoDB](https://www.mongodb.com/what-is-mongodb) deployed behind a service named `pixidb`.

![Demo architecture](/kubernetes-guides/graphics/42cAKS-Pixi.png?raw=true "Demo architecture")

## Deployment steps

In this guide, we explain the deployment using plain YAML files. You can also deploy the artifacts using helm charts, available at [42Crunch/resources](https://github.com/42Crunch/resources/tree/master/helm-artifacts).

### Step 1 - Import Pixi API and generate a firewall configuration

1. Log in to 42Crunch Platform at <https://platform.42crunch.com>

2. Create an API collection called `PixiTest`.

3. Import the Pixi API definition from the file `OASFiles/Pixi-v2.0.json`.![Import API definition](/kubernetes-guides/graphics/42c_ImportOAS.png?raw=true "Import API definition")

   The API should score around 87/100 in API Contract Security Audit: the API contract description in this file has been optimized, in particular for data definition quality (such as inbound headers, query params, access tokens, and responses JSON schema).

4. In the main menu on the left, click **Protection** to create a firewall configuration for the API.

5. Select the `PixiTest` API collection, and the Pixi API, and enter a name for the protection token.
   This token tells the API Firewall instance which firewall configuration to run.
    ![Create protection configuration](/kubernetes-guides/graphics/42c_CreateProtection.png?raw=true "Create protection configuration")

6. Copy protection token value to the clipboard. **Do not close this dialog** until you have safely saved the value (in the next step).
   ![Token value](/kubernetes-guides/graphics/42c_TokenToClipboard.png?raw=true "token value")

### Step 2- Configure the deployment scripts

You must configure the deployment scripts to use the firewall configuration you just created and to successfully authenticate to DockerHub.

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

    >Remember that **only registered users** on [42Crunch Platform](https://platform.42crunch.com) have the access to download the Docker images.
    >If you have an existing user but cannot access the Docker image, please contact support@42crunch.com.

### Step 3 - Deploy the API Firewall

By default, the artifacts are deployed to a namespace called `42crunch`. If you want to change the namespace, edit the `etc/env` file and change the namespace before you run the script.

1. Before deploying the artifacts, ensure that `kubectl` is properly configured to point to the cluster you want to use. You can confirm this by running the command `kubectl cluster-info`. The output should be similar to:

    ```text
        $ kubectl cluster-info
        Kubernetes master is running at https://aks-42crun-rg-42crunch-######-########.hcp.eastus.azmk8s.io:443
        CoreDNS is running at https://aks-42crun-rg-42crunch-######-########.hcp.eastus.azmk8s.io:443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
        kubernetes-dashboard is running at https://aks-42crun-rg-42crunch-######-########.hcp.eastus.azmk8s.io:443/api/v1/namespaces/kube-system/services/kubernetes-dashboard/proxy
        Metrics-server is running at https://aks-42crun-rg-42crunch-######-########.hcp.eastus.azmk8s.io:443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy
    ```

2. Depending on your environment, run either the `pixi-create-demo.sh` or `pixi-create-demo.bat` script to deploy the sample configuration:

    ```shell
        # Create the 42crunch namespace - Edit the env file is you want to change it
        kubectl create namespace $RUNTIME_NS

        # Create secrets
        kubectl create --namespace=$RUNTIME_NS secret docker-registry docker-registry-creds --docker-server=$REGISTRY_SERVER --docker-username=$REGISTRY_USERNAME --docker-password=$REGISTRY_PASSWORD --docker-email=$REGISTRY_EMAIL
        kubectl create --namespace=$RUNTIME_NS secret tls guardiancerts --key ../etc/tls/private.key --cert ../etc/tls/cert-fullchain.pem
        kubectl create --namespace=$RUNTIME_NS secret generic protection-token --from-env-file=../etc/secret-protection-token

        # Config Map creation
        kubectl create --namespace=$RUNTIME_NS configmap firewall-props --from-env-file=./deployment.properties

        # Deployment (Required App/DB + storage)
        kubectl apply --namespace=$RUNTIME_NS -f pixi-basic-deployment.yaml

        # Deployment (Pixi + FW as sidecar pod)
        kubectl apply --namespace=$RUNTIME_NS -f pixi-secured-deployment.yaml
    ```

3. Once the deployment is complete, run `kubectl get pods -n 42crunch` to check that all pods are successfully running:

    ```shell
        NAME                            READY   STATUS    RESTARTS   AGE
        pixi-8c94b66b5-hq8js            1/1     Running   0          5m
        pixi-secured-54d957c8bc-h867f   2/2     Running   0          5m
        pixidb-755f648d47-k5pm9         1/1     Running   0          5m
    ```

4. If you want to see/monitor the various artifacts which have been created (pods, services, deployments and secrets), you can launch the Kubernetes standard dashboard, like this:

    ```az aks browse --resource-group rg-42crunch --name aks-42crunch```

    Then, change the default namespace to 42crunch to browse all artifacts.

    > If you get authorization issues in the dashboard, see those instructions: https://docs.microsoft.com/en-us/azure/aks/kubernetes-dashboard.


### Step 4 - Getting ready to test the firewall

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

3. Import the file `postman-collection/Pixi_collection.json` in Postman, and go to the newly imported Pixi project.

4. Create an environment variable called **42c_url**, and set its value to <https://pixi-secured.42crunch.test> to invoke the protected API, or to <http://pixi-direct.42crunch.test:8090> to invoke the unprotected API directly.

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

You should see a response similar to this. This `x-access-token` is a JWT that you must inject in an `x-access-token` header for all API calls (except login and register):
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

    The corresponding trace of the blocked API call in the transaction logs of the protected API on the platform UI:

    ![Postman wrong verb trace](/kubernetes-guides/graphics/42c_PostmanTest01-WrongVerb-Console.png?raw=true "Postman wrong verb trace")

2. Wrong path: any request to a path _not_ defined in the OAS definition is blocked, try `/api/foo`, for example.

3. Wrong `Content-Type`: the OpenAPI definition states that the operation `/api/register` requires input in the form of `application/json`. If you use a different value or if you do not specify the `Content-Type`, the request is blocked.

4. Missing a parameter that the input JSON structure requires: the schema for the operation `/api/register` specifies that the parameters `user`, `name`, `email`, and `password` are mandatory. If you leave out any of these parameters, the request is blocked.

5. Wrong format for values: if you specify a value (such as email) in a format that does not match the schema, the request is blocked. For example, try to register a user with email `user@acme.com@presidence@elysee.fr` (you can read how this was exploited by hackers [here](https://apisecurity.io/issue-28-breaches-tchap-shopify-justdial/) ).

6. Injecting a negative balance: the 42Crunch API firewall also validates integer boundaries. If you try to invoke `api/register` using a negative balance (-100 for example), the request is blocked.

7. The Pixi API has a MongoDB injection vulnerability that allows logging into the application without specifying a password. You can try this by using the raw parameters `user=user@acme.com&pass[$ne]=` in Postman for a login request. You will see that you can log in to the unprotected API, but the request is blocked by API Firewall on the protected API.

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

If you want to delete just the cluster created, run the command `az aks delete --resource-group RG-NAME --name CLUSTER-NAME`. If you used the names suggested in these examples, the command is:

```shell
    az aks delete --resource-group rg-42crunch --name aks-42crunch
```
