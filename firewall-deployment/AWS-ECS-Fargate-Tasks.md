![42Crunch](./graphics/42c_logo.png?raw=true "42Crunch")

# 42Crunch API Firewall on Amazon ECS with Fargate (Tasks)

[TOC]

## Introduction

This document describes how to deploy and test [42Crunch](https://42crunch.com/) API Firewall in AWS ECS with Fargate. For more information on [42Crunch Platform](https://platform.42crunch.com) and [42Crunch API Firewall](https://docs.42crunch.com/latest/content/concepts/api_protection.htm#Firewall), take a look at the [platform documentation](https://docs.42crunch.com/).

> The example setup in this document uses the Pixi API, a deliberately **vulnerable** API created as part of the [OWASP DevSlop](https://devslop.co/Home/Pixi) project to demonstrate common API issues.

## Platform Overview

The 42Crunch platform provides tools to quickly protect APIs from typical threats, such as mass assignment, data leakage, exception leakage, or injections as described in the [OWASP Top10 for API Security](https://apisecurity.io/encyclopedia/content/owasp/owasp-api-security-top-10.htm). The platform was built to empower developers to become key actors of API security, enabling them to address security concerns as early as possible in the API lifecycle.

Typically, the platform would be used as follows:

* Developers describe precisely API contracts using the OpenAPI specification format (aka Swagger). This can be done via annotations in the API implementation code or using specialized tools such as SwaggerHub or Stoplight.
* The OpenAPI definition is imported into the 42Crunch platform and audited: the audit service analyses the definition and gives a security score from 0 to 100. The score is calculated based on how the API is secured (authentication, authorisation and transport of credentials) and how well the data is defined (parameters, headers, schemas, etc.). This only can be done manually via our SaaS console, via the developers favorite IDE or via CI/CD pipelines. The entire functionality is available via a REST API, so that bulk import and audit can be performed via scripting as well.
* Developers improve the score by following the remediation recommendations given in the audit reports until they reach a satisfactory score (usually above 75) and have fixed all critical/high severity issues.
* The resulting OpenAPI file now describes precisely the inputs and outputs of our API and as such can be used as a configuration [whitelist](https://42crunch.com/adopting-a-positive-security-model/) for the 42Crunch API threats protection engine (API Firewall).

## Goals

This document guides you through:

1. Installing pre-requisites
2. Configuring the APIFirewall task values
3. Testing the API Firewall

## Prerequisites
In this guide, we deploy the 42Crunch API firewall in sidecar proxy mode (co-located in the same pod as the API) and use AWS ECS on top of Fargate as container orchestrator.

Before you start, ensure you comply with the following pre-requisites:

### 42Crunch resources project

You need to clone the 42Crunch resources project located on Github (https://github.com/42Crunch/resources) to get a local copy of the artifacts used in this guide.

### 42Crunch platform account

You must be a registered user on the [42Crunch Platform](https://platform.42crunch.com) to follow this guide. If you do not have an account, you can self-register at https://platform.42crunch.com/register.

### Running as-root

The API Firewall is started by the `root` user. The initial process as root reads the configuration and then forks child processes which will serve the requests. Those child processes run under the `guardian` user, which has no admin privileges nor can this user read the configuration or log files. 

### SaaS platform connection

When the API firewall starts, it need to connect to our SaaS platform to a URL which varies depending on the platform you are using. Default is **[protection.42crunch.com](protection.42crunch.com/)** on port **8001**. Make sure your network firewall configuration authorizes this connection.

> This gRPC-based, secured connection is always established from the API firewall to the platform. Logs and configuration are uploaded/downloaded through this connection.

### Tools

We recommend you install [Postman](https://www.getpostman.com/downloads/) to drive test the API. A Postman collection is provided to you in this repository.

## Configuration Setup

Import the Pixi API and generate the protection configuration

1. Log in to 42Crunch Platform at <https://platform.42crunch.com> (or your assigned platform)

2. Go to **API Collections** in the main menu and click on **New Collection**, name it  PixiTest.

3. Click on **Add Collection**.

   ![](./graphics/create-collection.png)

4. Click on **Import API** to upload the Pixi API definition from the file `OASFiles/Pixi-v2.0.json`. Once the file is imported, it is automatically audited.![Import API definition](./graphics/42c_ImportOAS.png?raw=true "Import API definition")

   The API should score 89/100 in API Contract Security Audit: the API contract description in this file has been optimized, in particular for data definition quality (such as inbound headers, query params, access tokens, and responses JSON schema). This implies we can use it as-is to configure our firewall.

5. In the main menu on the left, click **Protect** to launch the protection wizard

6. Select the `PixiTest` API collection, and the Pixi API, and enter a name for the protection token. This unique token is used later in this guide to configure the API Firewall.
    ![Create protection configuration](./graphics/42c_CreateProtection.png?raw=true "Create protection configuration")

7. Copy the protection token value to the clipboard. **Do not close this dialog** until you have safely saved the value (in the next step).
   ![Token value](./graphics/42c_TokenToClipboard.png?raw=true "token value")

# Deployment Setup

For simplicity, the pixi app, the pixi db and the Firewall will be deployed in the same Fargate task. 

## Protection Token Setup

The protection token is used by the API Firewall to retrieve its configuration from the platform. Think of it as a unique ID for the API protection configuration.

You must save the protection token in a configuration file. This file is read by the deployment scripts to create a secret in AWS SecretsManager.

1. Edit  `variables.env` with any text editor.

2. Set the value of the `XLIIC_PROTECTION_TOKEN` environment variable to the protection token you copied, and save the file:

```shell
$ cat variables.env
XLIIC_PROTECTION_TOKEN=587b70da-730a-4ac3-a2c9-78a68553e87c
...
```

### Create an AWS secret for the Protection Token

1. Use the `create-aws-secrets.sh` script to push the protection-token to  AWS secrets manager. This script assumes you're logged into the AWS CLI and have enough permissions to create the resources.

   > This assumes you're are using the CLI to create the files. You can create those  secrets through different means than this script, for example the AWS Console.

2. Store the ARN value of the **42c-protection-token** secret in the AWS_SECRET_ARN environment variable of the `variables.env` file.

```shell
$ sh create-aws-secrets.sh 
===========> Creating AWS Secrets 
{
    "ARN": "arn:aws:secretsmanager:eu-west-2:000000000000:secret:42c-protection-token2-adLeD9",
    "Name": "42c-protection-token",
    "VersionId": "dcc3f2f9-75fc-43ae-a593-2cc3992bc60b"
}
$ cat variables.env
...
AWS_SECRET_ARN=arn:aws:secretsmanager:eu-west-2:000000000000:secret:42c-protection-token2-adLeD9
```

## TLS Setup

When TLS is used, TLS configuration files (including private key) must be placed on the file system (inside the docker image). API Firewall expects to find the TLS configuration files under `/opt/guardian/conf/ssl`.  

> API Firewall also support PKCS#11 - In this case, you need to use PKCS URI instead of file names https://tools.ietf.org/html/rfc7512 - 

 In this guide we are using self-signed certs for testing purposes, but you could LetsEncrypt certs for example. 

> If you are using certificates that are signed by a CA (and potentially have intermediary CAs), the firewall-cert.pem file must contain the full chain of certificates, sorted from leaf to root.

The task environment variables are set to use those filenames : **firewall-cert.pem** and **firewall-key.pem**. You can use different names, but will need to update the task definition later on.

### Producing self-signed cert/key pairs

Cert/key pairs can be produced in a number of ways, through specialized platforms and tools. In this guide, we use openssl to generate self-signed certs, like this:

1. Go to `etc/tls`
2. Run the following command

```shell
openssl req \
       -newkey rsa:2048 -nodes -keyout firewall-key.pem \
       -x509 -days 30 -out firewall-cert.pem
```

and respond to the setup questions. You can use any CN you want for the purpose of this guide, like **42crunch-firewall.local**.

## Build Firewall Image

1. Create a private repository named `42cfirewall` in Amazon Elastic Container Registry (https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html).
2. Edit the `variables.env` file and set the `AWS_ACCOUNT_ID` environment variable (without dashes!) and the `AWS_REGION` to the corresponding values of your AWS environment. Finally, you may modify the `AWS_REPOSITORY` variable to correspond to the repository name you just created and set a tag, for instance `latest`:

```shell
$ cat variables.env
...
AWS_ACCOUNT_ID=123456789012
AWS_REGION=eu-west-2
AWS_REPOSITORY=42cfirewall:latest
...
```
3. Execute `build-image.sh`. This script consists of three steps:
   * First, it will login docker to your AWS ECR environment
   * Then, it will build a Docker image for the firewall, setting the cert/key pair you created previously on the base 42Crunch API firewall image
   * Finally, it will upload this newly created image to the ECR registry.

## Prepare the AWS environment

Assuming the environment in which you're running the tutorial is new, you will need a cluster, a load balancer, a target group, and a security group.

* If you don't have an ECS cluster yet, now is the time to create a cluster, with default options (https://docs.aws.amazon.com/AmazonECS/latest/developerguide/create_cluster.html).
* Create a CloudWatch log group to receive the logs from the containers (for example, `ecs/firewall`), and modify accordingly the `AWS_LOG_GROUP` environment variable
* Create an ECS task execution role named `ecsTaskExecutionRole` that has `AmazonECSTaskExecutionRolePolicy`. If you are not using the `ecsTaskExecutionRole`, modify accordingly the `AWS_TASK_ROLE` value in `variables.env`. (https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html#create-task-execution-role)
* You will need to authorize access to the SecretsManager (https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data-secrets.html) to the ECS execution task role.
* If a load balancer isn't already configured to reach your ECS cluster, create an AWS Network Load Balancer to expose the firewall to the internet. The load balancer needs to be listening on port 443 and forwarding traffic to a 443 IP target group (https://docs.aws.amazon.com/elasticloadbalancing/latest/network/create-network-load-balancer.html)
* Create a security group that allows `HTTPS/443` from `0.0.0.0/0` as an inbound rule. Allow `All traffic` as an outbound rule. This security group will be used when creating the service.
  > There are many ways to deploy this setup, which will vary depending on your existing application architecture.  For example, you could use an application LB and terminate TLS at that level, or just do TCP load balancing in a network LB on port 443 so that the API Firewall terminates SSL.

# API Firewall Deployment

1. If required, the 42Crunch platform **protection endpoint** can be changed by modifying the `XLIIC_PLATFORM` environment variable in the  `variables.env` file. It should correspond to the 42Crunch platform you are using, should it be our customer platforms or a dedicated instance. If your platform is `acme.42crunch.com`, then the protection endpoint will be: `protection.acme.42crunch.com`. Port is always 8001. See the 42Crunch [documentation](https://docs.42crunch.com) for details.
   > You may need to open access to this hostname  in your firewall / network rules.

2. Edit `variables.env` to set the `AWS_SERVER_NAME` to the FQDN of the exposed service. If you created a load balancer, it will be the DNS name of this load balancer, for instance `lb-76f8ea9a4cf2f37a.elb.eu-west-2.amazonaws.com`.
   
3. We will now generate the Fargate task definition, by running the `create-task.sh` script. This script creates a task definition in the `task.json` file, from the `task.template` file and the environment variables you defined in `variables.env`.

4. Optional. API Firewall Environment variables

  In `task.json` you can see the specific environment variables used by 42Crunch API firewall. Here is their description.

   | ENVIRONMENT VARIABLE NAME | DESCRIPTION                                                  | SAMPLE VALUE (in Task JSON file)           |
   | ------------------------- | ------------------------------------------------------------ | ------------------------------------------ |
   | GUARDIAN_INSTANCE_NAME    | Unique instance name. Used in logs and UI                    | aws-fargate-instance                       |
   | GUARDIAN_NODE_NAME        | Unique node name (system/cluster the container runs on). Used in logs and UI | aws-fargate-node                           |
   | LISTEN_PORT               | Port the API Firewall listens on                             | 443                                        |
   | LISTEN_NO_TLS             | If this variable is present, the firewall starts in non-TLS mode. The LISTEN_SSL directives will be ignored. | enabled                                    |
   | LISTEN_SSL_CERT           | Name of API Firewall certificate file (in PEM format). The whole certificate chain must be stored in this file (CA, Intermediate CA, cert) - Must be present on filesystem and match the names used when building the firewall image | firewall-cert.pem                          |
   | LISTEN_SSL_KEY            | Name of API Firewall private key file (in PEM format) - Must be present on filesystem and match the names used when building the firewall image. | firewall-key.pem                           |
   | PRESERVE_HOST             | API Firewall passes Host header unchanged to back-end        | On                                         |
   | TARGET_URL                | Backend URL the API Firewall proxies requests to. Since the Pixi API runs in the same Task, we can use localhost over HTTP | http://localhost:8090                      |
   | SERVER_NAME               | External host name used to invoke APIs (for example apis.acme.com or 42c-fw-lb-xxxx.elb.eu-west-1.amazonaws.com) - API Firewall makes sure that all calls come with that value in the Host header. | 42c-fw-lb-xxxx.elb.eu-west-1.amazonaws.com |
   | TIMEOUT_IN                | How long (in seconds) API Firewall waits for a TCP packet from the client to arrive before closing the connection. | 30                                         |
   | TIMEOUT_KEEPALIVE         | How long API Firewall waits for any subsequent requests from the client before closing the connection. By default, the value is in seconds. To define the timeout in milliseconds, add `ms` after the value. | 5                                          |
   | LOG_DESTINATION           | Destination of transaction logs (FILES/PLATFORM)             | PLATFORM                                   |
   | LOG_LEVEL                 | Debug level (warn/info/notice/debug/trace5)                  | warn                                       |

Those values are part of the environment configuration of the API Firewall container setup:

```json
   "environment": [
           {
             "name": "GUARDIAN_INSTANCE_NAME",
             "value": "aws-fargate-instance"
           },
           {
             "name": "GUARDIAN_NODE_NAME",
             "value": "aws-fargate-node"
           },
           {
             "name": "LISTEN_PORT",
             "value": "443"
           },
           {
             "name": "LISTEN_SSL_CERT",
             "value": "firewall-cert.pem"
           },
           {
             "name": "LISTEN_SSL_KEY",
             "value": "firewall-key.pem"
           },
           {
             "name": "LOG_DESTINATION",
             "value": "PLATFORM"
           },
           {
             "name": "LOG_LEVEL",
             "value": "warn"
           },
           {
             "name": "PRESERVE_HOST",
             "value": "On"
           },
           {
             "name": "SERVER_NAME",
             "value": "${AWS_SERVER_NAME}"
           },
           {
             "name": "TARGET_URL",
             "value": "http://localhost:8090"
           },
           {
             "name": "TIMEOUT_IN",
             "value": "30"
           },
           {
             "name": "TIMEOUT_KEEPALIVE",
             "value": "5"
           }
```

5. You can now create a new task definition in ECS from JSON, by copy/pasting the content of the `task.json` file (https://docs.aws.amazon.com/AmazonECS/latest/developerguide/create-task-definition.html).
  
6. Once the task has been configured and saved, create a service from this task. Make sure that in the `Networking` section, it uses the security group you created. In the `Load Balancer` section, specify the network load balancer you created, and the corresponding target group. Then click deploy.

# Getting ready to test the API firewall

The service will start, and the three containers defined in the task definition (firewall, pixi app and pixi db) will start.

1. Test the secured endpoint setup by invoking the hostname you have set, for example by running the curl command: `curl -k https://lb-76f8ea9a4cf2f37a.elb.eu-west-2.amazonaws.com/`. You should receive a message like this one, indicating the firewall has blocked the request:
> The API Firewall is configured with a self-signed certificate. You may have to accept an exception for the request to work properly, depending on where TLS termination is happening.

```json
{"status":400,"title":"path mapping","detail":"Bad Request","uuid":"2ce6eef2-28f0-45b0-86b7-2fea77febf0c"}
```

2. Import the  `postman-collection/Pixi_collection.json` file in Postman using **Import>Import from File**.

3. Create  an [environment variable](https://learning.getpostman.com/docs/postman/variables-and-environments/variables/) called **42c_url** inside an environment called **42Crunch-Secure** and set its value to the value of SERVER_NAME  to invoke the protected API (for example `https://lb-76f8ea9a4cf2f37a.elb.eu-west-2.amazonaws.com`/).
   
   The final configuration should look like this in Postman:

![Postman-Secure-Generic](./graphics/Postman-AWSEnv.jpg)

4. Go to the Pixi collection you just imported and invoke the operation **POST /api/register** with the following contents:

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

    You should see a response similar to this. The x-access-token is a JWT that you must inject in an x-access-token header for all API calls (except login and register):

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

   ![42c_PostmanTest01-WrongVerb](./graphics/42c_PostmanTest01-WrongVerb.jpg)

2. **Wrong path**: any request to a path _not_ defined in the OAS definition is blocked, try `/api/foo`, for example.

3. **Wrong `Content-Type`**: the OpenAPI definition states that the operation `/api/register` requires input in the form of `application/json`. If you use a different value or if you do not specify the `Content-Type`, the request is blocked. The most famous attack based on crafting Content-Type value is [*CVE-2017-5638*](https://www.synopsys.com/blogs/software-security/cve-2017-5638-apache-struts-vulnerability-explained/), an issue in Apache Struts which is at the root of Equifax's and many others breaches.

4. **Missing a parameter** that the input JSON structure requires: the schema for the operation `/api/register` specifies that the parameters `user`, `name`, `email`, and `password` are mandatory. If you leave out any of these parameters, the request is blocked.

5. **Wrong format for string values**: if you specify a value (such as email) in a format that does not match the schema, the request is blocked. For example, try to register a user with email `user@acme.com@presidence@elysee.fr` (you can read how this was exploited by hackers [here](https://apisecurity.io/issue-28-breaches-tchap-shopify-justdial/) ).

6. **Blocking out of boundaries data**: the 42Crunch API firewall also validates integer boundaries. If you try to invoke `api/register` using a negative balance (-100) for example), the request is blocked. This prevents Overflow type attacks. Similarly, requests with strings which do not match the minLength/maxLength constraints are blocked.

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

![API5-BlockingRequest](./graphics/API5-BlockingRequest.jpg)

# Conclusion

In this evaluation guide, we have seen how the 42Crunch API firewall can be easily configured from an OAS file, with no need to write specific rules or policies. The OAS file acts as a powerful whitelist, thanks to the audit service which helps you pinpoint and remediate security issues.
