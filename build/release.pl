#!/usr/bin/perl
use strict;

# dont look at this

my $release_dir = shift || die "need release dir";
my $version     = shift || die "need version";

my $joose_dir   = "joose-$version";
my $compile_dir = "$release_dir/$joose_dir";

mkdir $compile_dir || die "Cant make compile dir: $!";

use FindBin;
use File::Find;
use File::Copy;

sub exe ($);

my $path = "$FindBin::Bin/..";

my $files = [
    "Joose.js",               "Joose/Builder.js",
    "Joose/Class.js",         "Joose/Method.js",
    "Joose/ClassMethod.js",   "Joose/Method.js",
    "Joose/Attribute.js",     "Joose/Role.js",
    "Joose/SimpleRequest.js", "Joose/Gears.js",
    "Joose/Storage.js",       "Joose/Storage/Unpacker.js",
    "Joose/Decorator.js",     "Joose/Module.js",
    "Joose/Prototype.js",     "Joose/TypeConstraint.js",
    "Joose/TypeCoercion.js"
];

wipe_dir($compile_dir);
make_single_js();
compile();

sub compile {
    foreach my $file (qw/LICENCE README INSTALL/) {
        copy("$path/$file", "$path/joose/$file") or die "Cant copy file $file: $!";
    }
    
    export_dir("$path/examples", "$compile_dir/examples");
    export_dir("$path/tests", "$compile_dir/tests");
    export_dir("$path/ext", "$compile_dir/ext");
    export_dir("$path/lib", "$compile_dir/lib");
    
    chdir $release_dir or die "Cant change working dir: $!";
    gzip_dir($joose_dir);
    
    print "Made Release file\n";
}

sub make_single_js {

    # JS-Lib
    print "Building JS-Lib\n";

    @$files = map { "$path/lib/$_" } @$files;

    my $now = localtime;

    my $output = "// Generated: $now\n\n";

    foreach my $filename (@$files)
    {
        open my $in, "$filename" or die "Cant open $filename due to $!";
        my @content = <$in>;

        my $short = $filename;
        my $quoted_path = quotemeta($path."/lib/");
        $short =~ s(^$quoted_path)();

        $output .= "
// ##########################
// File: $short
// ##########################
";

        $output .= join "", @content;
    }

    # Write all JS-Code to a single file
     write_file("$compile_dir/joose.js", $output);
    
    # minify file

    $output =~ s(^\s*//.*$)()gm;    # c++ style comments on line without code
    $output =~ s(^\s+)()gm;         # leading white space
    my $end = "\s*[\r\n]+";
    $output =~ s(;$end)(;)g;         # no newline after ;
    $output =~ s({$end)({)g;         # no newline after {
    $output =~ s(\s+$)()mg;          # trailing space
    $output =~ s(\n+)(\n)g;          # multiple new lines
    $output =~ s(//[^"'\n]*$)()gm;   # c++ style comments that cant be in quotes

    # Write all JS-Code to a single file
    write_file("$compile_dir/joose.mini.js", $output);
    
    # quick hack to get bleeding edge copy into blok
    copy_file("$compile_dir/joose.mini.js", "/ws/Joose2/examples/blok/static");

    print "Built Mini JS-Lib\n";
}

sub write_file {
    my($filename, $content) = @_;
    open my $out, ">$filename"
      or die "Cant open $filename for writing due to $!";
    print $out $content;
    close $out;
    
    gzip($filename);
}

sub gzip {
    my ($file) = @_;
    print exe qq(gzip -cf $file > $file.gz);
}

sub copy_file {
    my ($file, $target) = @_;
    print exe qq(cp $file $target);
}

sub gzip_dir {
    my ($dir) = @_;
    print exe qq(tar -czvf $dir.tgz $dir);
}

sub export_dir {
    my ($from, $to) = @_;
    print exe qq(svn export $from $to);
}

sub wipe_dir {
    my ($dir) = @_;
    print exe qq(rm -Rf $dir/*);
}

sub exe($) {
    my($command) = @_;
    
    print "$command\n";
    print qx($command);
}