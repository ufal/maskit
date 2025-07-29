#!/usr/bin/env perl

# skript se na serveru spustí pomocí
# morbo api.pl (testování, v jednu chvíli jen jeden klient)
# nebo hypnotoad api.pl (ostrý provoz, více klientů naráz)

# Pak v případě morbo naslouchá na defaultním portu 3000 a lokálně funguje např.:
# curl http://localhost:3000/api/info
# A v případě hypnotoad naslouchá na defaultním portu 8080 a lokálně funguje např.:
# curl http://localhost:8080/api/info

# Perlovský balíček Mojolicious obsahující i příkaz morbo se instaloval pomocí 
# sudo apt-get install libmojolicious-perl

# Pro přesměrování požadavků z Apache2 bylo mj. potřeba nastavit v /etc/apache2/sites-available/000-default.conf v sekci <VirtualHost *:80>:
#        ServerName localhost
#        # Proxy pro /api/process a /api/info
#        ProxyPass "/api/process" "http://localhost:8080/api/process"
#        ProxyPassReverse "/api/process" "http://localhost:8080/api/process"
#        ProxyPass "/api/info" "http://localhost:8080/api/info"
#        ProxyPassReverse "/api/info" "http://localhost:8080/api/info"
# (port 8080 pro hypnotoad, resp. 3000 pro morbo)

# A v /etc/apache2/apache2.conf bylo potřeba přidat:
#        LoadModule proxy_module modules/mod_proxy.so
#        LoadModule proxy_http_module modules/mod_proxy_http.so
# Pak funguje např.
# curl http://localhost/api/info


use strict;
use warnings;
use Mojolicious::Lite;
use Sys::Syslog qw(:standard :macros); # Načtení modulu Sys::Syslog s potřebnými konstantami
use Getopt::Long; # reading arguments
use IPC::Run qw(run);
use JSON;
use Encode;
use File::Basename;
use Net::DNS;

# use Data::Dumper;

# STDIN and STDOUT in UTF-8
binmode STDIN, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my $script_path = $0;  # Získá název spuštěného skriptu s cestou
my $script_dir = dirname($script_path);  # Získá pouze adresář ze získané cesty

# variables for arguments
my $url_udpipe;
my $url_nametag;

# getting the arguments
GetOptions(
    'uu|url-udpipe=s'        => \$url_udpipe, # set a custom UDPipe URL
    'un|url-nametag=s'       => \$url_nametag, # set a custom NameTag URL
);


# Endpoint pro info
any '/api/info' => sub {
    my $c = shift;
    my $method = $c->req->method;

    # Spuštění skriptu maskit.pl s parametrem pro získání info
    my @cmd = ('/usr/bin/perl', "$script_dir/maskit.pl",
               '--info');
    my $stdin_data = '';
    my $result_json;
    run \@cmd, \$stdin_data, \$result_json;
        
    # Decode the output as a JSON object
    my $json_data = decode_json($result_json);

    # Access the 'data' and 'stats' items in the JSON object
    my $version  = $json_data->{'version'};
    my $features = $json_data->{'features'};
    my $version_utf8 = decode_utf8($version);
    my $features_utf8 = decode_utf8($features);

    # Vytvoření odpovědi
    $c->res->headers->content_type('application/json; charset=UTF-8');
    my $data = {message => "This is the info function of the MasKIT service called via $method.",
                version => "$version_utf8", features => "$features_utf8" };
    # print STDERR Dumper($data);
    return $c->render(json => $data);
};

# Endpoint pro process
any '/api/process' => sub {
    my $c = shift;
    my $method = $c->req->method;
    
    my $text = $c->param('text'); # input text
    my $input_format = $c->param('input') // ''; # input format
    my $output_format = $c->param('output') // ''; # output format
    my $randomize = defined $c->param('randomize') ? 1 : 0; # randomization
    my $classes = defined $c->param('classes') ? 1 : 0; # classes as replacements

    # Získání hlaviček pro původní informace
    my $referer = $c->req->headers->referer // 'unknown'; # Standardní referer
    my $forwarded_for = $c->req->headers->header('X-Forwarded-For') // 'unknown'; # Původní IP klienta
    my $forwarded_for_name = reverse_dns($forwarded_for);

    # Zápis do syslogu
    syslog(LOG_INFO, 'maskit: API request "process" from: "%s", X-Forwarded-For: "%s" ("%s"), method: "%s"',
           $referer, $forwarded_for, $forwarded_for_name, $method);
    syslog(LOG_INFO, 'maskit: API parameters: input format: "%s", output format: "%s", randomize: "%s", classes: "%s"',
           $input_format, $output_format, $randomize, $classes);

    # Spuštění skriptu maskit.pl s předáním parametrů a standardního vstupu
    my @cmd = ('/usr/bin/perl', "$script_dir/maskit.pl",
               '--stdin',
               '--replacements-file', "$script_dir/resources/replacements.csv",
               '--input-format', $input_format, 
               '--output-format', $output_format,
               '--diff',
               '--output-statistics');
    if ($randomize) {
        push(@cmd, '--randomize');
    }
    if ($classes) {
        push(@cmd, '--classes');
    }
    if ($url_udpipe) {
        push(@cmd, ('--url-udpipe', $url_udpipe));
    }
    if ($url_nametag) {
        push(@cmd, ('--url-nametag', $url_nametag));
    }
    my $stdin_data = $text;
    my $result_json;
    run \@cmd, \$stdin_data, \$result_json;
        
    # Decode the output as a JSON object
    my $json_data = decode_json($result_json);

    # Access the 'data' and 'stats' items in the JSON object
    my $result  = $json_data->{'data'};
    my $stats = $json_data->{'stats'};
    my $result_utf8 = decode_utf8($result);
    my $stats_utf8 = decode_utf8($stats);

    # Vytvoření odpovědi
    $c->res->headers->content_type('application/json; charset=UTF-8');
    my $data = {message => "This is the process function of the MasKIT service called via $method; input format=$input_format, output format=$output_format.",
                result => "$result_utf8", stats => "$stats_utf8" };
    # print STDERR Dumper($data);
    return $c->render(json => $data);

};

app->config(hypnotoad => {
    workers => 4,
    heartbeat_timeout => 50,
});

#app->log->level('debug');

app->start;


# Vrací název hostitele z reverzního DNS (PTR) nebo primární DNS server (SOA) pro zadanou IP adresu, preferuje veřejné IP z X-Forwarded-For.
sub reverse_dns {
    my $ip_input = shift;

    # Rozdělit X-Forwarded-For a vybrat první veřejnou IP adresu
    my @ips = split /\s*,\s*/, $ip_input;
    my $ip = 'unknown';
    foreach my $candidate (@ips) {
        if ($candidate =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ && $candidate !~ /^10\.|^192\.168\.|^172\.(1[6-9]|2[0-9]|3[0-1])\./) {
            $ip = $candidate;
            last;
        }
    }

    # Pokud není platná IP adresa, vrátit 'unknown'
    return 'unknown' unless $ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;

    my $resolver = Net::DNS::Resolver->new(nameservers => ['8.8.8.8', '8.8.4.4']);

    # PTR dotaz
    my $target = join(".", reverse split(/\./, $ip)) . ".in-addr.arpa";
    my $query = $resolver->query($target, "PTR");

    if ($query) {
        for my $rr ($query->answer) {
            next unless $rr->type eq "PTR";
            return $rr->ptrdname;
        }
    }

    # SOA dotaz
    my $zone = join(".", (reverse split(/\./, $ip))[1..3]) . ".in-addr.arpa";
    my $soa_query = $resolver->query($zone, "SOA");

    if ($soa_query) {
        for my $rr ($soa_query->answer) {
            next unless $rr->type eq "SOA";
            return $rr->mname;
        }
    }

    return 'unknown';
}

