my @templates = <../templates/factory/*>;

my %doc;

for my $template (@templates) {
    open TEMP, $template or die $!;
    $template =~ s/.*factory\///g;
    while (<TEMP>) {
        next unless /^#?=for doc/... /^#?=cut/
                    and not /(%#?\]|\[%#?)$/
                    and not /=cut|=for doc/; # Much magic.
        s/^\s*#//g;
        $doc{$template} .= $_;
    }
}

while (<>) {
    if (!/^=template (\w+)/) { print; next; }
    die "Can't find doc for template $1" unless $doc{$1};
    print $doc{$1};
}
