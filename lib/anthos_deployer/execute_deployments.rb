# frozen_string_literal: true

module AnthosDeployer
  class ExecuteDeployments < BaseInteraction # rubocop:disable Metrics/ClassLength
    include KubernetesDeploy::KubeclientBuilder

    hash :config, strip: false

    string :context, :namespace, :config_context_dir

    hash :current_deployed_state, strip: false

    def execute
      process_sequentially config[:order][:before]
      independent_charts = config[:charts].keys - (config[:order][:before] + config[:order][:after])
      process_parallely independent_charts
      process_sequentially config[:order][:after]
    end

    def process_sequentially(charts)
      charts.each do |chart_name|
        deployment = build_deployment(chart_name)
        process_deployment(deployment)
      end
    end

    IN_PARALLEL = ENV.fetch('DEPLOYER_IN_PARALLEL', 5)
    def process_parallely(charts)
      result = Parallel.map(charts, in_threads: IN_PARALLEL) do |chart_name|
        begin
          deployment = build_deployment(chart_name)
          process_deployment(deployment)
        rescue => exception
          raise Parallel::Break # -> stops after all current items are finished
        end
      end
      raise 'One or more services deployment failed' if result.nil?
    end

    def process_deployment(deployment) # rubocop:disable Metrics/AbcSize
      # build_and_push_docker_image(deployment) if deployment.requires_docker_image_push?
      install_deployment(deployment) if deployment.needs_helm_install?
      upgrade_deployment(deployment) if deployment.needs_helm_upgrade? && !deployment.needs_helm_install?
      wait_for_deployment_rollout(deployment) if deployment.should_wait_for_rollout?
    rescue StandardError => error
      logger.error "Failed to process deployment: #{deployment.name} rolling back chart upgrade, error: #{error}"
      AnthosDeployer::Helm::RollbackRevision.run!(
        logger: logger,
        context: context,
        release_name: deployment.name,
        revision: deployment.old_revision
      )
      patch_deployment(deployment, :post_deployment) if deployment.needs_deployment_to_be_patched?
      raise error
    end

    def wait_for_deployment_rollout(deployment)
      wait_for_k8s_deployment_rollout(deployment.kube_deployment_name) if deployment.kube_deployment_name
      return unless deployment.additional_deployments?
      deployment.additional_deployments.each { |k8s_dep| wait_for_k8s_deployment_rollout(k8s_dep) }
    end

    def wait_for_k8s_deployment_rollout(k8s_deployment_name)
      AnthosDeployer::Kubernetes::WaitForDeploymentToBeReady.run!(
        kube_deployment_name: k8s_deployment_name,
        namespace: namespace,
        context: context,
        logger: logger
      )
    end

    # def build_and_push_docker_image(deployment)
    #   build_args = {}
    #   if deployment.require_common_code?
    #     build_common_code_image
    #     build_args = { COMMON_CODE_VERSION: 'latest' }
    #   end
    #   AnthosDeployer::Docker::BuildAndPushImage.run!(
    #     logger: logger,
    #     docker_context: deployment.docker_context,
    #     build_args: build_args,
    #     image_tag: docker_tags_for_deployment(deployment)
    #   )
    # end

    # @common_image_built works as a flag that common image is already built
    def build_common_code_image
      @common_image_built ||= AnthosDeployer::Docker::ImageBuilder.run!(
        logger: logger,
        docker_context: File.join(config_context_dir, config[:common_code][:docker][:context]),
        tags: ['common:latest'],
        build_args: {}
      )
    end

    def docker_tags_for_deployment(deployment)
      "#{config[:docker][:repository]}/#{deployment.name}:#{deployment.service_code_hash}"
    end

    def patch_deployment(deployment, patch_type)
      patch_k8s_deployment(deployment.name, patch_type)
      return unless deployment.additional_deployments?
      deployment.additional_deployments.each { |k8s_dep| patch_k8s_deployment(k8s_dep, patch_type) }
    end

    def patch_k8s_deployment(k8s_deployment_name, patch_type)
      AnthosDeployer::Kubernetes::PatchDeployment.run!(
        namespace: namespace,
        context: context,
        logger: logger,
        deployment_name: k8s_deployment_name,
        patch_hash: get_patch(patch_type)
      )
    end

    def get_patch(patch_type)
      if patch_type == :pre_deployment
        load_yaml_patches('_pre-deploy.yaml')
      elsif patch_type == :post_deployment
        load_yaml_patches('_post-deploy.yaml')
      end
    end

    def load_yaml_patches(patch)
      file = File.join(AnthosDeployer::GEM_ROOT, 'patches', patch)
      YAML.safe_load(ERB.new(File.read(file)).result)
    end

    def install_deployment(deployment)
      install_chart(deployment)
      patch_deployment(deployment, :pre_deployment) if deployment.needs_deployment_to_be_patched?
      run_installation_commands(deployment) if deployment.installation_commands.present?
      patch_deployment(deployment, :post_deployment) if deployment.needs_deployment_to_be_patched?
    end

    def install_chart(deployment)
      chart_overrides = add_chart_values_override(deployment)
      AnthosDeployer::Helm::ChartInstaller.run!(
        context: context,
        namespace: namespace,
        logger: logger,
        chart_path: deployment.chart_path,
        chart_name: deployment.name,
        values_overrides: chart_overrides
      )
    end

    def run_installation_commands(deployment)
      log_and_raise 'No istallation commands present' if deployment.installation_commands.blank?
      deployment.installation_commands.each do |cmd|
        run_task(deployment, cmd[:entrypoint], cmd[:args])
      end
    end

    def upgrade_deployment(deployment)
      upgrade_chart(deployment)
      patch_deployment(deployment, :pre_deployment) if deployment.needs_deployment_to_be_patched?
      run_pre_upgrade_commands(deployment) if deployment.pre_upgrade_commands.present?
      patch_deployment(deployment, :post_deployment) if deployment.needs_deployment_to_be_patched?
    end

    def upgrade_chart(deployment)
      chart_overrides = add_chart_values_override(deployment)
      AnthosDeployer::Helm::ChartUpgrader.run!(
        context: context,
        namespace: namespace,
        logger: logger,
        chart_path: deployment.chart_path,
        chart_name: deployment.name,
        values_overrides: chart_overrides
      )
    end

    def run_pre_upgrade_commands(deployment)
      log_and_raise 'No istallation commands present' if deployment.pre_upgrade_commands.blank?
      deployment.pre_upgrade_commands.each do |cmd|
        run_task(deployment, cmd[:entrypoint], cmd[:args])
      end
    end

    def add_chart_values_override(deployment)
      chart_overrides = deployment.chart_overrides.deep_dup || {}
      chart_overrides[:config_digest] = deployment.config_digest
      if deployment.requires_docker_image_push?
        chart_overrides = chart_overrides.merge(
          image: { tag: deployment.service_code_hash, repository: config[:docker][:repository] }
        )
      end
      chart_overrides
    end

    def run_task(deployment, entrypoint, args)
      AnthosDeployer::Kubernetes::RunTaskFromPodTemplate.run!(
        namespace: namespace,
        context: context,
        logger: logger,
        task_template: "#{deployment.name}-job-runner",
        entrypoint: entrypoint,
        args: args,
        image_hash: deployment.service_code_hash,
        env_vars: [] # [TODO] lets see if we need this
      )
    end

    def build_deployment(name)
      AnthosDeployer::AnthosResource::ChartDeployment.run(
        name: name,
        config: config[:charts][name],
        logger: logger,
        config_context_dir: config_context_dir,
        current_deployed_state: current_deployed_state,
        context: context,
        namespace: namespace
      )
    end
  end
end
