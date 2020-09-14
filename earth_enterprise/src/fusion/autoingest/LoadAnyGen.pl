#!/usr/bin/perl -w-
#
# Copyright 2017 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use FindBin;
use Getopt::Long;
use File::Basename;


my $cppfile;
my $help = 0;
my $thiscommand = "@ARGV";

sub usage() {
    die "usage: $FindBin::Script --cppfile <cppfile> <plugin name>...\n";
}
GetOptions("cppfile=s" => \$cppfile,
	   "help|?"    => \$help) || usage();
usage() if $help;
usage() unless defined($cppfile);
my @plugins;
my %pluginpath;
foreach my $tmp (@ARGV) {
    if ($tmp =~ s,^deprecated/,,) {
        $pluginpath{$tmp} = "deprecated/$tmp";
    } else {
        $pluginpath{$tmp} = $tmp;
    }
    push @plugins, $tmp;
}

EnsureDirExists($cppfile);
my $fh;
chmod 0777, $cppfile;
open($fh, "> $cppfile") || die "Unable to open $cppfile: $!\n";
my $indent = '    ';

EmitAutoGeneratedWarning($fh);

print $fh <<EOF;
#include <string>
#include <khxml/khdom.h>
using namespace khxml;
#include <autoingest/AssetThrowPolicy.h>
#include <khGuard.h>
EOF

foreach my $plugin (@plugins) {
    print $fh "#include <autoingest/plugins/$pluginpath{$plugin}Asset.h>\n";
}



print $fh "\nconst char * const PluginNames[] = {\n";
foreach my $plugin (@plugins) {
    print $fh "    \"${plugin}\",\n";
}
print $fh "};\n";
print $fh "unsigned int NumPlugins = ", scalar(@plugins), ";\n\n";


print $fh <<EOF;

std::shared_ptr<AssetImpl>
AssetImpl::Load(const std::string &boundref)
{
    std::string filename = AssetImpl::XMLFilename(boundref);
    std::shared_ptr<AssetImpl> result;
    time_t timestamp = 0;
    unsigned long long filesize = 0;

    if (khGetFileInfo(filename, filesize, timestamp) && (filesize > 0)) {
	    std::unique_ptr<GEDocument> doc = ReadDocument(filename);
	    if (doc) {
		try {
		    DOMElement *top = doc->getDocumentElement();
		    if (!top)
			throw khException(kh::tr("No document element"));
		    std::string tagname = FromXMLStr(top->getTagName());
EOF


    my $first = 1;
    foreach my $plugin (@plugins) {
	if ($first) {
	    print $fh $indent x5;
	    $first = 0;
	}
	print $fh "if (tagname == \"${plugin}Asset\") {\n";
	print $fh $indent x6, "result = ${plugin}AssetImpl::NewFromDOM(top);\n";
	print $fh $indent x5, "} else ";
    }
    print $fh "{\n";

    print $fh <<EOF;
                        std::string msg { tagname + filename};
		        AssetThrowPolicy::WarnOrThrow
                          (kh::tr("Unknown asset type '%1' while parsing %2")
                           .arg(msg.c_str()));
		    }
	        } catch (const std::exception &e) {
                    std::string msg { filename + e.what() };
		    AssetThrowPolicy::WarnOrThrow
		      (kh::tr("Error loading %1: %2")
                       .arg(msg.c_str()));//ToQString(filename.c_str()), QString::fromUtf8(e.what())));
		} catch (...) {
		    AssetThrowPolicy::WarnOrThrow(kh::tr("Unable to load ")
                                                  + filename.c_str());
		}
	    } else {
	        AssetThrowPolicy::WarnOrThrow(kh::tr("Unable to read ")
                                              + filename.c_str());
	    }
    } else {
        AssetThrowPolicy::WarnOrThrow(kh::tr("No such file: ") + filename.c_str());
    }

    if (!result) {
	notify(NFY_DEBUG, "Creating placeholder for bad asset %s",
	       boundref.c_str());
	// use SourceAssetImpl since AssetImpl is pure virtual
	result = SourceAssetImpl::NewInvalid(boundref);

	// leave timestamp alone
        // if it failed but there was a vlid timestamp we want
	// to remember the timestamp of the one that failed
    }

    // store the timestamp so the cache can check it later
    result->timestamp = timestamp;
    result->filesize  = filesize;

    return result;
}


std::shared_ptr<AssetVersionImpl>
AssetVersionImpl::Load(const std::string &boundref)
{
    std::string filename = AssetVersionImpl::XMLFilename(boundref);
    std::shared_ptr<AssetVersionImpl> result;
    time_t timestamp = 0;
    unsigned long long filesize = 0;

    if (khGetFileInfo(filename, filesize, timestamp) && (filesize > 0)) {
	    std::unique_ptr<GEDocument> doc = ReadDocument(filename);
	    if (doc) {
		try {
		    DOMElement *top = doc->getDocumentElement();
		    if (!top)
			throw khException(kh::tr("No document element"));
		    std::string tagname = FromXMLStr(top->getTagName());
EOF


    $first = 1;
    foreach my $plugin (@plugins) {
	if ($first) {
	    print $fh $indent x5;
	    $first = 0;
	}
	print $fh "if (tagname == \"${plugin}AssetVersion\") {\n";
	print $fh $indent x6, "result = ${plugin}AssetVersionImpl::NewFromDOM(top);\n";
	print $fh $indent x5, "} else ";
    }
    print $fh "{\n";

    print $fh <<EOF;
		        AssetThrowPolicy::WarnOrThrow
                          (kh::tr("Unknown asset version type '%1' while parsing %2")
                           .arg(ToQString(tagname.c_str()), ToQString(filename.c_str())));
		    }
	        } catch (const std::exception &e) {
		    AssetThrowPolicy::WarnOrThrow
		      (kh::tr("Error loading %1: %2")
		       .arg(ToQString(filename.c_str()), QString::fromUtf8(e.what())));
		} catch (...) {
		    AssetThrowPolicy::WarnOrThrow(kh::tr("Unable to load ")
                                                  + filename.c_str());
		}
	    } else {
	        AssetThrowPolicy::WarnOrThrow(kh::tr("Unable to read ")
                                              + filename.c_str());
	    }
    } else {
        AssetThrowPolicy::WarnOrThrow(kh::tr("No such file: ") + filename.c_str());
    }


    if (!result) {
	notify(NFY_DEBUG, "Creating placeholder for bad asset version %s",
	       boundref.c_str());
	// use SourceAssetVersionImpl since AssetVersionImpl is pure virtual
	result = SourceAssetVersionImpl::NewInvalid(boundref);

	// leave timestamp alone
        // if it failed but there was a vlid timestamp we want
	// to remember the timestamp of the one that failed
    }

    // store the timestamp so the cache can check it later
    result->timestamp = timestamp;
    result->filesize  = filesize;

    return result;
}



EOF











close($fh);
chmod 0444, $cppfile;



sub EmitAutoGeneratedWarning
{
    my ($fh, $cs) = @_;
    $cs = '//' unless defined $cs;
    print $fh <<WARNING;
$cs ***************************************************************************
$cs ***  This file was AUTOGENERATED with the following command:
$cs ***
$cs ***  $FindBin::Script $thiscommand
$cs ***
$cs ***  Any changes made here will be lost.
$cs ***************************************************************************
WARNING
}

sub EnsureDirExists
{
    my $dir = dirname($_[0]);
    if (! -d $dir) {
	EnsureDirExists($dir);
	mkdir($dir) || die "Unable to mkdir $dir: $!\n";
    }
}
