# frozen_string_literal: true

module Jobrnr
  module Job
    # The job execution pool.
    #
    # Contains all active jobs.
    class Pool
      require "concurrent"

      def initialize
        self.futures = []
        self.instances = []
      end

      def empty?
        self.futures.empty?
      end

      # Removes completed job instances from the pool and returns them
      def remove_completed
        completed_futures = self.futures.select(&:fulfilled?)
        remove_futures(completed_futures)
        completed_instances = completed_futures.map(&:value)
        remove_instances(completed_instances)
        completed_instances
      end

      # Adds job instances to the pool and starts them
      def add_and_start(instances)
        self.instances.concat(instances)
        self.futures.concat(create_futures(instances))
      end

      def sigint
        self.instances.each(&:sigint)
      end

      private

      attr_accessor :futures
      attr_accessor :instances

      def remove_futures(completed_futures)
        self.futures.reject! do |future|
          completed_futures.any? do |completed_future|
            future == completed_future
          end
        end
      end

      def remove_instances(completed_instances)
        self.instances.reject! do |instance|
          completed_instances.any? do |completed_instance|
            instance == completed_instance
          end
        end
      end

      def create_futures(instances)
        instances.map { |instance| Concurrent::Promises.future { instance.execute } }
      end
    end
  end
end
