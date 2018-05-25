require "./blockchan/node"

require "option_parser"

address = 9000
miner = false
slow = false
bootstrap_peers = [] of String

OptionParser.parse! do |parser|
  parser.banner = "Usage: blockchan [arguments]"
  parser.on("-h ADDR", "--host=ADDR", "node address") { |addr| address = addr.to_i }
  parser.on("-b ADDR", "--bootstrap=ADDR", "bootstrap node address") { |addr| bootstrap_peers.push(addr) }
  parser.on("-m", "--miner", "miner?") { miner = true }
  parser.on("-s", "--slow", "slow?") { slow = true }
  parser.on("-h", "--help", "Show this help") { puts parser }
end

node = Blockchan::Node.new(address, bootstrap_peers, miner: miner, slow: slow)

loop do
  puts "------------------"
  puts "#{node.peers.size} peers"
  puts "#{node.longest_fork.current_height} blocks"
  puts "#{node.wallet.total_balance} tokens"
  puts "------------------"
  sleep 10.seconds
end
