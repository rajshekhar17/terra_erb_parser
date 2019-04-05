# Script to parse the terraform templates from erb
require 'erb'
require 'rhcl'
require 'active_support/core_ext/hash/deep_merge'
require 'json'
require 'mkmf'

input = ARGV
if input.length > 1
  puts "Not enough arguments passed, needed 0 or 1 got #{input.length}"
  exit
end

terraform_exe = find_executable('terraform')
if terraform_exe.to_s.empty?
  puts 'Terraform executable not found, exiting...'
  exit
end

def parse_tf
  # Parse the tf files to collect the attributes
  current_dir = Dir.pwd
  erb_files = Dir["#{current_dir}/**/*.erb"]
  terraform_files = Dir["#{current_dir}/**/*.tf*"]
  variables = {}
  terraform_files.each do |vars|
    begin
      variable = Rhcl.parse(File.open(vars))
      variables = variables.deep_merge(variable)
    rescue
      puts "Error parsing the following file : #{vars}\nKindly verify the format, fix it and retry..."
    end
  end

  # Write collected attributes to a local files
  f = File.open('./terraform_erb.variables.json', 'w')
  f.write(JSON.pretty_generate(variables))
  f.close

  # Parse the erb files and write to tf file
  erb_files.each do |erb|
    erb_file_name = erb.rpartition('/').last
    fpath = erb.gsub(erb_file_name, '')
    content = ERB.new(File.read(erb), 0, '%<>')
    begin
      Rhcl.parse(content.result(binding))
    rescue
      puts "Warning: #{erb_file_name} didn't converted to a valid tf, terraform command might not work"
    end
    f = File.open(fpath + '/' + erb_file_name.rpartition('.').first + '.tf', 'w')
    f.write(content.result(binding))
    f.close
  end
end

case input[0]
when nil
  parse_tf
  puts 'Parsing completed, you can use terraform commands'
when 'plan'
  parse_tf
  system(terraform_exe, 'init')
  system(terraform_exe, 'plan')
when 'apply'
  parse_tf
  system(terraform_exe, 'apply')
else
  puts 'Incorrect arguments'
end
