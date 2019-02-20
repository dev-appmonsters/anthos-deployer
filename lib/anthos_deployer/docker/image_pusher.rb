# frozen_string_literal: true

module AnthosDeployer
  module Docker
    class ImagePusher < BaseInteraction
      string :tag

      validates :tag, presence: true

      array :docker_args, default: -> { ['push'] }

      class ImagePushError < KubernetesDeploy::FatalDeploymentError
        def initialize(msg)
          super("Docker image push failed failed: #{msg}")
        end
      end

      def execute
        docker_args.push(tag)
        successful = docker.run(*docker_args)
        return true if successful
        logger.error("Docker push failed for image: #{tag}")
        logger.summary.add_action('Docker push failed.')
        raise ImagePushError, 'Docker push failed.'
      end

      private

      def log_start
        logger.phase_heading 'Initializing docker image push'
        logger.info "Docker push: tags: #{tag}"
      end

      def docker
        @docker ||= AnthosDeployer::Docker::Client.new(logger: logger, log_failure_by_default: true)
      end
    end
  end
end
