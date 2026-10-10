ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def create_import(filename: "test.csv")
      Import.create!(filename: filename, sha256: ::Digest::SHA256.hexdigest(filename), byte_size: 1)
    end
  end
end
