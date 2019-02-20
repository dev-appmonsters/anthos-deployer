# frozen_string_literal: true

module AnthosDeployer
  module Docker
    class ImageBuilder < BaseInteraction
      string :docker_context

      array :tags

      hash :build_args, strip: false

      validates :docker_context, presence: true

      array :docker_args, default: -> { ['build'] }

      class ImageBuildError < KubernetesDeploy::FatalDeploymentError
        def initialize(msg)
          super("Docker image build failed failed: #{msg}")
        end
      end

      def execute
        log_start
        add_context_path
        add_tags_to_docker_args
        add_build_args_to_docker_args if build_args.present?
        successful = docker.run(*docker_args)
        return true if successful
        logger.error("Docker Build failed. context:#{docker_context}, tags: #{tags}, build args: #{build_args}")
        logger.summary.add_action('Docker Build failed.')
        raise ImageBuildError, 'Docker Build failed.'
      end

      private

      def log_start
        logger.phase_heading 'Initializing docker image build'
        logger.info "Docker build: context:#{docker_context}, tags: #{tags}, build args: #{build_args}"
      end

      def add_context_path
        docker_args.push(docker_context)
      end

      def add_tags_to_docker_args
        tags.map do |tag|
          docker_args.push('-t', tag)
        end
      end

      def add_build_args_to_docker_args
        docker_args.push('--build-arg')
        build_args.each do |k, v|
          docker_args.push("#{k.upcase}=#{v}")
        end
      end

      def docker
        @docker ||= AnthosDeployer::Docker::Client.new(logger: logger, log_failure_by_default: true)
      end
    end
  end
end
