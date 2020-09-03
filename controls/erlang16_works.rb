title 'Tests to confirm erlang16 works as expected'

plan_origin = ENV['HAB_ORIGIN']
plan_name = input('plan_name', value: 'erlang16')

control 'core-plans-erlang16-works' do
  impact 1.0
  title 'Ensure erlang16 works as expected'
  desc '
  Verify erlang16 by ensuring that
  (1) its installation directory exists 
  (2) all binaries, except for "erl" and "escript", return expected "help" usage info
  (3) escript successfully runs an erlang script that returns the expected version

  NOTE:
  (*) erl is ignored in this old version of erlang because it does not seem to behave like
      later versions.  So, for example, core/erlang[18,19,20,21,22] all verify erl evaluating
      a string to return the version.  For this version and test suite, it has been assumed that 
      since the escript works, then it must also be exercising erl under the covers.
  (*) testing all these binaries can be tricky: some use "--help" others use "-help"; 
      some return output to stdout, other to stderr; some return "Usage:..."
      others return "usage:..."  The outcome is that no one standard test pattern can be 
      used for all.  escript must reference an actual file; the normal linux <(..) re-direction
      does not work.
  '
  
  plan_installation_directory = command("hab pkg path #{plan_origin}/#{plan_name}")
  describe plan_installation_directory do
    its('exit_status') { should eq 0 }
    its('stdout') { should_not be_empty }
    its('stderr') { should be_empty }
  end
  
  plan_pkg_version = plan_installation_directory.stdout.split("/")[5]
  describe command("cat #{plan_installation_directory.stdout.chomp!}/lib/erlang/releases/RELEASES") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match /#{plan_pkg_version}/ }
    its('stderr') { should be_empty }
  end
  
  fullset = {
    "ct_run" => {
      command_output_pattern: /ct_run -vts \[-browser Browser\]/,
      exit_pattern: /^[0]$/,
    },
    "dialyzer" => {
      command_suffix: "--help",
      exit_pattern: /^[0]$/,
    },
    "epmd" => {
      io: "stderr", 
    },
    # "erl" => {
    #   command_prefix: "echo 'io:format(erlang:system_info(otp_release)). erlang:halt(0).' | hab pkg exec core/erlang16 -- ",
    #   command_suffix: "",
    #   command_output_pattern: /#{plan_pkg_version}/,
    #   io: "stderr",
    # },
    "erlc" => {
      io: "stderr", 
    },
    "escript" => {
      command_suffix: "",
      command_output_pattern: /#{plan_pkg_version}/, 
      exit_pattern: /^[0]$/,
      script: <<~END
        #!/usr/bin/env escript
        -export([main/1]).
        main([]) -> io:format(erlang:system_info(otp_release)).
      END
    },
    "run_erl" => {
      io: "stderr",
    },
    "to_erl" => {
      io: "stderr",
    },
    "typer" => {
      command_suffix: "--help",
      exit_pattern: /^[0]$/,
    }, 
  }.each do |binary_name, value|
    # set default values if each binary_name doesn't define an over-ride
    command_prefix = value[:command_prefix] || ""
    command_suffix = value[:command_suffix] || "-help"
    command_output_pattern = value[:command_output_pattern] || /[uU]sage:.+#{binary_name}/ 
    exit_pattern = value[:exit_pattern] || /^[^0]$/ # use /^[^0]$/ for non-zero exit status
    io = value[:io] || "stdout"
    script = value[:script]

    # set default 'command_under_test' only adding a Tempfile if 'script' is defined
    command_full_path = File.join(plan_installation_directory.stdout.strip, "bin", binary_name)
    command_statement = "#{command_prefix} #{command_full_path} #{command_suffix}"
    command_under_test = nil
    if(script)
      Tempfile.open('foo') do |f|
        f << script
        command_under_test = bash("#{command_statement} #{f.path}")
      end
    else
      command_under_test = bash("#{command_statement}")
    end

    # verify output
    describe command_under_test do
      its('exit_status') { should cmp exit_pattern }
      its(io) { should match command_output_pattern }
    end
  end
end