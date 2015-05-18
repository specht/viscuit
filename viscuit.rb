#!/usr/bin/env ruby
require 'json'
require 'rack'
require 'sinatra'

# module Rack
#     class CommonLogger
#         def call(env)
#             # do nothing
#             @app.call(env)
#         end
#     end
# end

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

def render_as_svg()
    result = ''
    result += "digraph {\n"
    result += "    rankdir=TB;\n"
    result += "    splines=true;\n"
    result += "    graph [fontname = \"Ubuntu Mono\", fontsize = 10, size = \"14, 11\", nodesep = 0.2, ranksep = 0.3];\n"
    result += "    node [fontname = \"Ubuntu Mono\", fontsize = 10, shape = rect, fillcolor = \"#ffffff\", style = filled];\n"
    result += "    edge [fontname = \"Ubuntu Mono\", fontsize = 10];\n"
    $dirs.each_with_index do |dir, _|
        
        result += "    subgraph cluster_group_#{_} {\n"
        result += "        labeljust = \"r\";\n"
        result += "        label = <<B>#{dir[1]}</B>>;\n" unless dir[1].empty?
        result += "        color = \"#808080\";\n"

        all_objects = `git -C \"#{dir.first}\" rev-list --objects --all`.split("\n").map { |x| x.split(' ').first[0, USE_PLACES]}
        all_objects.each do |x|
            type = `git -C \"#{dir.first}\" cat-file -t #{x}`.strip
            color = {'tree' => COLOR_TREE, 'commit' => COLOR_COMMIT, 'blob' => COLOR_BLOB}[type]
            color ||= '#ffffff'
            content = ''
            if type == 'blob'
                content = `git -C \"#{dir.first}\" cat-file -p #{x}`.gsub("\n", "<BR ALIGN=\"LEFT\"/>")
            end
            result += "    \"#{x}_#{_}\" [label = <<B>#{type}<BR ALIGN=\"LEFT\"/></B>#{x}<BR ALIGN=\"LEFT\"/>#{content}>, fillcolor=\"#{color}\"];\n"
            if type == 'tree'
                `git -C \"#{dir.first}\" cat-file -p #{x}`.split("\n").each do |line|
                    y = line.split(' ')[2][0, USE_PLACES]
                    label = line.split(' ')[3]
                    result += "    \"#{x}_#{_}\" -> \"#{y}_#{_}\" [label = \" #{label} \"];\n"
                end
            end
            if type == 'commit'
                `git -C \"#{dir.first}\" cat-file -p #{x}`.split("\n").each do |line|
                    if line[0, 5] == 'tree '
                        y = line.split(' ')[1][0, USE_PLACES]
                        result += "    \"#{x}_#{_}\" -> \"#{y}_#{_}\";\n"
                    end
                    if line[0, 7] == 'parent '
                        y = line.split(' ')[1][0, USE_PLACES]
                        result += "    \"#{x}_#{_}\" -> \"#{y}_#{_}\";\n"
                    end
                end
            end
            if type == 'tag'
                `git -C \"#{dir.first}\" cat-file -p #{x}`.split("\n").each do |line|
                    if line[0, 7] == 'object '
                        y = line.split(' ')[1][0, USE_PLACES]
                        result += "    \"#{x}_#{_}\" -> \"#{y}_#{_}\";\n"
                    end
                end
            end
        end
        `git -C \"#{dir.first}\" show-ref`.split("\n").each do |line|
            x = line[0, USE_PLACES]
            name = line.split(' ')[1].sub('refs/', '')
            result += "    \"ref_#{name}_#{_}\" [label = <<B>ref<BR ALIGN=\"LEFT\"/></B>#{name}>, fillcolor=\"#{COLOR_BRANCH}\"];\n"
            result += "    \"ref_#{name}_#{_}\" -> \"#{x}_#{_}\";\n"
        end
        x = `git -C \"#{dir.first}\" rev-parse HEAD`[0, USE_PLACES]
        result += "    \"ref_HEAD_#{_}\" [label = <<B>HEAD</B>>, fillcolor=\"#{COLOR_BRANCH}\"];\n"
        result += "    \"ref_HEAD_#{_}\" -> \"#{x}_#{_}\";\n"
        result += "}\n";
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

puts "Listening on http://127.0.0.1:9595 ..."

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
