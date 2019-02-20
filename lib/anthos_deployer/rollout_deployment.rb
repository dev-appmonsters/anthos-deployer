# frozen_string_literal: true

module AnthosDeployer
  class RolloutDeployment < BaseInteraction
    include KubernetesDeploy::KubeclientBuilder

    hash :config, strip: false

    string :context, :namespace, :config_context_dir

    def execute
      start = Time.now.utc
      log_current_state
      rollout_deloyment
      success = true
    rescue KubernetesDeploy::FatalDeploymentError, AnthosDeployer::Kubernetes::PatchDeployment::FatalPatchError => error
      logger.summary.add_action(error.message)
      success = false
      raise error
    ensure
      logger.print_summary(success)
      status = success ? 'success' : 'failed'
      tags = %W[namespace:#{@namespace} context:#{@context} status:#{status}]
      ::StatsD.measure('restart.duration', KubernetesDeploy::StatsD.duration(start), tags: tags)
    end

    def rollout_deloyment
      ExecuteDeployments.run!(
        logger: logger,
        config: config,
        context: context,
        namespace: namespace,
        config_context_dir: config_context_dir,
        current_deployed_state: current_deployed_state.deep_dup
      )
    end

    def log_current_state
      logger.info '=======================Current deployment State================================================'
      ap current_deployed_state
      logger.info '=======================Current deployment State END============================================'
      logger.info(current_deployed_state)
    end

    def current_deployed_state
      @current_deployed_state ||= AnthosDeployer::CurrentDeployedState.run!(
        config: config.deep_dup, # [TODO][Tanuj] Move this object duplication from here.
        logger: logger,
        context: context,
        namespace: namespace
      )
    end
  end
end
