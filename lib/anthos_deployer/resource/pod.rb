# frozen_string_literal: true

module PatchPodContainerClass
  def doom_reason # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity,
    limbo_reason = @status.dig('state', 'waiting', 'reason')
    limbo_message = @status.dig('state', 'waiting', 'message')

    if @status.dig('lastState', 'terminated', 'reason') == 'ContainerCannotRun'
      # ref: https://github.com/kubernetes/kubernetes/blob/11111111111111/pkg/kubelet/dockershim/docker_container.go#L353
      exit_code = @status.dig('lastState', 'terminated', 'exitCode')
      "Failed to start (exit #{exit_code}): #{@status.dig('lastState', 'terminated', 'message')}"
    elsif @status.dig('state', 'terminated', 'reason') == 'ContainerCannotRun'
      exit_code = @status.dig('state', 'terminated', 'exitCode')
      "Failed to start (exit #{exit_code}): #{@status.dig('state', 'terminated', 'message')}"
    #----------------------------------------Patched------------------------------------------#

    elsif @status.dig('state', 'terminated', 'reason') == 'Error'
      exit_code = @status.dig('state', 'terminated', 'exitCode')
      "Failed to start (exit #{exit_code}): #{@status.dig('state', 'terminated', 'message')}"

    #----------------------------------------end----------------------------------------------#

    elsif limbo_reason == 'CrashLoopBackOff'
      exit_code = @status.dig('lastState', 'terminated', 'exitCode')
      "Crashing repeatedly (exit #{exit_code}). See logs for more information."
    elsif %w[ImagePullBackOff ErrImagePull].include?(limbo_reason) &&
          limbo_message.match(/(?:not found)|(?:back-off)/i)
      "Failed to pull image #{@image}. "\
      'Did you wait for it to be built and pushed to the registry before deploying?'
    elsif limbo_message == 'Generate Container Config Failed'
      # reason/message are backwards in <1.8.0 (next condition used by 1.8.0+)
      # Fixed by https://github.com/kubernetes/kubernetes/commit/111111111111111111111111111
      "Failed to generate container configuration: #{limbo_reason}"
    elsif limbo_reason == 'CreateContainerConfigError'
      "Failed to generate container configuration: #{limbo_message}"
    end
  end
end

KubernetesDeploy::Pod::Container.send :prepend, PatchPodContainerClass

module AnthosDeployer
  module Resource
    class Pod < KubernetesDeploy::Pod

      TIMEOUT = 1.hour

      def deploy_succeeded?
        if unmanaged?
          return true if task_runner_container? && task_runner_was_successful
          phase == 'Succeeded'
        else
          phase == 'Running' && ready?
        end
      end

      def task_runner_was_successful
        task_status = task_runner_container.instance_variable_get(:@status)
        exited_with_code_zero = task_status.dig('state', 'terminated', 'exitCode') == 0 # rubocop:disable Style/NumericPredicate, Metrics/LineLength
        reason_completed = task_status.dig('state', 'terminated', 'reason') == 'Completed'
        exited_with_code_zero && reason_completed
      end

      def task_runner_container?
        task_runner_container.present?
      end

      def task_runner_container
        @containers.find { |container| container.name == 'task-runner' }
      end
    end
  end
end
