require_relative '../lib/ncbo_resolver'

require 'minitest/unit'
MiniTest::Unit.autorun

class Unit < MiniTest::Unit
  def before_suites
    # code to run before the first test (gets inherited in sub-tests)
  end

  def after_suites
    # code to run after the last test (gets inherited in sub-tests)
  end

  def _run_suites(suites, type)
    begin
      before_suites
      super(suites, type)
    ensure
      after_suites
    end
  end

  def _run_suite(suite, type)
    begin
      suite.before_suite if suite.respond_to?(:before_suite)
      super(suite, type)
    rescue Exception => e
      puts e.message
      puts e.backtrace.join("\n\t")
      raise e
    ensure
      suite.after_suite if suite.respond_to?(:after_suite)
    end
  end
end

MiniTest::Unit.runner = Unit.new

class TestCase < MiniTest::Unit::TestCase
end