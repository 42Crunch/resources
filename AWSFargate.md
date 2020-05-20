![42Crunch](./graphics/42c_logo.png?raw=true "42Crunch")

# Deploying 42Crunch API Firewall on AWS Fargate

[TOC]

## Introduction

This document describes how to deploy and test [42Crunch](https://42crunch.com/) API Firewall in AWS Fargate. For more information on [42Crunch Platform](https://platform.42crunch.com) and [42Crunch API Firewall](https://docs.42crunch.com/latest/content/concepts/api_protection.htm#Firewall), take a look at the [platform documentation](https://docs.42crunch.com/).

> The example setup in this document uses the Pixi API, a deliberately **vulnerable** API created as part of the [OWASP DevSlop](https://devslop.co/Home/Pixi) project to demonstrate common API issues.
>

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
In this guide, we deploy the 42Crunch API firewall in sidecar proxy mode (co-located in the same pod as the API) and use AWS Fargate as container orchestrator.

Before you start, ensure you comply with the following pre-requisites:

### 42Crunch resources project

You need to clone the 42Crunch resources project located on Github (https://github.com/42Crunch/resources) to get a local copy of the artifacts used in this guide.

### 42Crunch platform account

You must be a registered user on the [42Crunch Platform](https://platform.42crunch.com) to follow this guide. If you do not have an account, you can self-register at https://platform.42crunch.com/register.

### Tools

We recommend you install [Postman](https://www.getpostman.com/downloads/) to drive test the API. A Postman collection is provided to you in this repository.

## Configuration Setup

Import the Pixi API and generate the protection configuration

1. Log in to 42Crunch Platform at <https://platform.42crunch.com>

2. Go to **API Collections** in the main menu and click on **New Collection**, name it  PixiTest.

3. Click on **Add Collection**.

   ![](./graphics/create-collection.png)

4. Click on **Import API** to upload the Pixi API definition from the file `OASFiles/Pixi-v2.0.json`. Once the file is imported, it is automatically audited.![Import API definition](./graphics/42c_ImportOAS.png?raw=true "Import API definition")

   The API should score around 89/100 in API Contract Security Audit: the API contract description in this file has been optimized, in particular for data definition quality (such as inbound headers, query params, access tokens, and responses JSON schema). This implies we can use it as-is to configure our firewall.

5. In the main menu on the left, click **Protect** to launch the protection wizard

6. Select the `PixiTest` API collection, and the Pixi API, and enter a name for the protection token. This unique token is used later in this guide to configure the API Firewall.
    ![Create protection configuration](./graphics/42c_CreateProtection.png?raw=true "Create protection configuration")

7. Copy the protection token value to the clipboard. **Do not close this dialog** until you have safely saved the value (in the next step).
   ![Token value](./graphics/42c_TokenToClipboard.png?raw=true "token value")

# Deployment Setup

For simplicity, the pixi app, the pixi db and the FW have been deployed in the same Fargate task. 

## Protection Token Setup

The protection token is used by the API Firewall to retrieve its configuration from the platform. Think of it as a unique ID for the API protection configuration.

You must save the protection token in a configuration file. This file is read by the deployment scripts to create a secret in AWS SecretsManager.

1. Edit  `etc/secret-protection-token` with any text editor.

2. Replace the placeholder `<your_token_value>` with the protection token you copied, and save the file:

```shell
<your_token_value>
```

### Create the Protection Token secret

1. Use the `create-aws-secrets.sh` script the protection-token to the AWS secrets manager. This script assumes you're logged in to AWS CLI and have enough permissions to create the resources.

   > This assumes you're are using the CLI to create the files. You can create those  secrets through different means than this script.

2. Note the ARN value of the **pixi-fw-token** secret. You will need it later to configure the API FW task.

   ```JSON
   {
       "ARN": "arn:aws:secretsmanager:eu-west-1:749000xxxxx:secret:pixi-fw-token-OLHpnL",
       "Name": "pixi-fw-token",
       "VersionId": "7fe79bc2-xxxx-4969-a2cc-7c9f6fe38433"
   }
   ```

## TLS Setup

API firewall only works in TLS mode. The TLS configuration files (including private key) must be placed on the file system (inside the docker image). API Firewall expects to find the TLS configuration files under `/opt/guardian/conf/ssl`.  

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

## Build POC Image

Use the `build.sh` script to build a Docker image which adds the cert/key pair you created previously to the base 42Crunch API firewall image.

Then, publish this image to your AWS container registry and record the image name, as per those instructions: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html.

# API Firewall Task configuration 

You need to make the following changes to the `task.json` file that was shared with you.

1. apifirewall image value needs to be changed to point to the  image created above:

   ```JSON
   {
     ...
       "image": "749000xxxxx.dkr.ecr.eu-west-1.amazonaws.com/42c-fw:latest",
     ...
   }
   ```

2. Environment variables

   | ENVIRONMENT VARIABLE NAME | DESCRIPTION                                                  | SAMPLE VALUE (in Task JSON file)           |
   | ------------------------- | ------------------------------------------------------------ | ------------------------------------------ |
   | GUARDIAN_INSTANCE_NAME    | Unique instance name. Used in logs and UI                    | aws-fargate-instance                       |
   | GUARDIAN_NODE_NAME        | Unique node name (system/cluster the container runs on). Used in logs and UI | aws-fargate-node                           |
   | LISTEN_PORT               | Port the API Firewall listens on                             | 443                                        |
   | LISTEN_SSL_CERT           | Name of API Firewall certificate file (in PEM format). The whole certificate chain must be stored in this file (CA, Intermediate CA, cert) - Must be present on filesystem and match the names used when building the firewall image. | firewall-cert.pem                          |
   | LISTEN_SSL_KEY            | Name of API Firewall private key file (in PEM format) - Must be present on filesystem and match the names used when building the firewall image. | firewall-key.pem                           |
   | PRESERVE_HOST             | API FW passes Host header unchanged to back-end              | On                                         |
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
             "value": "42c-fw-lb-xxxxx.elb.eu-west-1.amazonaws.com"
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

3. Set the **PROTECTION_TOKEN** value from the secret created earlier - Use the ARN obtained via the AWS CLI. 

```
secrets": [
  {
    "valueFrom": "arn:aws:secretsmanager:eu-west-1:749000xxxxx:secret:pixi-fw-token-xxxxx",
     "name": "PROTECTION_TOKEN"
  }
```

## Deploying the API Firewall

Once the task has been configured and saved, you can create a service from this task, configuring AWS network components to make the FW reachable.

When creating the service from the task: 

* You can use a network LB to expose the FW, with a 443 target

* You will need to put HTTPS/443 as inbound rule for the security group

* You will need to authorize access to secrets from the Fargate task (https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data-secrets.html)

* When the FW starts it will need to connect to **protection.42crunch.com:8001** - You may need to open access to this hostname that in your firewall / network rules.

  > They are many ways to deploy this setup, which will vary depending on your existing application architecture.  For example, you could use a application LB and terminate TLS at that level, or just do TCP load balancing in a network LB on port 443 so that the API Firewall terminates SSL.

# Getting ready to test the firewall

1. Test the secured endpoint setup by invoking the hostname you have set, for example: https://42c-fw-lb-xxxx.elb.eu-west-1.amazonaws.com/ - You should receive a message like this one, indicating the firewall has blocked the request.

> The API Firewall is configured with a self-signed certificate. You may have to accept an exception for the request to work properly, depending on where TLS termination is happening.

```json
{"status":404,"title":"path mapping","detail":"Not Found","instance":"https://42c-fw-lb-xxxx.elb.eu-west-1.amazonaws.com/","uuid":"dd385220-xxxx-11ea-bdc0-c9cc06d42ae5"}
```

You can also use curl to make the same request (using the -k option to avoid the self-signed certificates issue): `curl -k https://42c-fw-lb-xxxx.elb.eu-west-1.amazonaws.com/`

2. Import the  `postman-collection/Pixi_collection.json` file in Postman using **Import>Import from File**.

3. Create  an [environment variable](https://learning.getpostman.com/docs/postman/variables-and-environments/variables/) called **42c_url** inside an environment called **42Crunch-Secure** and set its value to the value of SERVER_NAME  to invoke the protected API (for example 42c-fw-lb-xxxx.elb.eu-west-1.amazonaws.com).
   The final configuration should look like this in Postman:

![Postman-Secure-Generic](/Volumes/DATA/42Crunch/Source/resources/graphics/Postman-Secure-Generic.jpg)

8. Go to the Pixi collection you just imported and invoke the operation **POST /api/register** with the following contents:

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

## Understanding Pixi

Pixi requires to register or login users to obtain a token, token which is then used to invoke other operations. The Postman has been setup to extract the token from login or register responses and add them automatically to the **current environment**, like this:

```javascript
var jsonData = pm.response.json();
pm.globals.set("token", jsonData.token);
```

Other operations, such getUserInfo or updateUserInfo take the value of the **token** variable set above and use it as the value of the **x-access-token** header, like this:

![Token Variable](/Volumes/DATA/42Crunch/Source/resources/graphics/Postman_TokenValue.png)

Make sure you always call either login or register before calling any other operations, or the request will fail at the firewall level, since the x-access-token header will be empty! When this happens, this is what you will see in the transaction logs of the API firewall .

![BadAccessToken](/Volumes/DATA/42Crunch/Source/resources/graphics/BadAccessToken.png)

# Blocking attacks with API Firewall

42Crunch API Firewall validates API requests and responses according to the OpenAPI definition of the protected API. In this section, you send various malicious requests to the API firewall to test its behavior.

## Viewing Transaction Logs

Whenever a request/response is blocked, transaction logs are automatically published to the 42Crunch platform. You can access the transaction logs viewer from the API protection tab. For each entry, you can view details information about the request and response step, as well as each step latency.

![](/Volumes/DATA/42Crunch/Source/resources/graphics/42c_logging.jpeg)

## Blocking Pixi API sample attacks

You can test the API firewall behavior with the following requests:

1. **Wrong verb**: the operation `Register` is defined to use `POST`, try calling it with `GET` or other verbs, and see how requests are blocked.

   ![42c_PostmanTest01-WrongVerb](./graphics/42c_PostmanTest01-WrongVerb.jpg)

2. **Wrong path**: any request to a path _not_ defined in the OAS definition is blocked, try `/api/foo`, for example.

3. **Wrong `Content-Type`**: the OpenAPI definition states that the operation `/api/register` requires input in the form of `application/json`. If you use a different value or if you do not specify the `Content-Type`, the request is blocked. The most famous attack based on crafting Content-Type value is [*CVE-2017-5638*](https://www.synopsys.com/blogs/software-security/cve-2017-5638-apache-struts-vulnerability-explained/), an issue in Apache Struts which is at the root of Equifax's and many others breaches.

4. **Missing a parameter** that the input JSON structure requires: the schema for the operation `/api/register` specifies that the parameters `user`, `name`, `email`, and `password` are mandatory. If you leave out any of these parameters, the request is blocked.

5. **Wrong format for string values**: if you specify a value (such as email) in a format that does not match the schema, the request is blocked. For example, try to register a user with email `user@acme.com@presidence@elysee.fr` (you can read how this was exploited by hackers [here](https://apisecurity.io/issue-28-breaches-tchap-shopify-justdial/) ).

6. **Blocking out of boundaries data**: the 42Crunch API firewall also validates integer boundaries. If you try to invoke `api/register` using a negative balance (-100) for example), the request is blocked. This prevents Overflow type attacks. Similarly, strings with do not match the minLength/maxLength properties will be blocked.

7. **Blocking exception leakage**: the 42Crunch APIfirewall prevents data leakage or exception leakage. If you invoke `/api/register` using a negative balance between -50 and -1 , the response will be blocked. The backend API does not properly handle negative values and returns an exception. That exception is blocked by the firewall since the schema from the OAS file does not match the actual response.

8. **Blocking data leakage**: the Pixi API exposes an admin operation which lists all users within the database. This operation leaks admin status and passwords (it is a straight export from the backend database). If you invoke `API 5: Get Users List`, the response is blocked. You get an HTTP 500 error since the response is invalid.

   ![API5-AdminOperation](/Volumes/DATA/42Crunch/Source/resources/graphics/API5-AdminOperation.png)

9. The Pixi API has a **MongoDB injection** vulnerability that allows logging into the application without specifying a password. You can try this by using the raw parameters `user=user@acme.com&pass[$ne]=` in Postman for a login request. You will see that you can log in to the unprotected API, but the request is blocked by API Firewall on the protected API.

10. **Mass assignment**:  the `API6: Mass Assignment` operation can be used to update a user record. It has a common issue (described in this [blog](https://42crunch.com/stopping_harbor_registry_attack/) ) by which a hacker with a valid token can change their role or administrative status. The OAS file does not declare is_admin as a valid input and as such this request will be blocked. Same occurs with the password. If you remove those two properties, the request will be accepted and both email and name are updated for the logged in user.

    ![42c_API6BVulnerability](/Volumes/DATA/42Crunch/Source/resources/graphics/42c_API6BVulnerability.png)

11. Reflected **XSS attack**: If you introduce a XSS attack like the example below in any property, the request is blocked:

    ```script
    <script>alert('hi')</script>
    ```

## Blocking admin operations

You have been able previously to invoke the `API5: Get Users List` admin operation, due to the fact it's declared in the Pixi OAS file. Although we blocked the response and prevented critical data from leaking, ideally we do not want this operation to be available. As such, we are going to replace the current OAS file, then update the configuration live.

1. Go to https://platform.42crunch.com and locate the Pixi API

2. At the top-right, select the Settings icon and choose **Update Definition**

   ![](/Volumes/DATA/42Crunch/Source/resources/graphics/API6-UpdateDefinition.png)

3. Browse to the `resources/OASFiles` folder and select the `Pixi-v2.0-noadmin.json` file

4. Once the file has been imported, select the **Protection** tab

5. Click the **Reconfigure** button and type *confirm* to confirm the instance update

6. When the instance's list refreshes, it means the re-configuration was successful.

7. Back to Postman, try to invoke the `API5:Get Users list` operation. This time, the request is blocked with a 404 code, since this operation is not defined in the OpenAPI file anymore.

![API5-BlockingRequest](./graphics/API5-BlockingRequest.jpg)

# Conclusion

In this evaluation guide, we have seen how the 42Crunch API firewall can be easily configured from an OAS file, with no need to write specific rules or policies. The OAS file acts as a powerful whitelist, thanks to the audit service which helps you pinpoint and remediate security issues.
