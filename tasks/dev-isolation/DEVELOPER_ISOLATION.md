## Developer Isolation

#### [This](working-aws-example/.k8s/charts/spin-test-env/templates/deployment.yaml) is a part of a working solution that runs on AWS, allowing developers work in isolated cloud environments.

It was designed, deployed and maintained by me.

#### The problem:
Developers work on different branches and need to have their own isolated environments to avoid conflicts and ensure a smooth development process, where each developer can run and test their code without affecting others, while mimicking a production environment.

Creating multiple clusters is a common approach to achieve developer isolation in cloud environments. By creating separate clusters for each developer or team, they can work independently without interfering with each other's work. This allows for better organization, easier management, and improved collaboration within the development team.
However, this is a very expensive approach, as it requires significant resources and infrastructure to support multiple clusters. Additionally, managing and maintaining multiple clusters can be complex and time-consuming, which can lead to delays and errors in the development process.

#### The implemented solution:
A single Kubernets cluster is used for all developers, allowing each developer to have his own isolated environment within the cluster, while still allowing selected resources to be shared.

#### The convention:
A developer who needs to test his work in the cloud is required to create a branch with a name that starts with "test-".

#### Background activity:
* All production databases are cloned to test DB servers once a day. This enables to test the new code with nearly identical data to production, ensuring that the code behaves as expected in a realistic environment.
* Secrets are loaded into the deployment from an integration with [1Password](https://1password.com).<br>When a developer changes a secret in 1Password, it is immediately updated in the deployment and the deploymet itself is reloaded to use the new secret.

#### The process:
A developer pushes the code to the "test-" branch.
<br>The `push` event triggers a pipeline that executes the following steps:
1. A new Kubernetes deployment is created, with the same name as the branch name.
2. New databases are created in the test DB server, with the same naming convention.
3. The data from the cloned databases is loaded into the new databases.
4. The new deployment is rolled out to the test cluster, and is accessible to the the developer, through VPN, on a subdomain with the same name as the branch name.<br>In this example, the main domain is working-example.com, and the developer's branch is named "test-feature-123".<br>Therefore, the developer can access the new deployment at "test-feature-123.working-example.com".
5. During the pipeline execution, all environment variables in the deployment are set to the values of the test environment, so the new code can't access production resources.<br>Even if the code contains hard coded production resources, the new deployment will not be able to access them because of firewall policies.
6. Scaling up the deployment is limited to a relative small number of pods, to prevent expensive resources consumption.
7. When a deployment is not accessed for more than 8 hours, it is automatically scaled down to 0 pods. The databases that were created for the deployment are kept active for the meantime.
8. When the developer tries to access the deployment after it was scaled down, the deployment is automatically scaled up again.
9. If the deployment is not accessed for a few days, the databases that were created for the deployment are automatically deleted. If the developer tries to access the deployment after the databases were deleted, they will be recreated and populated again.
10. Additionally, every night a Kubernetes CronJob maps the active test deployments and their owners, and sends a Slack message to developers that have more than 2 active test deployments, asking the to make sure they still need them.

#### This solution was implemented on AWS, but can be very easily adapted to other cloud providers.
   
