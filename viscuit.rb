#!/usr/bin/env ruby
require 'json'
require 'sinatra'
require 'yaml'

USE_PLACES = 8
COLOR_COMMIT = '#729fcf'
COLOR_TREE = '#73a946'
COLOR_BLOB = '#fce94f'
COLOR_BRANCH = '#ad7fa8'

$dirs = []
ARGV.each do |x|
    name = ''
    if x.include?(':')
        x = x.split(':')
        name = x[1]
        x = x[0]
    end
    $dirs << [x, name]
end

class GitCrawler

    def initialize(index, dir, label = nil)
        @objects = {}
        @index = index
        @dir = dir
        @label = label
    end

    def update()
        @seeds = {}
        `git -C \"#{@dir}\" show-ref`.split("\n").each do |line|
            x = line.split(' ').first
            name = line.split(' ')[1].sub('refs/', '')
            @seeds[x] ||= []
            @seeds[x] << name
        end
        x = `git -C \"#{@dir}\" rev-parse HEAD`.strip
        @seeds[x] ||= []
        @seeds[x] << 'HEAD'

        @seeds.keys.each do |x|
            traverse(x)
        end
    end

    def traverse(hash, level = 10)
        return if level <= 0
        return if @objects.include?(hash)
        type = `git -C \"#{@dir}\" cat-file -t #{hash}`.strip
        cat = `git -C \"#{@dir}\" cat-file -p #{hash}`
        @objects[hash] = {:type => type}
        if type == 'commit'
            @objects[hash][:label] = "<B>commit</B><BR ALIGN=\"LEFT\"/>#{hash[0, USE_PLACES]}"
            cat.each_line do |line|
                line = line.split(' ')
                if line.first == 'tree' || line.first == 'parent'
                    traverse(line[1], level - 1)
                    @objects[hash][:links] ||= {}
                    @objects[hash][:links][line[1]] = {}
                end
            end
        elsif type == 'tree'
            @objects[hash][:label] = "<B>tree</B><BR ALIGN=\"LEFT\"/>#{hash[0, USE_PLACES]}"
            cat.each_line do |line|
                line = line.split(' ')
                traverse(line[2], level - 1)
                @objects[hash][:links] ||= {}
                @objects[hash][:links][line[2]] = {:label => line[3]}
            end
        elsif type == 'blob'
            @objects[hash][:label] = "<B>blob</B><BR ALIGN=\"LEFT\"/>#{hash[0, USE_PLACES]}<BR ALIGN=\"LEFT\"/>"
            @objects[hash][:label] += cat.gsub("\n", "<BR ALIGN=\"LEFT\"/>")
        end
#         color = {'tree' => COLOR_TREE, 'commit' => COLOR_COMMIT, 'blob' => COLOR_BLOB}[type]
#         color ||= '#ffffff'
#         content = ''
#         if type == 'blob'
#             content = `git -C \"#{dir.first}\" cat-file -p #{x}`.gsub("\n", "<BR ALIGN=\"LEFT\"/>")
#         end
#         result += "    \"#{x}_#{_}\" [label = <<B>#{type}<BR ALIGN=\"LEFT\"/></B>#{x}<BR ALIGN=\"LEFT\"/>#{content}>, fillcolor=\"#{color}\"];\n"
#         if type == 'tree'
#             `git -C \"#{dir.first}\" cat-file -p #{x}`.split("\n").each do |line|
#                 y = line.split(' ')[2][0, USE_PLACES]
#                 label = line.split(' ')[3]
#                 result += "    \"#{x}_#{_}\" -> \"#{y}_#{_}\" [label = \" #{label} \"];\n"
#             end
#         end
#         if type == 'commit'
#             `git -C \"#{dir.first}\" cat-file -p #{x}`.split("\n").each do |line|
#                 if line[0, 5] == 'tree '
#                     y = line.split(' ')[1][0, USE_PLACES]
#                     result += "    \"#{x}_#{_}\" -> \"#{y}_#{_}\";\n"
#                 end
#                 if line[0, 7] == 'parent '
#                     y = line.split(' ')[1][0, USE_PLACES]
#                     result += "    \"#{x}_#{_}\" -> \"#{y}_#{_}\";\n"
#                 end
#             end
#         end
#         if type == 'tag'
#             `git -C \"#{dir.first}\" cat-file -p #{x}`.split("\n").each do |line|
#                 if line[0, 7] == 'object '
#                     y = line.split(' ')[1][0, USE_PLACES]
#                     result += "    \"#{x}_#{_}\" -> \"#{y}_#{_}\";\n"
#                 end
#             end
#         end

    end

    def dot_subgraph()
        result = ''
        result += "    subgraph cluster_group_#{@index} {\n"
        result += "        labeljust = \"r\";\n"
        result += "        label = <<B>#{@label}</B>>;\n" if @label && !@label.empty?
        result += "        color = \"#808080\";\n"
        @seeds.each_pair do |hash, names|
            names.each do |name|
                color = COLOR_BRANCH
                label = name
                result += "        ref_#{name.gsub('/', '_')}_#{@index} [fillcolor=\"#{color}\", label=<#{label}>];\n"
            end
        end
        @objects.each_pair do |hash, info|
            color = {'commit' => COLOR_COMMIT, 'tree' => COLOR_TREE, 'blob' => COLOR_BLOB}[info[:type]]
            color ||= '#ffffff'
            label = info[:label] || hash[0, USE_PLACES]
            result += "        _#{hash[0, USE_PLACES]}_#{@index} [fillcolor=\"#{color}\", label=<#{label}>];\n"
        end
        @seeds.each_pair do |hash, names|
            names.each do |name|
                result += "        ref_#{name.gsub('/', '_')}_#{@index} -> _#{hash[0, USE_PLACES]}_#{@index};\n"
            end
        end
        @objects.each_pair do |hash, info|
            info[:links] && info[:links].each_pair do |other_hash, link_info|
                label = link_info[:label]
                label = "  #{label}  " if label
                result += "        _#{hash[0, USE_PLACES]}_#{@index} -> _#{other_hash[0, USE_PLACES]}_#{@index} [label = \"#{label}\"];"
            end
        end
        result += "    }"
        result
    end
end


def render_as_svg()
    result = ''
    result += "digraph {\n"
    result += "    rankdir=TB;\n"
    result += "    splines=true;\n"
    result += "    graph [fontname = \"Ubuntu Mono\", fontsize = 10, size = \"14, 11\", nodesep = 0.2, ranksep = 0.3];\n"
    result += "    node [fontname = \"Ubuntu Mono\", fontsize = 10, shape = rect, fillcolor = \"#ffffff\", style = filled];\n"
    result += "    edge [fontname = \"Ubuntu Mono\", fontsize = 10];\n"
    crawlers = {}
    $dirs.each_with_index do |dir, _|
        crawlers[dir] ||= GitCrawler.new(_, dir.first, dir[1])
        crawlers[dir].update()

        result += crawlers[dir].dot_subgraph()
    end

    result += "}\n"

    svg = nil
    IO::popen("dot -Tsvg -o /dev/stdout /dev/stdin", 'r+') do |io|
        io.puts result
        io.close_write()
        svg = io.read
    end
    svg[svg.index('<svg'), svg.size].sub('<svg', '<svg class="svg"')
end

disable :logging
set :port, 9595
set :server, :thin

puts "Please point your web browser to ==> [ http://127.0.0.1:9595 ]..."

get '/json/data' do
    content_type :json
    result = {
        :svg => render_as_svg()
    }
    return result.to_json
end

get '/' do
    redirect('index.html')
end
