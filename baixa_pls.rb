require 'open-uri'
require 'thread'

# url_base = 'http://www.camara.gov.br/proposicoesWeb/prop_imp;jsessionid=.node2?tp=completa&idProposicao='
@url_base = 'http://www.camara.gov.br/proposicoesWeb/fichadetramitacao?idProposicao='

@queue = Queue.new
# first id > 12665
# 580209 - 07/06/2013
# 581181 - 14/06/2013
580209.upto(581181) do |pl_id| 
	@queue.push pl_id
end 

def pull_urls(thread_id)
	while pl_id = @queue.pop
			url  = @url_base + pl_id.to_s
			puts "#{thread_id.to_s.rjust(2, '0')} #{Time.now} #{url}"
			tried = 0
			begin
				html = open(url).read
			rescue
				tried += 1
				sleep 0.5
				retry if tried < 4
			end
			path = "pls/#{pl_id % 500}"
			`mkdir -p #{path}`
			File.open("#{path}/#{pl_id}.html", 'w') do |f|
				f.write html
			end
	end
end

threads = []
1.upto(20) do |i|
	threads << Thread.new {
		pull_urls(i)
	}
end

threads.map(&:join)