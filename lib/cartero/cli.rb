require 'optparse'
require 'ostruct'
require 'cartero/crypto_box'

module Cartero
	class CLI
		attr_reader :options

		def initialize(args)
			@args = args
			@options = OpenStruct.new
			@options.commands = []

			# Initialize all avilable loaded Commands that are parto of
			# Cartero::Commands and are its supper class is << Cartero::Command.
      Cartero::Commands.constants.each do |klass|
      	# Get the constant from the Kernel using the symbol
      	const = Kernel.const_get("Cartero::Commands::#{klass}")
      	# Check if the plugin has a super class and if the type is Plugin
      	if const.respond_to?(:superclass) and const.superclass == Cartero::Command
      	  Cartero::COMMANDS[klass.to_s] = const
      	end
      end

      # Initialize Crypto Box
			Cartero::CryptoBox.init

		end

		def commands
			@options.commands
		end

		def parse
			@parser = OptionParser.new do |opts|
	    	opts.banner = "Usage: cartero [options]"

	    	opts.separator ""

				opts.separator "List of Commands:\n    " + Cartero::COMMANDS.keys.join(", ")


	    	opts.separator ""
	      opts.separator "Global options:"

	    	opts.on("-p", "--proxy [HOST:PORT]", String,
	    		"Sets TCPSocket Proxy server") do |pxy|
	    		@options.proxy = pry
	    		require 'socksify'
	      	url, port = pxy.split(":")
	      	TCPSocket::socks_server = url
	      	TCPSocket::socks_port = port.to_i
	    	end

	    	opts.on("-c", "--config [CONFIG_FILE]", String,
	    		"Provide a different cartero config file") do |config|
	    		@options.config_file = config
	    	end

	      opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
	        @options.verbose = true
	      end

	    	opts.on("-p", "--ports [PORT_1,PORT_2,..,PORT_N]", String,
	    		"Global Flag to set Mailer and Webserver ports") do |p|
	    		@options.ports = p.split(",").map(&:to_i)

	    	end

	    	opts.on("-m", "--mongodb [HOST:PORT]", String,
	    		"Global flag to Set MongoDB bind_ip and port") do |p|
	    		@options.mongodb = p

	    	end

	    	opts.on("-d", "--debug", "Sets debug flag on/off") do
	    		@options.debug = true
	    	end

	    	opts.on("--editor [EDITOR]", String,
	    		"Edit Server") do |name|
	    		# User something besides ENV["EDITOR"].
	      	ENV["EDITOR"] = name
	    	end


	    	opts.separator ""
	      opts.separator "Common options:"

	      opts.on_tail("-h", "--help [COMMAND]", "Show this message") do |x|
	      	if x.nil?
	        	$stdout.puts opts
	      	else
	      		$stdout.puts subcommands[x].help
	      	end
	        exit
	      end
	    	
	    	opts.on("--list-commands", "Prints list of commands for bash completion") do
	    		$stdout.puts Cartero::COMMANDS.keys.join(" ")
	    	end

	      opts.on_tail("--version", "Shows cartero CLI version") do
	        puts Cartero::Version.join('.')
	        exit
	      end
			end
		end

		def run
			# Dealing with Global Options and Execution.
	    begin
	    	if @args.empty?
	    		$stdout.puts @parser
	    		exit
	    	end
	      @parser.order!
	    rescue OptionParser::InvalidOption, OptionParser::MissingArgument
	      $stderr.puts "Invalid global option, try -h for usage"
	      exit
	    end
			# Now it is time to parse all Commands.
			# It is important to notice that order of commands does matter.
			# Commands split option flags. i.e.
			# > Cartero [ Global options ] command1 [command1 options ] command2 [command2 options]

	    while !ARGV.empty?
	    	cmd = ARGV.shift
	    	if Cartero::COMMANDS.has_key?(cmd)
				  begin
				  	command = Cartero::COMMANDS[cmd].new
				  	if ARGV.empty?
		    			$stdout.puts command.help
		    			exit
		    		end
		    		command.order!
				  	commands << command
				  rescue OptionParser::InvalidOption, OptionParser::MissingArgument
				    $stderr.puts "Invalid sub-command #{cmd} option, try -h for usage"
				    exit
				  rescue StandardError => e
				  	$stderr.puts e
				  	exit(1)
				  end

				else
					$stderr.puts "Invalid command, try -h for usage"
				  exit(1)
				end
			end

			# Running commands objects created on parsing.
			commands.each do |cmd|
				begin
					cmd.options.debug = true if @options.debug
					cmd.options.verbose = true if @options.verbose
					cmd.options.ports = @options.ports if @options.ports
					cmd.options.mongodb = @options.mongodb if @options.mongodb
					cmd.run
				rescue StandardError => e
					$stderr.puts e.to_s
					$stderr.puts e.backtrace if @options.debug
				end
			end
		end
	end
end

