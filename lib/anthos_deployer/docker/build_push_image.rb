# frozen_string_literal: true

module AnthosDeployer
  module Docker
    class BuildAndPushImage < BaseInteraction
      string :docker_context, :image_tag

      hash :build_args, strip: false

      def execute
        build_docker_image
        push_docker_image
      end

      private

      def build_docker_image
        AnthosDeployer::Docker::ImageBuilder.run!(
          logger: logger,
          docker_context: docker_context,
          build_args: build_args,
          tags: [image_tag]
        )
      end

      def push_docker_image
        AnthosDeployer::Docker::ImagePusher.run!(
          logger: logger,
          tag: image_tag
        )
      end
    end
  end
end
