# frozen_string_literal: true

# [Warning] This is not complete, there is a need to store the current state somewhere out of CI/CD
# Currently this only serves the purpose of checking deployed images hashes and simulates current state
# [TODO][Tanuj] Use objects instead of iterating over hashes

module AnthosDeployer
  class CurrentDeployedState < BaseInteraction
    include KubernetesDeploy::KubeclientBuilder

    hash :config, strip: false

    string :context, :namespace

    def execute
      retrieve_current_state
    end

    def retrieve_current_state
      charts_state = {}
      current_helm_installations.each_with_index do |(chart_inst_name, helm_state), _index|
        next unless config[:charts][chart_inst_name].present?
        charts_state[chart_inst_name] = config[:charts][chart_inst_name]
        if config[:charts][chart_inst_name][:docker_context]
          charts_state[chart_inst_name].merge!(current_deployment_service_info(chart_inst_name))
        end
        charts_state[chart_inst_name][:helm] = helm_state if config[:charts][chart_inst_name]
      end
      charts_state
    end

    # [TODO][Tanuj] Raise error if serviceHash is not found or not defined
    KUBE_DEPLOYMENT_OK_STATUS = 'True'
    KUBE_DEPLOYMENT_FAIL_STATUS = 'False'
    def current_deployment_service_info(service) # rubocop:disable Metrics/AbcSize:
      kube_item = current_kube_deployments.items.find do |s|
        s.metadata.name == service
      end
      condition = if kube_item&.status&.conditions&.find { |f| f.status == KUBE_DEPLOYMENT_FAIL_STATUS }
                    KUBE_DEPLOYMENT_FAIL_STATUS
                  else
                    KUBE_DEPLOYMENT_OK_STATUS
                  end
      {
        service_hash: kube_item&.metadata&.labels&.serviceHash,
        config_digest: kube_item&.metadata&.labels&.configDigest,
        status: condition,
        database_state: kube_item&.metadata&.labels&.databaseState,
        kube_deployment: kube_item&.metadata&.name
      }
    end

    # [TODO][Tanuj] Not sure if logs should be out of this class
    def current_helm_installations
      helm_installations = AnthosDeployer::Helm::GetHelmInstallations.run!(logger: logger, context: context)
      logger.info '=========================Current Helm State================================================'
      ap helm_installations
      logger.info '=========================Current Helm State END============================================'
      logger.info(helm_installations)
      helm_installations
    end

    def current_kube_deployments
      @current_kube_deployments ||= v1beta1_kubeclient.get_deployment('', namespace)
    rescue KubeException => error
      not_found = error.error_code == 404
      raise FatalPatchError, "Deployments fetch error in namespace `#{namespace}`" if not_found
      raise
    end

    def v1beta1_kubeclient
      @v1beta1_kubeclient ||= build_v1beta1_kubeclient(context)
    end
  end
end
