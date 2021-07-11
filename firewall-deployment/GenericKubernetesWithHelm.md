![](./graphics/42c_logo.png)

# Deploying 42Crunch API Firewall on a Kubernetes Cluster via Helm 3

## Introduction

This document describes how to deploy and test [42Crunch](https://42crunch.com/) API Firewall in a standard Kubernetes cluster using Helm 3. For more information on [42Crunch Platform](https://platform.42crunch.com) and [42Crunch API Firewall](https://docs.42crunch.com/latest/content/concepts/api_protection.htm#Firewall), take a look at the [platform documentation](https://docs.42crunch.com/).

> The example setup in this document uses the Pixi API, a deliberately **vulnerable** API created as part of the [OWASP DevSlop](https://devslop.co/Home/Pixi) project to demonstrate common API issues. **We recommend that you install the Pixi API in a dedicated Kubernetes cluster, and delete the cluster once your tests are completed.** Do not leave the unprotected Pixi API running, it is vulnerable!

## Platform Overview

The 42Crunch platform provides tools to quickly protect APIs from typical threats, such as mass assignment, data leakage, exception leakage, or injections as described in the [OWASP Top10 for API Security](https://apisecurity.io/encyclopedia/content/owasp/owasp-api-security-top-10.htm). The platform was built to empower developers to become key actors of API security, enabling them to address security concerns as early as possible in the API lifecycle.

Typically, the platform would be used as follows:

* Developers describe precisely API contracts using the OpenAPI specification format (aka Swagger). This can be done via annotations in the API implementation code or using specialized tools such as SwaggerHub or Stoplight.
* The OpenAPI definition is imported into the 42Crunch platform and audited: the audit service analyses the definition and gives a security score from 0 to 100. The score is calculated based on how the API is secured (authentication, authorisation and transport of credentials) and how well the data is defined (parameters, headers, schemas, etc.). This only can be done manually via our SaaS console, via the developers favorite IDE or via CI/CD pipelines. The entire functionality is available via a REST API, so that bulk import and audit can be performed via scripting as well.
* Developers improve the score by following the remediation recommendations given in the audit reports until they reach a satisfactory score (usually above 75) and have fixed all critical/high severity issues.
* The resulting OpenAPI file now describes precisely the inputs and outputs of our API and as such, can be used as an [allowlist](https://42crunch.com/adopting-a-positive-security-model/) for the 42Crunch API threats protection engine (API Firewall).

## Goals

This document guides you through:

1. Getting your Kubernetes cluster ready.
2. Importing an API contract into our SaaS platform and configuring the protection.
3. Deploying the unsecured API (Pixi API).
4. Deploying the 42Crunch API firewall protecting the unsecured API.
5. Testing the 42Crunch API Firewall in action.

## Prerequisites

In this guide, we deploy the 42Crunch API firewall in sidecar proxy mode (co-located in the same pod as the API) and use Kubernetes as orchestrator as well as Helm v3. You need a basic understanding of [Kubernetes concepts](https://kubernetes.io/docs/concepts/) and Helm v3 before running this guide.

Before you start, ensure you comply with the following pre-requisites:

### 42Crunch resources project

You need to clone the 42Crunch resources project located on Github (https://github.com/42Crunch/resources) to get a local copy of the artifacts used in this guide.

### 42Crunch platform account

You must be a registered user on the [42Crunch Platform](https://platform.42crunch.com) to follow this guide. If you do not have an account, you can self-register at https://platform.42crunch.com/register.

### Kubernetes cluster
This guide assumes that you already have a Kubernetes cluster running and you have proper credentials to deploy apps into that cluster.

### Helm Installation
Deployment templates have been tested with Helm v3.2.

### Running as-root

The API Firewall is started by the `root` user. The initial process as root reads the configuration and then forks child processes which will serve the requests. Those child processes run under the `guardian` user, which has no admin privileges nor can this user read the configuration or log files. 

### Access to DockerHub 

Images are pulled from DockerHub. Make sure your Kubernetes cluster can reach it. Otherwise, get the docker images from DockerHub, store them in your registry of choice and edit both `values.yaml` files (one for each deployment) to point to the proper registry, for example:

```yaml
image:
  repository: myregistry/42c-apifirewall
  version: latest
```

### SaaS platform connection

When the API firewall starts, it need to connect to our SaaS platform to a URL which varies depending on the platform you are using. Default is **[protection.42crunch.com](protection.42crunch.com/) on port \**8001\**. Make sure your network firewall configuration authorizes this connection.**

> **This gRPC-based, secured connection is always established from the API firewall to the platform. Logs and configuration are uploaded/downloaded through this connection.**

If your company is hosted on a different 42Crunch SaaS instance, you can edit the `firewall-deployment/helm-artifacts/42c-evalguide/charts/protected-pixi/values.yaml`file and override this entry.

```yaml
platform:
  url: protection.42crunch.com:8001
```

### Tools

We recommend you install [Postman](https://www.getpostman.com/downloads/) to drive test the API. A Postman collection is provided to you in this repository.

## Deployment artifacts

The deployment involves two types of artifacts: configuration artifacts and runtime artifacts. The scripts and conf files for Helm-based deployment are located under `helm-artifacts`.

### Configuration artifacts

The following configuration artifacts are created when you execute the deployment scripts:

- A TLS secret that contains the key-cert pair to protect the listening interface of the API firewall. The key-cert pair is automatically created via a Helm [webhook](https://helm.sh/docs/topics/charts_hooks/) using a self-signed CA.
- A generic secret that contains the protection token identifying the API firewall configuration to run.
- A config map which contains properties that affect how the firewall gets configured at deployment time. 

### Runtime artifacts

The Helm charts create two deployments:
- `pixi-secured`, which exposes the protected Pixi API (all API calls go through the API Firewall deployed in sidecar mode)
- `pixi-open`, which exposes the original, unprotected Pixi API so that you can directly invoke the vulnerable API to contrast the protected vs. unprotected behavior.

Both deployments are fronted by load balancers and point to a [MongoDB](https://www.mongodb.com/what-is-mongodb) deployed behind a service named `pixidb`.

![Demo architecture](./graphics/GenericDeployment.png?raw=true "Demo architecture")

### Helm artifacts 

The main chart is called `42c-evalguide`. At install time, it creates all the artefacts above, including the secrets.

## Configuration Setup

### Import the Pixi API and generate the protection configuration

1. Log in to 42Crunch Platform at <https://platform.42crunch.com>

2. Go to **API Collections** in the main menu and click on **New Collection**, name it PixiTest.

3. Click on **Add Collection**.

   ![](./graphics/create-collection.png)

4. Click on **Import API** to upload the Pixi API definition from the file `OASFiles/Pixi-v2.0.json`. Once the file is imported, it is automatically audited.

![Import API definition](./graphics/42c_ImportOAS.png?raw=true "Import API definition")

The API should score around 94/100 in API Contract Security Audit: the API contract description in this file has been optimized, in particular for data definition quality (such as inbound headers, query params, access tokens, and responses JSON schema). This implies we can use it as-is to configure our firewall.

5. In the main menu on the left, click **Protect** to launch the protection wizard

6. Select the `PixiTest` API collection, and the Pixi API, and enter a name for the protection token. This unique token is used later in this guide to configure the API Firewall.
   ![Create protection configuration](./graphics/42c_CreateProtection.png?raw=true "Create protection configuration")

7. Copy the protection token value to the clipboard. **Do not close this dialog** until you have safely saved the value (in the next step).
   ![Token value](./graphics/42c_TokenToClipboard.png?raw=true "token value")

# Configuration Deployment

> *This deployment uses a specific namespace called `42crunch`. This means that you can deploy the artifacts in an existing Kubernetes cluster without overlapping other existing artifacts.*
>*If you want to change this name, change the value of the **--namespace** parameter passed to Helm below.*

1. Before deploying the artifacts, ensure that `kubectl` is properly configured to point to the cluster you want to use. To do this, run the following:

   ```shell
   kubectl config current-context
   ```
   For example, if you're running a GKE cluster, you should get an answer like:

   ```shell
   kubectl config current-context
   gke_pixi-deploy_europe-west6-a_xxxx
   ```

2. Install the Helm chart, passing the protection token you copied above as a parameter, like this: 

   ```shell
   helm install evalguide  ./42c-evalguide  --namespace 42crunch --create-namespace --set-string protected-pixi.apifirewall.protection_token=xxxxxx-e9e6-41e8-86d4-777cc54a6dd7
   ```

   This installs a release called **evalguide** and automatically creates the 42crunch namespace at install time. 

3. Run `kubectl get pods -w -n 42crunch`  and wait until all pods are successfully running. It takes usually a couple minutes the first time, since the docker images must be pulled from the DockerHub registry.	

   ```shell
   NAME                                      READY   STATUS        RESTARTS   AGE
   evalguide-pixi-open-c75c48977-wtkww       1/1     Running       0          5m2s
   evalguide-pixi-secured-648b86dcb8-8xpkv   2/2     Running       0          34s
   evalguide-pixidb-68f7fbf6c8-bhftt         1/1     Running       0          5m2s
   ```

4. Back in the SaaS platform, you can see a new entry under **Protection-Active instances**. Note the ServerName value. 
   ![InstancesList](./graphics/InstancesList.jpg)

# Preparing to test the API firewall

We now have a running configuration with two endpoints: one that invokes the unsecured API and the other one that invokes the secured API.

1. Run `kubectl get svc -n 42crunch` to get the external IP of the `pixisecured` deployment (values shown here are placeholders):

   ```shell
   NAME                        TYPE           CLUSTER-IP     EXTERNAL-IP             
   evalguide-open-service      LoadBalancer   10.0.228.131   <pixi-open-ip> 
   evalguide-secured-service   LoadBalancer   10.0.85.77     <pixi-secured-ip>  
   pixidb                      ClusterIP      10.0.254.59    <none>         
   ```

2. [Edit your `hosts` file](https://support.rackspace.com/how-to/modify-your-hosts-file/) and add the `pixi-secured` and `pixi-open` services endpoints to it. Replace the placeholder `<pixi-secured-ip>` below with the actual IP returned by the command above and repeat for the `pixi-open-ip` endpoint.

   ```shell
   <pixi-secured-ip> 	pixi-secured.42crunch.test
   <pixi-open-ip> 			pixi-open.42crunch.test
   ```

   Save your hosts file.

3. Test the open endpoint setup by invoking http://pixi-open.42crunch.test:8090 - You should receive a message like this one, indicating you have connected to the API.

   ```json
   {
     "message": "Welcome to the Pixi API, use /api/login using x-www-form-coded post data, user : email, pass : password - Make sure when you authenticate on the API you have a header called x-access-token with your token"
   }
   ```

4. Test the secured endpoint setup by invoking https://pixi-secured.42crunch.test - You should receive a message like this one, indicating the firewall has blocked the request.

   > The API Firewall is configured with a self-signed certificate. You will have to accept an exception for the request to work properly.

   ```json
   {"status":404,"title":"path mapping","detail":"Not Found","uuid":"628d7d3c-dd77-471a-8246-62885c71893b"}
   ```
   
   You can also use curl to make the same request, using the -k option to avoid the self-signed certificates issue: `curl -k https://pixi-secured.42crunch.test`
   
5. Import the  `postman-collection/Pixi_collection.json` file in Postman using **Import>Import from File**.

6. Import the `42Crunch-Secure.json` and `42Crunch-Unsecure.json` environment files using **Import>Import from File**.

   The final configuration should look like this in Postman:

   ![Postman-Unsecure](./graphics/Postman-Unsecure-Generic.jpg)

   ![Postman-Secure](./graphics/Postman-Secure-Generic.jpg)

7. Select the **42Crunch-Secure** environment

8. Invoke the operation `POST /api/register` with the following contents

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

  You should see a response similar to this. The `x-access-token` is a JWT that you must inject in an `x-access-token` header for all API calls (except login and register):

  ```json
    {
      "message": "x-access-token: ",
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxxx"
    }
  ```

Now that we know everything works, we can start testing the API Firewall.

# Blocking attacks with API Firewall

42Crunch API Firewall validates API requests and responses according to the OpenAPI definition of the protected API. In this section, you send various malicious requests to the API firewall to test its behavior.

## Viewing Transaction Logs

Whenever a request/response is blocked, transaction logs are automatically published to the 42Crunch platform. You can access the transaction logs viewer from the API protection tab. For each entry, you can view details information about the request and response step, as well as each step latency.

![](./graphics/42c_logging.jpeg)

## Understanding Pixi

Pixi requires to register or login users to obtain a token, token which is then used to invoke other operations. The Postman has been setup to extract the token from login or register responses and add them automatically to the **current environment**, like this:

```javascript
var jsonData = pm.response.json();
pm.globals.set("token", jsonData.token);
```

Other operations, such getUserInfo or updateUserInfo take the value of the **token** variable set above and use it as the value of the **x-access-token** header, like this:

![Token Variable](./graphics/Postman_TokenValue.png)

Make sure you always call either login or register before calling any other operations, or the request will fail at the firewall level, since the x-access-token header will be empty! When this happens, this is what you will see in the transaction logs of the API firewall .

![BadAccessToken](./graphics/BadAccessToken.png)

## Blocking Pixi API sample attacks

You can test the API firewall behavior with the following requests:

1. **Wrong verb**: the operation `Register` is defined to use `POST`, try calling it with `GET` or other verbs, and see how requests are blocked.

    ![Postman wrong verb](./graphics/42c_PostmanTest01-WrongVerb.png?raw=true "Postman wrong verb")

2. **Wrong path**: any request to a path _not_ defined in the OAS definition is blocked, try `/api/foo`, for example.

3. **Wrong `Content-Type`**: the OpenAPI definition states that the operation `/api/register` requires input in the form of `application/json`. If you use a different value or if you do not specify the `Content-Type`, the request is blocked. The most famous attack based on crafting Content-Type value is [*CVE-2017-5638*](https://www.synopsys.com/blogs/software-security/cve-2017-5638-apache-struts-vulnerability-explained/), an issue in Apache Struts which is at the root of Equifax's and many others breaches.

4. **Missing a parameter** that the input JSON structure requires: the schema for the operation `/api/register` specifies that the parameters `user`, `name`, `email`, and `password` are mandatory. If you leave out any of these parameters, the request is blocked.

5. **Wrong format for string values**: if you specify a value (such as email) in a format that does not match the schema, the request is blocked. For example, try to register a user with email `user@acme.com@presidence@elysee.fr` (you can read how this was exploited by hackers [here](https://apisecurity.io/issue-28-breaches-tchap-shopify-justdial/) ).

6. **Blocking out of boundaries data**: the 42Crunch API firewall also validates integer boundaries. If you try to invoke `api/register` using a negative balance (-100) for example), the request is blocked. This prevents Overflow type attacks.  Similarly, requests with strings which do not match the minLength/maxLength constraints are blocked.

7. **Blocking exception leakage**: the 42Crunch APIfirewall prevents data leakage or exception leakage. If you invoke `/api/register` using a negative balance between -50 and -1 , the response will be blocked. The backend API does not properly handle negative values and returns an exception. That exception is blocked by the firewall since the schema from the OAS file does not match the actual response.

8. **Blocking data leakage**: the Pixi API exposes an admin operation which lists all users within the database. This operation leaks admin status and passwords (it is a straight export from the backend database). If you invoke `API 5: Get Users List`, the response is blocked. You get an HTTP 502 error since the response from the back-end is invalid.

   ![API5-AdminOperation](./graphics/API5-AdminOperation.png)

9. The Pixi API has a **MongoDB injection** vulnerability that allows logging into the application without specifying a password. You can try this by using the raw parameters `user=user@acme.com&pass[$ne]=` in Postman for a login request. You will see that you can log in to the unprotected API, but the request is blocked by API Firewall on the protected API.

10. **Mass assignment**:  the `API6: Mass Assignment` operation can be used to update a user record. It has a common issue (described in this [blog](https://42crunch.com/stopping_harbor_registry_attack/) ) by which a hacker with a valid token can change their role or administrative status. The OAS file does not declare is_admin as a valid input and as such this request will be blocked. Same occurs with the password. If you remove those two properties, the request will be accepted and both email and name are updated for the logged in user.

  ![42c_API6BVulnerability](./graphics/42c_API6BVulnerability.png)

11. Reflected **XSS attack**: If you introduce a XSS attack like the example below in any property, the request is blocked:

    ```script
    <script>alert('hi')</script>
    ```

## Blocking admin operations

You have been able previously to invoke the `API5: Get Users List` admin operation, due to the fact it's declared in the Pixi OAS file. Although we blocked the response and prevented critical data from leaking, ideally we do not want this operation to be available. As such, we are going to replace the current OAS file, then update the configuration live.

1. Go to https://platform.42crunch.com and locate the Pixi API

2. At the top-right, select the Settings icon and choose **Update Definition**

   ![](./graphics/API6-UpdateDefinition.png)

3. Browse to the `resources/OASFiles` folder and select the `Pixi-v2.0-noadmin.json` file

4. Once the file has been imported, select the **Protection** tab

5. Click the **Reconfigure** button and type *confirm* to confirm the instance update

6. When the instance's list refreshes, it means the re-configuration was successful.

7. Back to Postman, try to invoke the `API5:Get Users list` operation. This time, the request is blocked with a 404 code, since this operation is not defined in the OpenAPI file anymore.

![API5-BlockingRequest](./graphics/API5-BlockingRequest.png)

# Conclusion

In this deployment guide, we have seen how the 42Crunch API firewall can be easily configured from an OAS file, with no need to write specific rules or policies and then deployed as sidecar proxy. The OAS file acts as a powerful whitelist, thanks to the audit service which helps you pinpoint and remediate security issues.

# Clean up

To delete all the artifacts you created, just uninstall the release and  delete the namespace:

 ```shell
    helm uninstall evalguide
    kubectl delete namespace 42crunch
 ```

