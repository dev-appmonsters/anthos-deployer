# frozen_string_literal: true

module AnthosDeployer
  module Kubernetes
    class RunnerTaskTemplateGenerator < KubernetesDeploy::RunnerTask
      def run!(task_template:, entrypoint:, args:, runner_pod_name:, env_vars: [])
        # @override
        # @logger.reset

        @logger.phase_heading('Validating configuration')
        validate_configuration(task_template, args)
        if kubectl.server_version < Gem::Version.new(KubernetesDeploy::MIN_KUBE_VERSION)
          @logger.warn(KubernetesDeploy::Errors.server_version_warning(kubectl.server_version))
        end
        @logger.phase_heading('Fetching task template')
        raw_template = get_template(task_template)

        @logger.phase_heading('Constructing final pod specification')
        rendered_template = build_pod_template(raw_template, entrypoint, args, env_vars, runner_pod_name)

        validate_pod_spec(rendered_template)

        rendered_template
      end

      private

      def build_pod_template(base_template, entrypoint, args, env_vars, runner_pod_name) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/LineLength
        @logger.info('Rendering template for task runner pod')
        rendered_template = base_template.dup
        rendered_template.kind = 'Pod'
        rendered_template.apiVersion = 'v1'

        container = rendered_template.spec.containers.find { |cont| cont.name == 'task-runner' }

        raise FatalTaskRunError, "Pod spec does not contain a template container called 'task-runner'" if container.nil?

        container.command = entrypoint
        container.args = args
        container.env ||= []

        env_args = env_vars.map do |env|
          key, value = env.split('=', 2)
          { name: key, value: value }
        end

        container.env = container.env.map(&:to_h) + env_args

        # @Override
        # unique_name = rendered_template.metadata.name + "-" + SecureRandom.hex(8)
        unique_name = runner_pod_name

        @logger.warn("Name is too long, using '#{unique_name[0..62]}'") if unique_name.length > 63
        rendered_template.metadata.name = unique_name[0..62]
        rendered_template.metadata.namespace = @namespace

        rendered_template
      end
    end
  end
end
