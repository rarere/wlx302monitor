# WLX302の接続端末数データ取得用

## 取得イメージ

* 周波数

![周波数](https://github.com/rarere/wlx302monitor/blob/master/img/freq.png)

* 通信速度

![通信速度](https://github.com/rarere/wlx302monitor/blob/master/img/speed.png)

## ファイル

* ap_mon.pl: テスト用
* ap_mon_for_cacti.pl: cacti用
* cacti_graph_template_unix_-_wlx302_frequency_client.xml: cactiテンプレート(周波数毎のクライアント接続数)
* cacti_graph_template_unix_-_wlx302_rate_client: cactiテンプレート(接続速度毎のクライアント接続数)

## 必要な環境

* perl 5.12以上(たぶん)
* Encode
* HTTP::Request::Common
* LWP::UserAgent

## WLX302

ブラウザでの設定のSSID管理で、No.1に2.4Ghz、No.2に5GHzの設定を入れてることを想定しています。

## cactiへのinstall

Cacti version 0.8.8f

* perlと必要なモジュールを入れる
* ap_mon_for_cacti.pl を <cacti>/scripts/ に設置
* テンプレートをインポート
* デバイスを追加
* デバイスにテンプレートのグラフを追加。追加時に、IPアドレス、BASIC認証のユーザ名とパスワードを登録する。
* Graph Treesなどで表示できるようにしておく

## エターなるTODO

* ユニークな端末数
* 無線のエラーレート的なもののグラフ
* munin用設定追加

# 参考文献

http://projectphone.lekumo.biz/blog/2015/03/wlx302-lua-0c0d.html
