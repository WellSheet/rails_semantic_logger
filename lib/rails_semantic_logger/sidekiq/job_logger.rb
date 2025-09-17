module RailsSemanticLogger
  module Sidekiq
    class JobLogger
      # Sidekiq 6.5 does not take any arguments, whereas v7 is given a logger
      def initialize(*_args)
      end

      def call(item, queue, &block)
        klass  = item["wrapped"] || item["class"]
        logger = klass ? SemanticLogger[klass] : Sidekiq.logger

        SemanticLogger.tagged(queue: queue) do
          # Measure the duration of running the job
          logger.measure_info(
            "Completed #perform",
            on_exception_level: :error,
            log_exception:      :full,
            metric:             "sidekiq.job.perform",
            &block
          )
        end
      end

      def prepare(job_hash, &block)
        level = job_hash["log_level"]
        if level
          SemanticLogger.silence(level) do
            SemanticLogger.tagged(job_hash_context(job_hash), &block)
          end
        else
          SemanticLogger.tagged(job_hash_context(job_hash), &block)
        end
      end

      private

      def job_hash_context(job_hash)
        h         = {jid: job_hash["jid"]}
        h[:bid]   = job_hash["bid"] if job_hash["bid"]
        h[:tags]  = job_hash["tags"] if job_hash["tags"]
        h[:queue] = job_hash["queue"] if job_hash["queue"]
        h
      end
    end
  end
end
