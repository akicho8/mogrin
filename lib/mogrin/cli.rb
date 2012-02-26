# -*- coding: utf-8 -*-

require "optparse"
require_relative "../../lib/mogrin"

module Mogrin
  module CLI
    extend self

    def execute(args = ARGV)
      config = Core.default_config

      oparser = OptionParser.new do |oparser|
        oparser.version = VERSION
        oparser.banner = [
          "似非死活監視 #{oparser.ver}\n",
          "使い方: #{oparser.program_name} [オプション] [タスク...]\n",
        ].join
        oparser.on("タスク")
        oparser.on("    server  鯖のチェック")
        oparser.on("    url     URL毎にチェック")
        oparser.on("    list    監視対象の確認")
        oparser.on("オプション")
        oparser.on("-t", "--timeout=Float", "タイムアウト(#{config[:timeout]})", Float) {|v|config[:timeout] = v}
        oparser.on("-f", "--file=FILE", "読み込むファイルを指定", String) {|v|config[:file] = v}
        oparser.on("-q", "--quiet", "静かにする(#{config[:quiet]})"){|v|config[:quiet] = v}
        oparser.on("-x", "--skip-config", "設定ファイルを読み込まない(#{config[:skip_config]})"){|v|config[:skip_config] = v}
        oparser.on("-m", "--match=STRING", "マッチしたもののみ", String) {|v|config[:match] = v}
        oparser.on("-d", "--debug", "デバッグモード(#{config[:debug]})"){|v|config[:debug] = v}
        oparser.on("--help", "このヘルプを表示する") {puts oparser; abort}
      end

      begin
        args = oparser.parse(args)
      rescue => error
        puts error
        usage(oparser)
      end

      Core.run(args, config)
    end

    def usage(oparser)
      puts "使い方: #{oparser.program_name} [オプション] [タスク...]"
      puts "`#{oparser.program_name}' --help でより詳しい情報を表示します。"
      abort
    end
  end
end

if $0 == __FILE__
  Mogrin::CLI.execute(["--help"])
end
