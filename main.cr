require "./src/mare"

require "clim"

module Mare
  class Cli < Clim
    main do
      desc "Mare compiler."
      usage "mare [sub_command]. Default sub_command in build"
      version "mare version: 0.0.1", short: "-v"
      help short: "-h"
      option "-b", "--backtrace", desc: "Show backtrace on error", type: Bool, default: false
      option "-r", "--release", desc: "Compile in release mode", type: Bool, default: false
      option "--no-debug", desc: "Compile without debug info", type: Bool, default: false
      option "--print-ir", desc: "Print generated LLVM IR", type: Bool, default: false
      option "--print-perf", desc: "Print compiler performance info", type: Bool, default: false
      option "-o NAME", "--output=NAME", desc: "Name of the output binary"
      option "-p NAME", "--pass=NAME", desc: "Name of the compiler pass to target"
      run do |opts, args|
        options = Mare::Compiler::CompilerOptions.new(
          release: opts.release,
          no_debug: opts.no_debug,
          print_ir: opts.print_ir,
          print_perf: opts.print_perf,
        )
        options.binary_name = opts.output.not_nil! if opts.output
        options.target_pass = Mare::Compiler.pass_symbol(opts.pass) if opts.pass
        Cli.compile options, opts.backtrace
      end
      sub "server" do
        alias_name "s"
        desc "run lsp server"
        usage "mare server [options]"
        help short: "-h"
        run do |opts, args|
          Mare::Server.new.run
        end
      end
      sub "eval" do
        alias_name "e"
        desc "evaluate code"
        usage "mare eval [code] [options]"
        help short: "-h"
        argument "code", type: String, required: true, desc: "code to evaluate"
        option "-b", "--backtrace", desc: "Show backtrace on error", type: Bool, default: false
        option "-r", "--release", desc: "Compile in release mode", type: Bool, default: false
        option "--no-debug", desc: "Compile without debug info", type: Bool, default: false
        option "--print-ir", desc: "Print generated LLVM IR", type: Bool, default: false
        option "--print-perf", desc: "Print compiler performance info", type: Bool, default: false
        run do |opts, args|
          options = Mare::Compiler::CompilerOptions.new(
            release: opts.release,
            no_debug: opts.no_debug,
            print_ir: opts.print_ir,
            print_perf: opts.print_perf,
          )
          Cli.eval args.code, options, opts.backtrace
        end
      end
      sub "run" do
        alias_name "r"
        desc "build and run code"
        usage "mare run [options]"
        help short: "-h"
        option "-b", "--backtrace", desc: "Show backtrace on error", type: Bool, default: false
        option "-r", "--release", desc: "Compile in release mode", type: Bool, default: false
        option "--no-debug", desc: "Compile without debug info", type: Bool, default: false
        option "--print-ir", desc: "Print generated LLVM IR", type: Bool, default: false
        option "--print-perf", desc: "Print compiler performance info", type: Bool, default: false
        option "-p NAME", "--pass=NAME", desc: "Name of the compiler pass to target"
        run do |opts, args|
          options = Mare::Compiler::CompilerOptions.new(
            release: opts.release,
            no_debug: opts.no_debug,
            print_ir: opts.print_ir,
            print_perf: opts.print_perf,
          )
          options.target_pass = Mare::Compiler.pass_symbol(opts.pass) if opts.pass
          Cli.run options, opts.backtrace
        end
      end
      sub "build" do
        alias_name "b"
        desc "build code"
        usage "mare build [options]"
        help short: "-h"
        option "-b", "--backtrace", desc: "Show backtrace on error", type: Bool, default: false
        option "-r", "--release", desc: "Compile in release mode", type: Bool, default: false
        option "-o NAME", "--output=NAME", desc: "Name of the output binary"
        option "--no-debug", desc: "Compile without debug info", type: Bool, default: false
        option "--print-ir", desc: "Print generated LLVM IR", type: Bool, default: false
        option "--print-perf", desc: "Print compiler performance info", type: Bool, default: false
        run do |opts, args|
          options = Mare::Compiler::CompilerOptions.new(
            release: opts.release,
            no_debug: opts.no_debug,
            print_ir: opts.print_ir,
            print_perf: opts.print_perf,
          )
          if opts.output
            options.binary_name = opts.output.not_nil!
          end
          Cli.compile options, opts.backtrace
        end
      end
      sub "compilerspec" do
        desc "run compiler specs"
        usage "mare compilerspec [target] [options]"
        help short: "-h"
        argument "target", type: String, required: true, desc: "mare.spec.md file to run"
        option "--print-perf", desc: "Print compiler performance info", type: Bool, default: false
        run do |opts, args|
          options = Mare::Compiler::CompilerOptions.new(
            print_perf: opts.print_perf,
          )
          Cli.compilerspec args.target, options
        end
      end
    end

    def self._add_backtrace(backtrace = false)
      if backtrace
        exit yield
      else
        begin
          exit yield
        rescue e : Error | Pegmatite::Pattern::MatchError
          STDERR.puts "Compilation Error:\n\n#{e.message}\n\n"
          exit 1
        rescue e
          message = if e.message
            "Mare compiler error occured with message \"#{e.message}\". Consider submitting new issue."
          else
            "Unknown Mare compiler error occured. Consider submitting new issue."
          end
          STDERR.puts message
          exit 1
        end
      end
    end

    def self.compile(options, backtrace = false)
      _add_backtrace backtrace do
        ctx = Mare.compiler.compile(Dir.current, options.target_pass || :binary, options)
        ctx.errors.any? ? finish_with_errors(ctx, backtrace) : 0
      end
    end

    def self.run(options, backtrace = false)
      _add_backtrace backtrace do
        ctx = Mare.compiler.compile(Dir.current, options.target_pass || :eval, options)
        ctx.errors.any? ? finish_with_errors(ctx, backtrace) : ctx.eval.exitcode
      end
    end

    def self.eval(code, options, backtrace = false)
      _add_backtrace backtrace do
        ctx = Mare.compiler.eval(code, options)
        ctx.errors.any? ? finish_with_errors(ctx, backtrace) : ctx.eval.exitcode
      end
    end

    def self.compilerspec(target, options)
      _add_backtrace true do
        spec = Mare::SpecMarkdown.new(target)
        ctx = Mare.compiler.compile(spec.sources, spec.target_pass, options)
        spec.verify!(ctx) ? 0 : 1
      end
    end

    def self.finish_with_errors(ctx, backtrace = false) : Int32
      puts
      puts "Compilation Error#{ctx.errors.size > 1 ? "s" : ""}:"
      ctx.errors.each { |error|
        puts
        puts "---"
        puts
        puts error.message(backtrace)
      }
      puts
      1 # exit code reflects the fact that compilation errors occurred
    end
  end
end

Mare::Cli.start(ARGV)
