# AnthosDeployer

This gem deployes helm charts of multiple microservices based on a `deployment.yaml` file. It automatically builds docker image, pushes images to container registry overrides image tag in helm and deployes new release.

It also executes commands required for deploying a new service or required before upgrade of services.

CI/CD of microservices with migrations is complex, this tool makes all of the things super easy.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'anthos_deployer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install anthos_deployer


## Prerequisite

`$KUBECONFIG` (required): points to one or multiple valid kubeconfig files that include the context you want to deploy to. File names are separated by colon for Linux and Mac, and semi-colon for Windows.

`$GOOGLE_APPLICATION_CREDENTIALS` : points to the credentials for an authenticated service account (required if your kubeconfig user's auth provider is GCP)


## ENV config file

This gem uses [Figaro](https://github.com/laserlemon/figaro]) to manage the configs which can be utilized in `deployment.yaml` file.

```yaml
# Global configs

# anthos-certificates config
CERTIFICATE_ISSUER_EMAIL: tanujs@techracers.com

devops:
  # AnthosDeployer Config config
  DOCKER_REPOSITORY: asia.gcr.io/xyz-devops
  KUBE_NAMESPACE: default
  KUBE_CONTEXT: gke_xyz-devops_asia-southeast1-b_devops

  DOMAIN: ethox.gq

staging:
  # AnthosDeployer Config config
  DOCKER_REPOSITORY: asia.gcr.io/xyz-sandbox
  KUBE_NAMESPACE: default
  KUBE_CONTEXT: gke_xyz-sandbox_asia-southeast1-b_staging-sandbox

  DOMAIN: ethox.ml

production:

  # AnthosDeployer Config config
  DOCKER_REPOSITORY: asia.gcr.io/xyz-195909
  KUBE_NAMESPACE: default
  KUBE_CONTEXT: gke_xyz-195909_asia-southeast1-b_production

  DOMAIN: ethox.ga

```

The configurations can be defined for each environment you want to maintain.


## Example configuration file

```yaml
#============================= Anthos Config ===============================

docker:
  repository: <%= ENV['DOCKER_REPOSITORY'] %>

kube:
  namespace: <%= ENV['KUBE_NAMESPACE'] %>
  context: <%= ENV['KUBE_CONTEXT'] %>

common_code:
  docker:
    context: common

#============================= CAUTION ======================================
# Never ever put any sensitive information here.
#============================= CAUTION ======================================

#============================= Charts Config ================================
charts:

  coin:
    docker_context: coin
    chart_path: coin/charts/coin/
    update_service_code_hash: true
    require_common_code: true
    patch_after_commands: true
    chart_overrides:
      replicaCount: 2
    install_cmds:
      - entrypoint: [make]
        args: [create-db]
      - entrypoint: [make]
        args: [migrate-db]
      - entrypoint: [make]
        args: [seed-db]
    pre_upgrade_cmds:
      - entrypoint: [make]
        args: [migrate-db]

  anthos-ingress:
    chart_path: deployment/anthos_charts/anthos-ingress
    always_upgrade: true
    chart_overrides:
      domain: <%= ENV['DOMAIN'] %>

```

The values defined in the `env.yaml` file can be used to do the helm charts overrides my specifying them under `chart_overrides` key in the deployment file.

The configuration file uses Ruby ERB templating so the values defined in the `env.yaml` can be utilized here, this also helps in keeping the configurations in the codebase specific to every environment.

Required configurations:
```yaml
docker:
  repository: <%= ENV['DOCKER_REPOSITORY'] %> # Base url of private docker repository

kube:
  namespace: <%= ENV['KUBE_NAMESPACE'] %> # Kubernetes namespace where anthos_deployer will deploy these charts
  context: <%= ENV['KUBE_CONTEXT'] %> # Kubernetes config context
```


Charts configurations

```yaml
charts:
  coin:
    docker_context: coin            # Path of the directory of Dockerfile
    chart_path: coin/charts/coin/   # Path of helm charts for this service
    update_service_code_hash: true  # Update the docker image tag with the git sub tree hash value and update deployments based on this.
    require_common_code: true       # Specify if this service requires the common code container to build the docker image (Specific to xyz as of now)
    patch_after_commands: true      # This removes the infinite wait init containers after running the `install_cmds` or `pre_upgrade_cmds`
    chart_overrides:				# Used to override helm charts values.
      domain: <%= ENV['DOMAIN'] %>
    install_cmds:                   # These are executed when the the service is installed for the first time.
      - entrypoint: [make]
        args: [create-db]
    pre_upgrade_cmds:               # Executed before upgrading the docker image with new code (Commands are executed with the new docker image)
      - entrypoint: [make]
        args: [migrate-db]
```


## Task execution

If a service require to run tasks like `seed-db`, `create-db` then the helm chart of service must define a `PodTemplate` object and should have an init container defined in the main deployment object.

templates/job-runner.yaml
```yaml
apiVersion: v1
kind: PodTemplate
metadata:
  name: coin-job-runner
  labels:
    app: coin-job-runner
    type: job-runner
    chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
template:
  metadata:
    name: coin-job-runner
    labels:
      app: coin-job-runner
      release: {{ .Release.Name }}
  spec:
    restartPolicy: Never
    containers:
      - name: task-runner # Name of the container must be exactly this.
        image: "{{ .Values.image.repository }}/coin:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
```

templates/deployment.yaml
```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: coin
  labels:
    app: coin
    chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
    serviceHash: {{ .Values.image.tag }}
    configDigest: {{ .Values.config_digest }}
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    metadata:
      labels:
        app: coin
        release: {{ .Release.Name }}
    spec:
      initContainers:
        - name: infinite-wait
          image: busybox
          command: ['sh', '-c', 'while true; do echo waiting for this to be removed; sleep 2; done;'] # This blocks the execution of main containers.
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}/coin:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
```


Including an init container with infinite wait keeps the actual containers on hold till the `anthos_deployer` uses the PodTemplate to generate a `Pod` configuration to run specific tasks. If the tasks executes successfully, the Deployment object will be patched to remove the init container and the actual container will come up.




## Usage

```bash
anthos_deployer --config_file=./deployment.yaml --env_variables_file=./env.yaml --deployment_environment=staging
```
1. config_file: the main deployment configuration file
2. env_variables_file: where the configs are defined as environment variables
3. deployment_environment: Specifies which environment to deploy based on `env.yaml` file.



## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/anthos_deployer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the AnthosDeployer project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/anthos_deployer/blob/master/CODE_OF_CONDUCT.md).
