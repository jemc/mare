require "../../dsl_spec"

{% begin %}
{%
  main_help_message = <<-HELP_MESSAGE

                        Command Line Interface Tool.

                        Usage:

                          main_of_clim_library [options] [arguments]

                        Options:

                          -b, --bool                       Bool option description. [type:Bool]
                          --help                           Show this help.


                      HELP_MESSAGE
%}

 spec(
  spec_class_name: MainCommandWithBoolRequiredFalseOnly,
  spec_dsl_lines: [
    "option \"-b\", \"--bool\", type: Bool, desc: \"Bool option description.\", required: false",
  ],
  spec_desc: "main command with Bool option,",
  spec_cases: [
    {
      argv:        [] of String,
      expect_help: {{main_help_message}},
      expect_opts: {
        "type" => Bool,
        "method" => "bool",
        "expect_value" => false,
      },
      expect_args_value: [] of String,
    },
    {
      argv:        ["arg1"],
      expect_help: {{main_help_message}},
      expect_opts: {
        "type" => Bool,
        "method" => "bool",
        "expect_value" => false,
      },
      expect_args_value: ["arg1"],
    },
    {
      argv:        ["-b"],
      expect_help: {{main_help_message}},
      expect_opts: {
        "type" => Bool,
        "method" => "bool",
        "expect_value" => true,
      },
      expect_args_value: [] of String,
    },
    {
      argv:        ["--bool"],
      expect_help: {{main_help_message}},
      expect_opts: {
        "type" => Bool,
        "method" => "bool",
        "expect_value" => true,
      },
      expect_args_value: [] of String,
    },
    {
      argv:        ["-b", "arg1"],
      expect_help: {{main_help_message}},
      expect_opts: {
        "type" => Bool,
        "method" => "bool",
        "expect_value" => true,
      },
      expect_args_value: ["arg1"],
    },
    {
      argv:        ["arg1", "-b"],
      expect_help: {{main_help_message}},
      expect_opts: {
        "type" => Bool,
        "method" => "bool",
        "expect_value" => true,
      },
      expect_args_value: ["arg1"],
    },
    {
      argv:        ["--bool", "arg1"],
      expect_help: {{main_help_message}},
      expect_opts: {
        "type" => Bool,
        "method" => "bool",
        "expect_value" => true,
      },
      expect_args_value: ["arg1"],
    },
    {
      argv:        ["arg1", "--bool"],
      expect_help: {{main_help_message}},
      expect_opts: {
        "type" => Bool,
        "method" => "bool",
        "expect_value" => true,
      },
      expect_args_value: ["arg1"],
    },
    {
      argv:        ["--help"],
      expect_help: {{main_help_message}},
    },
    {
      argv:        ["--help", "ignore-arg"],
      expect_help: {{main_help_message}},
    },
    {
      argv:        ["ignore-arg", "--help"],
      expect_help: {{main_help_message}},
    },
  ]
)
{% end %}
