module Netzke::Testing::Helpers
  def run_mocha_spec(path, options = {})
    @component = options[:component] || path.camelcase
    locale = options[:locale]
    url = netzke_components_path(class: @component, spec: path)
    url << "&locale=#{locale}" if locale

    visit url

    # Wait while the test is running
    wait_for_javascript(options)

    assert_mocha_results(options)
  end

  def wait_for_javascript(options = {})
    pause = options[:pause] || 0.1
    # no specs are supposed to run longer than 100 seconds (overridable though)
    timeout = options[:timeout] || 100

    start = Time.now
    loop do
      page.execute_script("return Netzke.mochaDone;") ? break : sleep(pause)

      raise "Timeout running JavaScript specs for #{@component}" if
        Time.now > start + timeout.seconds
    end

  rescue Selenium::WebDriver::Error::JavascriptError => e
    # give some time for visual examination of the problem
    sleep(pause) if pause > 0

    raise e
  end

  def assert_mocha_results(options)
    result = page.execute_script(<<-JS)
      var runner = Netzke.mochaRunner;
      var errors = [];
      Ext.Array.each(runner.suite.suites[0].tests, function(t) { if (t.err) errors.push([t.title, t.err.toString()]) });
      return {
        test: runner.test.title,
        success: runner.stats.failures == 0 && runner.stats.tests !=0,
        error: runner.test.err && runner.test.err.toString(),
        errors: errors
      }
    JS

    if !result["success"]
      pause = options[:pause] || 0
      # give some time for visual examination of the problem
      sleep(pause) if pause > 0

      errors = result["errors"].each_with_index.map do |(title, error), i|
        "#{i+1}) #{title}\n#{error}\n\n"
      end

      raise "Failures:\n#{errors.join}"
    end
  end
end
