require 'caze/version'
require 'active_support'
require 'active_support/concern'
require 'active_support/core_ext/module/delegation'

module Caze
  class NoTransactionMethodError < StandardError; end
  extend ActiveSupport::Concern

  module ClassMethods
    attr_accessor :transaction_handler

    def has_use_case(use_case_name, use_case_class, options = {})
      transactional = options.fetch(:transactional) { false }
      intercept_exceptions = options.fetch(:intercept_exceptions) { false }

      define_singleton_method(use_case_name, Proc.new do |*args|
        use_case = get_use_case_class(use_case_class)

        begin
          if transactional
            handler = self.transaction_handler

            unless handler
              raise NoTransactionMethodError,
                "This action should be executed inside a transaction. But no transaction handler was configured."
            end

            handler.transaction { use_case.send(use_case_name, *args) }
          else
            use_case.send(use_case_name, *args)
          end
        rescue => e
          if intercept_exceptions
            raise "#{use_case_class}: #{e.message}"
          else
            raise e
          end
        end
      end)
    end

    def export(method_name, options = {})
      method_to_define = options.fetch(:as) { method_name }

      define_singleton_method(method_to_define, Proc.new { |*args|
        use_case_object = args.empty? ? new : new(*args)
        use_case_object.send(method_name)
      })
    end

    private

    def get_use_case_class(use_case_class)
      if use_case_class.respond_to?(:upcase)
        return Object.const_get(use_case_class)
      end

      use_case_class
    end
  end
end
