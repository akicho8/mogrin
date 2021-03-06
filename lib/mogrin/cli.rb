# -*- coding: utf-8 -*-

require "optparse"
require_relative "../../lib/mogrin"

module Mogrin
  module CLI
    extend self

    def execute(args)
      config = Core.default_config

      oparser = OptionParser.new do |oparser|
        oparser.version = VERSION
        oparser.banner = [
          "似非死活監視 #{oparser.ver}\n",
          "使い方: #{oparser.program_name} [オプション] [タスク or URL or ホスト名...]\n",
        ].join
        oparser.on("タスク:")
        oparser.on("    host  鯖のチェック")
        oparser.on("    url   URLのチェック")
        oparser.on("    list  監視対象の確認")
        oparser.on("オプション:")
        oparser.on("-n", "--dry-run", "予行演習(#{config[:dry_run]})"){|v|config[:dry_run] = v}
        oparser.on("-m", "--match=STRING", "マッチしたもののみ", String){|v|config[:match] = v}
        oparser.on("-s", "--host=HOST", "ホストの指定"){|v|config[:host] = v}
        oparser.on("-u", "--url=URL", "URLの指定"){|v|config[:url] = v}
        oparser.on("-t", "--timeout=Float", "タイムアウト(#{config[:timeout]})", Float){|v|config[:timeout] = v}
        oparser.on("--pretty=TYPE", "鯖チェック結果の表示タイプ(full/process/dns/ssh)(default:#{config[:pretty]})", String){|v|config[:pretty] = v}
        oparser.on("レアオプション:")
        oparser.on("-x", "--skip-config", "デフォルトの設定ファイルを読み込まない(#{config[:skip_config]})"){|v|config[:skip_config] = v}
        oparser.on("-f", "--file=FILE", "読み込むファイルを指定", String) {|v|config[:file] = v}
        oparser.on("-q", "--quiet", "静かにする(#{config[:quiet]})"){|v|config[:quiet] = v}
        oparser.on("-a", "--append-log", "ログを結果の後につける(#{config[:append_log]})"){|v|config[:append_log] = v}
        oparser.on("-p", "--[no-]parallel", "--[no-]thread", "スレッドモード(#{config[:single]})") {|v|config[:single] = !v}
        oparser.on("-l", "--local", "ローカルが対象(#{config[:local]})"){|v|config[:local] = v}
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
