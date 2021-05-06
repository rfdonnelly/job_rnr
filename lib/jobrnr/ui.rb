# frozen_string_literal: true

module Jobrnr
  # User interface
  class UI
    require "io/console"
    require "pastel"

    attr_reader :color
    attr_reader :ctrl_c
    attr_reader :pool
    attr_reader :slots

    DEFAULT_TIME_SLICE_INTERVAL = 1

    KEYS = Hash.new do |h, k|
      k.chr
    end.merge({
      3 => :ctrl_c,
    })

    def initialize(pool:, slots:)
      @color = Pastel.new(enabled: $stdout.tty?)
      @ctrl_c = 0
      @pool = pool
      @slots = slots
      @time_slice_interval = Float(ENV.fetch("JOBRNR_TIME_SLICE_INTERVAL", DEFAULT_TIME_SLICE_INTERVAL))

      trapint
    end

    def pre_instance(inst)
      message = [
        "Running:",
        format_command(inst),
      ]

      message << format_iteration(inst) if inst.job.iterations > 1

      Jobrnr::Log.info message.join(" ")
    end

    def post_instance(inst)
      message = [
        format_status(inst),
        format_command(inst),
      ]

      message << format_iteration(inst) if inst.job.iterations > 1

      message << format("in %#.2fs", inst.duration)

      Jobrnr::Log.info message.join(" ")
    end

    def post_interval(stats)
      Jobrnr::Log.info stats.to_s
    end

    def post_application(early_termination:)
      Jobrnr::Log.info "Early termination due to reaching maximum failures" if early_termination
    end

    def sleep
      process_input
    end

    def stop_submission?
      ctrl_c.positive?
    end

    def process_input
      c = $stdin.getch(min: 0, time: @time_slice_interval)
      return unless c
      case KEYS[c.ord]
      when :ctrl_c
        sigint
      when "="
        $stdout.write("max-jobs=")
        begin
          n = Integer($stdin.gets)
          slots.resize(n)
        rescue ::ArgumentError
          $stdout.puts("could not parse integer")
        end
      end
    end

    def format_status(inst)
      if inst.success?
        color.green("PASSED:")
      else
        color.red("FAILED:")
      end
    end

    def format_command(inst)
      format(
        "'%<command>s' %<log>s",
        command: inst.to_s,
        log: File.basename(inst.log),
      )
    end

    def format_iteration(inst)
      format("iter:%d", inst.iteration) if inst.job.iterations > 1
    end

    def trapint
      trap "INT" do
        sigint
      end
    end

    # Handle Ctrl-C
    #
    # On first Ctrl-C, stop submitting new jobs and allow current jobs to
    # finish. On second Ctrl-C, send SIGINT to jobs. On third Ctrl-C, send
    # SIGTERM to jobs. On fourth (and subsequent) Ctrl-C, send SIGKILL to jobs.
    def sigint
      case ctrl_c
      when 0
        Jobrnr::Log.info "Stopping job submission. Allowing active jobs to finish."
        Jobrnr::Log.info "Ctrl-C again to interrupt active jobs with SIGINT."
      when 1
        Jobrnr::Log.info "Interrupting jobs with SIGINT."
        Jobrnr::Log.info "Ctrl-C again to terminate active jobs with SIGTERM."
        pool.sigint
      when 2
        Jobrnr::Log.info "Terminating jobs with SIGTERM."
        Jobrnr::Log.info "Ctrl-C again to kill active jobs with SIGKILL."
        pool.sigterm
      else
        Jobrnr::Log.info "Killing jobs with SIGKILL."
        pool.sigkill
      end

      @ctrl_c += 1
    end
  end
end
