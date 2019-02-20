# frozen_string_literal: true

require 'open3'
require 'shellwords'
require 'active_interaction'
require 'kubeclient'
require 'colorize'
require 'colorized_string'
require 'awesome_print'
require 'digest'
require 'parallel'

require 'kubernetes-deploy'
require 'kubernetes-deploy/formatted_logger'
require 'kubernetes-deploy/kubectl'
require 'kubernetes-deploy/kubeclient_builder'
require 'kubernetes-deploy/runner_task'
require 'kubernetes-deploy/resource_watcher'
require 'kubernetes-deploy/kubernetes_resource/pod'

require 'anthos_deployer/version'

require 'anthos_deployer/git/client'

require 'anthos_deployer/base_interaction'

# require 'anthos_deployer/formatted_logger'

require 'anthos_deployer/anthos_resource/chart_deployment'

require 'anthos_deployer/current_deployed_state'
require 'anthos_deployer/execute_deployments'
require 'anthos_deployer/rollout_deployment'
# require 'anthos_deployer/kubeclient_builder'
# require 'anthos_deployer/kubectl'

require 'anthos_deployer/resource/pod'

require 'anthos_deployer/kubernetes/runner_task_template_generator'
require 'anthos_deployer/kubernetes/run_task_from_pod_template'
require 'anthos_deployer/kubernetes/wait_for_deployment_to_be_ready'
require 'anthos_deployer/kubernetes/patch_deployment'

require 'anthos_deployer/docker/client'
require 'anthos_deployer/docker/image_builder'
require 'anthos_deployer/docker/image_pusher'
require 'anthos_deployer/docker/build_push_image'

require 'anthos_deployer/helm/base'
require 'anthos_deployer/helm/client'
require 'anthos_deployer/helm/chart_installer'
require 'anthos_deployer/helm/chart_upgrader'
require 'anthos_deployer/helm/get_helm_installations'
require 'anthos_deployer/helm/rollback_revision'

require 'figaro'
require 'figaro/error'
require 'figaro/env'
require 'figaro/application'

module AnthosDeployer
  GEM_ROOT = File.expand_path('../..', __FILE__)

  def self.load_config(file)
    YAML.safe_load(ERB.new(File.read(file)).result).with_indifferent_access
  end

  def self.load_envs_with_figaro(env_file_path, environment = 'development')
    figaro_inst = Class.new(Figaro::Application) do
      def default_path
        @default_path
      end

      def default_environment
        @default_environment
      end
    end.new
    figaro_inst.instance_variable_set('@default_path', env_file_path)
    figaro_inst.instance_variable_set('@default_environment', environment)
    figaro_inst.load
  end
end
