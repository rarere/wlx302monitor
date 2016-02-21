#!/usr/bin/perl -w
# 参考
# http://projectphone.lekumo.biz/blog/2015/03/wlx302-lua-0c0d.html
#
# cacti用

use strict;
use warnings;
use feature qw(say);
use utf8;
use Encode;
use HTTP::Request::Common;
use LWP::UserAgent;


if(@ARGV != 4){
    die("Usage: $0 <hostname|ip_address> <username> <password> <frequency|rate>\n");
}

####################################################
# 設定など
####################################################
# アクセスポイントの情報
my $ap = {
    'host'     => $ARGV[0],
    'user'     => $ARGV[1],
    'password' => $ARGV[2],
};

# アクセス先・実行するコマンド
my $path = '/cgi-bin/admin/manage-config.sh';
my $cmd  = 'console columns 120
show airlink station list';

# 最大伝送速度的なもの(適当)
# 90Mbpsなら72以上144以下ということで72として扱う
my $rates = [1, 2, 5.5, 6, 9, 11, 12, 18, 24, 36, 48, 54, 72, 144, 150, 216, 288, 300];

# 周波数表示用
my $f_list = ['2.4GHz', '5GHz'];

my $opt = $ARGV[3];

####################################################
# 関数
####################################################
# APへアクセスしてPOST結果を取得
sub getPostRequest {
    my ($ap) = @_;
    my $req = POST(
        "http://$ap->{host}$path",
        'Content_Type' => 'multipart/form-data',
        'Content'      => [
            submit     => 1,                   # なくても動くみたい
            config_cmd => $cmd,                # 実行するコマンド
            run_cmd    => encode_utf8('実行'), # なんでもいいから文字列が必要っぽい
        ],
    );
    $req->authorization_basic($ap->{user}, $ap->{password});

    # resposeオブジェクトを取得
    my $ua  = LWP::UserAgent->new;
    my $res = $ua->request($req);
    my $msg = $res->as_string;

    return $msg;
}



# レスポンスから実行結果だけ抜き出す
sub getCmdResult {
    my ($response) = @_;

    my $result;
    if ($response =~ m/<textarea.*>(.*)<\/textarea>/s) {
        # 改行区切りで配列にする
        for my $str (split('\n', $1)) {
            # 不要分削除
            next if ($str =~ /^$/ or $str =~ /^#/ or $str =~ /^  ADDR/ or $str =~ /^  ----/);
            $str =~ s/^\s+//;
            # 必要な分を配列に
            push(@$result, $str);
        }
    }

    return $result;
}



# コマンドの実行結果を成型
sub resultToModules {
    my ($result) = @_;

    my $str;
    my $modules = {};

    for my $line (@$result) {
        if ($line =~ /^MODULE/) {
            $str     = $line;
            my $hash = {$line => undef};
            $modules = {%$modules, %$hash};
            $modules->{$str} = {count => 0, user => undef};
        } elsif ($line =~ /([0-9a-z][0-9a-z][:-]){5}[0-9a-z][0-9a-z]/i) {
            $modules->{$str}->{count}++;
            my @array = split(" ", $line);
            my $user  = {
                'CHAN'    => $array[2],
                'RATE'    => $array[3],
            };
            push(@{$modules->{$str}->{user}}, \%$user);
        }
    }
    return $modules;
}



# 全接続数を取得
sub getTotalClient {
    my $modules = shift;
    my $total = 0;
    while (my ($key, $module) = each %$modules) {
        $total += $module->{count};
    }
    return $total;
}


# 周波数毎のクライアント数
sub getFClient {
    my $modules = shift;

    # 2.4GHzと5GHzのそれぞれの接続数
    my $f = {
        '2.4GHz' => 0,
        '5GHz' => 0,
    };

    while (my ($key, $module) = each %$modules) {
        for my $user (@{$module->{user}}) {
            my $channel = $user->{CHAN};
            if (1 <= $channel and $channel < 14) {
                $f->{'2.4GHz'}++;
            } else {
                $f->{'5GHz'}++;
            }
        }
    }
    return $f;
}



# 接続速度ごとのクライアント数
sub getRateClient {
    my $modules = shift;

    # 通信速度ごとのクライアント数の配列を作成(0で初期化)
    my $rate_count = {};
    for my $r (@$rates) {
        $rate_count->{$r . 'Mbps'} = 0;
    }
    $rate_count->{other} = 0;

    # 通信速度ごとのクライアント数を数える
    while (my ($key, $module) = each %$modules) {
        for my $user (@{$module->{user}}) {
            my $user_rate = $user->{RATE};
            my $rate_str  = getRateString($user_rate);
            $rate_count->{$rate_str}++;
        }
    }

    return $rate_count;
}



# どの通信速度に当たるかを返す
sub getRateString {
    my $user_rate = shift;
    $user_rate    =~ s/M//; # 「数字M」という文字列が来るので数字だけにする

    my $rate_str = 'other'; # 該当しない場合の文字列を用意

    for (my $i = 0; $i < scalar(@$rates) - 1; $i++) {
        my $low  = @$rates[$i];
        my $high = @$rates[$i + 1];

        if ($high == $user_rate) {
            # 高いほうと同じだったらそれを返す
            $rate_str = $high . 'Mbps';
            last;
        } elsif ($low <= $user_rate and $user_rate < $high) {
            # 例：100Mpsの場合は72Mbpsとして扱う
            $rate_str = $low . 'Mbps';
            last;
        }
    }
    return $rate_str;
}


####################################################
# メイン処理
####################################################
# レスポンスを取得
my $response = getPostRequest($ap);

# レスポンスからコマンドの実行結果だけ抜き出す
my $result = getCmdResult($response);

# コマンド実行結果を成型
my $modules = resultToModules($result);

# APにつないでる合計クライアント数
# my $total = getTotalClient($modules);
# say("total: $total");

if ($opt eq 'frequency') {
    # ヘルツ数毎接続数を表示
    my $f_client = getFClient($modules);
    for my $f (@$f_list) {
        print $f . ':' . $f_client->{$f} . ' ';
    }
} elsif ($opt eq 'rate') {
    # 周波数毎の接続数を表示
    my $rate_client = getRateClient($modules);
    for my $r (@$rates) {
        print($r . 'Mbps:' . $rate_client->{$r . 'Mbps'} . ' ');
    }
    print('other:' . $rate_client->{other});
}




__END__
