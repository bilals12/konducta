# frozen_string_literal: true

require_relative "context"

module konducta
    # execute diff stages + handle setup/shutdown routines
    class bot
        # init new bot instance
        # create new context instance + init sources/vendors based on context
        def initialize
            @context = Context.new
            @sources = @context.sources.map { |source| source.new(@context) }
            @vendors = @context.options.products.map { |(vendor, apps)| vendor.new(@context, apps) }
        end

        # expose log to user without exposing entire context
        # @return[konducta::Log]
        def log
            @context.log
        end

        # main method
        # log start of run + check for invalid options
        # if invalid options found, log warning or exit app (depends on `force` option)
        # reset git projects if necessary, process advisories, clean data directory
        # log end of run
        def run
            log.info("BEGIN -- run ##{@context.start.to_i}")
            if @context.options.invalid.any?
                message = "invalid options: #{@context.options.invalid.join(", ")}"
                @context.options.force ? log.warn(message) : (log.fatal(message); exit)
            end

            unless @context.options.safe
                reset(:carrier_vuln_tests) if @context.options.stages.transform
                reset(:konducta_data) if @context.options.stages.upload
            end
            process_advisories
            if @context.options.stages.upload && !@context.options.keep
                log.info("clean data directory"); @context.data.clean!
            end
            log.info("END -- runtime: #{@context.runtime}")
        end

        # shutdown procedures + stop execution
        # cancel ticket (if exists) + exit app
        def stop
            log.header
            @context.cancel_ticket if @context.ticket
            exit
        end

        # processing stages for each company
        # get list of stages from context's options
        # for each combo of source/vendor + stage, call stage method on company
        def process_advisories
            log.header
            stages = @context.options.stages.to_h.select { |key, value| value == true }
            (@sources + @vendors).product(stages.keys).each do |company, stage|
                log.info("#{company.alias.downcase} #{stage}"); company.public_send(stage)
            end
            nil
        end

        # reset git project
        # checkout dev branch + remove untracked files
        # @param [Symbol] project_key - project path name
        def reset(project_key)
            log.header
            return unless project = @context.clients.git.projects.public_send(project_key)
            log.debug("checkout dev branch for #{project.url.path.downcase}")
            @context.clients.git.checkout_dev_branch(project)
            nil
        end
    end
end

