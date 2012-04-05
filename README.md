似非死活監視ツール
==================

使い方
------

    $ mog --help
    似非死活監視 mog 0.1.4
    使い方: mog [オプション] [タスク or URL or ホスト名...]
    タスク:
        host  鯖のチェック
        url   URLのチェック
        list  監視対象の確認
    オプション:
        -n, --dry-run                    予行演習(false)
        -m, --match=STRING               マッチしたもののみ
        -s, --host=HOST                  ホストの指定
        -u, --url=URL                    URLの指定
        -t, --timeout=Float              タイムアウト(16.0)
    レアオプション:
        -x, --skip-config                デフォルトの設定ファイルを読み込まない(false)
        -f, --file=FILE                  読み込むファイルを指定
        -q, --quiet                      静かにする(false)
        -a, --append-log                 ログを結果の後につける(false)
        -p, --[no-]parallel              スレッドモード(true)
            --[no-]thread
        -l, --local                      ローカルが対象(false)
        -d, --debug                      デバッグモード(false)
            --help                       このヘルプを表示する

実行例
------

    $ cat ~/.mogrin.rb
    # -*- coding: utf-8; mode: ruby -*-

    config[:hosts] = [
      {:desc => "メモ", :host => "memoria"},
      {:desc => "自分", :host => "localhost"},
    ]

    config[:urls] = [
      {:desc => "表,   :url => "http://example.net/"},
      {:desc => "管理, :url => "http://example.net/admin},
    ]

    $ mog
    +----------+--------------------------------+-----+------+----------+---------+-------------+------+------+----+
    | DESC     | URL                            | RET | 反速 | Title    | Ref     | 最終        | 書人 | 過時 | PD |
    +----------+--------------------------------+-----+------+----------+---------+-------------+------+------+----+
    | XxXX提出 | http://production.example.net/ | 503 | 0.53 |          |         |             |      |      |    |
    | 社内用表 | http://staging.example.net/    | 200 | 0.13 | XXXXXX - | e9a25d9 | 03-21 23:13 | xxxx | 2d   | 42 |
    | XXX用表  | http://example.net/            | 200 | 0.25 | XXXXXX - | b1a4540 | 03-22 16:09 | xxxx | 2d   | 21 |
    | XxXX     | http://foo.example.jp/12345678 | 302 | 0.09 |          |         |             |      |      |    |
    +----------+--------------------------------+-----+------+----------+---------+-------------+------+------+----+
    +----------+--------------------------+----+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
    | 用途     | 鯖名                     |LAVG|UP |IDS|NGX|NGS|UCN|UCS|RSQ|RSW|RDS|PRX|MEM|Git|SSH|GOD|
    +----------+--------------------------+----+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
    | XxXX     | production1.example.net  |    |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
    | XxXX     | production2.example.net  |    |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
    | STAGE    | staging.example.net      |0.01|14d| 84|  1|  1|  2|  8| 10|  4|  2|  2|  1|  0|  3|  1|
    | DEBUG    | example1.net             |0.01|14d| 82|  1|  1|  2|  8| 10|  4|  2|  1|  1|  0|  3|  1|
    | template | example2.net             |0.06|1d | 69|  1|  1|  0|  0|  0|  0|  0|  2|  0|  0|  3|  0|
    | resque1  | resque-batch1            |    |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
    | resque2  | resque-batch2            |    |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
    | app/db   | production               |    |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
    | GATEWAY  | gateway.example.net      |1.24|1d |167|  0|  0|  0|  0|  0|  0|  0|  0|  0|  0|  3|  0|
    | local    | localhost                |2.68|12d|163|  0|  0|  0|   |  0|  0|  1|  0|  1|  0|  5|  0|
    +----------+--------------------------+----+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
