SimpleCov.start 'rails' do
  # any custom configs like groups and filters can be here at a central place
	coverage_dir 'tmp/simplecov'
	add_filter 'spec/spec_helper.rb'
end
