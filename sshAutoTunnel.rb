#! /usr/bin/ruby
# Will create a reverse tunnel and maintain it.
# Takes in a JSON configuration which include keys -- 
# pip -- The public IP of the server.
# sshkey -- Path of the unencrypted private key to the sshd server.
# sshuser -- The ssh user to use to create the reverse tunnel.
# exposePorts -- What port will the server be listening to for the created reverse tunnel.
# sshPort -- SSH port of the server on the EC2 instance.
# privateIP -- The private IP of the server to which the reverse tunneled connection will listen to. This's probably the IP of the interface via which you access the Internet.
# localIP -- The IP to which the connection will map on the client. This's probably localhost, or the IP to which the sshd on your system listens to.
# localPort -- The port to which the connection will map on the client (your system).
# writeIntervel -- The interval between which this script will write to the created SSH session to the ec2 instance to test the connection.
# readDelay -- To ensure the ssh connection is active, this script will read the responses; after writing, it'll wait for these many seconds to give a chance for SSH to return the data. In case there's no response within these many seconds, will close the tunnel and retry.
# ServerAliveCountMax -- Sets the number of keepalive packets which may be sent by ssh without receiving any mes‐sages back from the server. If this threshold is reached, the ssh connection will be retried.
# ServerAliveInterval -- Intervals between keepalive packets for ssh.
# ConnectTimeout -- The timeout (in seconds) used when connecting to the SSH server (the started instance)
# Config file location will be the first argument to the script.
# 
# 
# Will use the ssh command to create the reverse tunnel without a tty. Will retry till infinity if ssh dies.
# Will send echo command to stdin to see if things are working. ssh client will die automatically if it's not.
# 
require 'oj'
Oj.default_options = { :symbol_keys => true, :bigdecimal_as_decimal => true, :mode => :compat, 'load' => :compat }
config = ARGF.read
config = Oj.load(config)

sshcmd = ['ssh', '-T', '-o', "ServerAliveCountMax=#{config[:ServerAliveCountMax]}", '-o', "ServerAliveInterval=#{config[:ServerAliveInterval]}", '-o', "ConnectTimeout=#{config[:ConnectTimeout]}",'-o', 'ExitOnForwardFailure=yes', '-i', config[:sshkey], '-p', config[:sshPort].to_s, '-R', "#{config[:privateIP]}:#{config[:exposePorts]}:#{config[:localIP]}:#{config[:localPort]}", "#{config[:sshuser]}@#{config[:pip]}"]
puts 'executing ssh....'
begin
	sshcmdIP = IO.popen(sshcmd, File::RDWR)
# 	algo 30.
	while 5 != 6
		if sshcmdIP.closed?
			sshcmdIP = IO.popen(sshcmd, File::RDWR)
			puts 'ssh terminated, retrying'
		end
		sleep config[:writeIntervel]
		sshcmdIP.puts('echo test')
		sleep config[:readDelay]
		sshReturn = sshcmdIP.read_nonblock(110)
	end
# 	algo 40
rescue Errno::EPIPE
	puts 'ssh terminated, retrying'
	sshcmdIP.close
	sleep config[:retryIntervel]
	retry
rescue IO::EAGAINWaitReadable
	puts 'ssh hanged'
	sshcmdIP.close
	sleep config[:retryIntervel]
	retry
rescue
	puts "#{$!} exception occurred."
	sshcmdIP.close
	sleep config[:retryIntervel]
	retry
end
