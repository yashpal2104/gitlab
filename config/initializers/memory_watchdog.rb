# frozen_string_literal: true

return unless Gitlab::Runtime.application?
return unless Gitlab::Utils.to_boolean(ENV['GITLAB_MEMORY_WATCHDOG_ENABLED'])

Gitlab::Cluster::LifecycleEvents.on_worker_start do
  watchdog = Gitlab::Memory::Watchdog.new

  watchdog.configure do |config|
    config.handler =
      if Gitlab::Runtime.puma?
        Gitlab::Memory::Watchdog::PumaHandler.new
      elsif Gitlab::Runtime.sidekiq?
        Gitlab::Memory::Watchdog::TermProcessHandler.new
      else
        Gitlab::Memory::Watchdog::NullHandler.instance
      end

    config.logger = Gitlab::AppLogger
    # config.monitor.use MonitorClass, args**, &block
    config.monitors.use Gitlab::Memory::Watchdog::Monitor::HeapFragmentation
    config.monitors.use Gitlab::Memory::Watchdog::Monitor::UniqueMemoryGrowth
  end

  Gitlab::BackgroundTask.new(watchdog).start
end
