# frozen_string_literal: true

module AnthosDeployer
  module Kubernetes
    class WaitForDeploymentToBeReady < BaseInteraction
      include KubernetesDeploy::KubeclientBuilder

      string :kube_deployment_name, :namespace, :context

      validates :kube_deployment_name, :namespace, :context, presence: true

      time :deploy_started_at, default: -> { Time.now.utc }

      def execute
        resource = build_watchable_deployment(fetch_deployment)
        sync_mediator.sync([resource])
        KubernetesDeploy::ResourceWatcher.new(resources: [resource], sync_mediator: sync_mediator,
                                              logger: logger, operation_name: 'patch').run
        log_and_raise "Patching deployment #{resource.name} Failed" unless resource.deploy_succeeded?
        resource
      end

      def sync_mediator
        @sync_mediator ||= KubernetesDeploy::SyncMediator.new(namespace: namespace, context: context, logger: logger)
      end

      def build_watchable_deployment(deployment)
        definition = deployment.to_h.deep_stringify_keys
        d = KubernetesDeploy::Deployment.new(namespace: namespace, context: context, definition:
        definition, logger: logger, statsd_tags: [])
        d.deploy_started_at = deploy_started_at
        d
      end

      def fetch_deployment
        v1beta1_kubeclient.get_deployment(kube_deployment_name, namespace)
      rescue KubeException => error
        not_found = error.error_code == 404
        log_and_raise "Deployment `#{kube_deployment_name}` not found in namespace `#{namespace}`" if not_found
      end

      def v1beta1_kubeclient
        @v1beta1_kubeclient ||= build_v1beta1_kubeclient(context)
      end
    end
  end
end
