# frozen_string_literal: true

require 'timeout'

module AnthosDeployer
  module Kubernetes
    class RunTaskFromPodTemplate < BaseInteraction # rubocop:disable Metrics/ClassLength
      include KubernetesDeploy::KubeclientBuilder

      class FatalTaskRunError < KubernetesDeploy::FatalDeploymentError; end

      class PodNotFoundError < KubernetesDeploy::FatalDeploymentError; end

      string :task_template, :image_hash, :namespace, :context

      array :env_vars, default: -> { [] }

      array :entrypoint, :args

      validates :task_template, :image_hash, :entrypoint, :args, :namespace, :context, presence: true

      time :deploy_started_at, default: -> { Time.now.utc }

      def execute
        log_start
        deploy_pod
        resource = build_watchable_pod
        sync_mediator.sync([resource])
        KubernetesDeploy::ResourceWatcher.new(resources: [resource], sync_mediator: sync_mediator,
                                              logger: logger, operation_name: "#{operation_name} ").run
        log_and_raise "Runnig task #{resource.name} Failed" unless resource.deploy_succeeded?
        resource
      rescue KubeException => error
        log_and_raise "RunTaskFromPodTemplate raised a error: #{error.message}"
      ensure
        delete_pod
      end

      private

      def sync_mediator
        @sync_mediator ||= KubernetesDeploy::SyncMediator.new(namespace: namespace, context: context, logger: logger)
      end

      def delete_pod
        logger.phase_heading("Deleting Pod created to run the job: #{task_template}")
        kubeclient.delete_pod task_runner_pod_uniq_name, namespace
        watch_for_pod_to_be_deleted
      rescue KubeException => error
        logger.error("Pod deletion failed: #{error.message}")
        logger.summary.add_action(error.message)
      end

      POD_DELETE_WAIT_TIME = 120
      # The idea is we are waiting for ResourceNotFoundError found error to be raised
      # when the pod would have been deleted
      def watch_for_pod_to_be_deleted
        time_start = Time.now
        begin
          time_running = Time.now - time_start
          kubeclient.get_pod task_runner_pod_uniq_name, namespace
          logger.info("Waiting for pod(#{task_runner_pod_uniq_name}) to be terminated")
          Kernel.sleep 5
        end until (time_running.to_i >= POD_DELETE_WAIT_TIME) # rubocop:disable Lint/Loop
      rescue Kubeclient::ResourceNotFoundError => not_found_err
        logger.info("Pod deletion successful: #{not_found_err.message}")
      end

      def fetch_running_pod
        kubeclient.get_pod(task_runner_pod_uniq_name, namespace)
      rescue KubeException => error
        log_and_raise "Pod `#{task_runner_pod_uniq_name}` not found in namespace `#{namespace}`" if error.error_code == 404
      end

      def build_watchable_pod
        AnthosDeployer::Resource::Pod.new(
          namespace: namespace,
          context: context,
          definition: running_resource_definition,
          logger: logger,
          deploy_started_at: deploy_started_at,
          statsd_tags: []
        )
      end

      def running_resource_definition
        fetch_running_pod.to_h.deep_stringify_keys
      end

      def operation_name
        Shellwords.join(entrypoint + args)
      end

      def deploy_pod
        logger.phase_heading("Creating pod #{task_template}")
        logger.info("Starting task runner pod: '#{pod_template.metadata.name}'")
        kubeclient.create_pod(pod_template)
      end

      def log_start
        logger.phase_heading("Prepare custom task with template: #{task_template}")
        logger.info("Entrypoint:#{entrypoint}, Args: #{args}")
        logger.info("Deployed Pod name is going to be: #{task_runner_pod_uniq_name} ")
      end

      def print_failure_log; end

      # Kubernates truncates pod names if the size is more than 62.
      def task_runner_pod_uniq_name
        "#{task_template}-#{image_hash}"[0..62]
      end

      def kubeclient
        @kubeclient ||= build_v1_kubeclient(context)
      end

      def v1beta1_kubeclient
        @v1beta1_kubeclient ||= build_v1beta1_kubeclient(context)
      end

      def pod_template
        @pod_template ||= runner_task_template_generator.run!(
          task_template: task_template,
          entrypoint: entrypoint,
          args: args,
          runner_pod_name: task_runner_pod_uniq_name,
          env_vars: env_vars
        )
      end

      def runner_task_template_generator
        @runner_task ||= AnthosDeployer::Kubernetes::RunnerTaskTemplateGenerator.new(
          namespace: namespace,
          context: context,
          logger: logger
        )
      end
    end
  end
end
