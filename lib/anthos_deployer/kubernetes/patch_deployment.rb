# frozen_string_literal: true

module AnthosDeployer
  module Kubernetes
    class PatchDeployment < BaseInteraction
      include KubernetesDeploy::KubeclientBuilder

      class FatalPatchError < KubernetesDeploy::FatalDeploymentError; end

      string :deployment_name, :namespace, :context

      validates :deployment_name, :namespace, :context, presence: true

      hash :patch_hash, strip: false

      def execute
        log_start
        verify_namespace
        patch_deployment
      end

      private

      def patch_deployment
        patch_yaml = recursive_to_h(patch_hash).to_yaml
        logger.info "Patching deployment: `#{deployment_name}` with: #{patch_hash}"
        _out, err, status = kubectl.run('patch', 'deployment', deployment_name, '--type', 'merge',
                                        '--patch', patch_yaml)
        if status.success?
          logger.info "Triggered `#{deployment_name}` patch"
        else
          logger.error "Failed to patch `#{deployment_name}`, Response:#{err}"
          raise FatalPatchError, err&.message
        end
      end

      # [Tanuj][TODO] Move this to utils
      def recursive_to_h(struct)
        if struct.is_a?(Array)
          return struct.map { |v| v.is_a?(OpenStruct) || v.is_a?(Array) || v.is_a?(Hash) ? recursive_to_h(v) : v }
        end

        hash = {}

        struct.each_pair do |k, v|
          recursive_val = v.is_a?(OpenStruct) || v.is_a?(Array) || v.is_a?(Hash)
          hash[k] = recursive_val ? recursive_to_h(v) : v
        end
        hash
      end

      def verify_namespace
        kubeclient.get_namespace(namespace)
        logger.info("Namespace #{namespace} found in context #{context}")
      rescue KubeException => error
        raise KubernetesDeploy::NamespaceNotFoundError.new(namespace, context) if error.error_code == 404
        raise
      end

      def log_start
        logger.phase_heading('Initializing deployment patch')
      end

      def kubeclient
        @kubeclient ||= build_v1_kubeclient(context)
      end

      def kubectl
        @kubectl ||= KubernetesDeploy::Kubectl.new(namespace: namespace, context: context,
                                                   logger: logger, log_failure_by_default: true)
      end
    end
  end
end
