#!/usr/bin/perl
#
# BZFlag
# Copyright (c) 1993 - 2002 Tim Riker
#
# This package is free software;  you can redistribute it and/or
# modify it under the terms of the license found in the file
# named LICENSE that should have accompanied this file.
#
# THIS PACKAGE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

package BZFlag;
use strict;

my $no_BZFlag;

BEGIN {
	$no_BZFlag = 0;
	eval "use Socket";
	eval "use LWP::UserAgent";
	$no_BZFlag++ if ($@);
}

sub BZFlag::BZFlag {
	my ($message) = @_;
  my ($retval);
	if ($no_BZFlag) {
		&main::status("BZFlag module requires Socket.");
		return 'BZFlag module not active';
	}
	if ($message =~ /^bzfquery\s+([^:]*)(?::([0-9]*))?$/xi) {
		$retval = &query($1,$2);
	} elsif ($message =~ /^bzflist$/xi) {
		$retval = &list();
  } else {
		$retval = "BZFlag: unhandled command \"$message\"";
	}
	&::performStrictReply($retval);
}

sub BZFlag::list {
	my ($response);
	my $ua = new LWP::UserAgent;

	$ua->timeout(5);

	my $req = HTTP::Request->new('GET', 'http://list.bzflag.org:5156/');
	my $res = $ua->request($req);
	for my $line (split("\n",$res->content)) {
		my ($serverport, $version, $flags, $ip, $comments) = split(" ",$line,5);
		# not "(A4)18" to handle old dumb perl
		my ($style,$maxPlayers,$maxShots,
				$rogueSize,$redSize,$greenSize,$blueSize,$purpleSize,
				$rogueMax,$redMax,$greenMax,$blueMax,$purpleMax,
				$shakeWins,$shakeTimeout,
				$maxPlayerScore,$maxTeamScore,$maxTime) =
				unpack("A4A4A4A4A4A4A4A4A4A4A4A4A4A4A4A4A4A4", $flags);
		my $playerSize = hex($rogueSize) + hex($redSize) + hex($greenSize)
				+ hex($blueSize) + hex($purpleSize);
		if ($playerSize > 0) {
			$response .= "$serverport($playerSize) ";
		}
	}
	&::performStrictReply($response);
	return;
}

sub BZFlag::querytext {
	my ($servernameport) = @_;
	my ($servername,$port) = split(":",$servernameport);
	if ($no_BZFlag) {
		&main::status("BZFlag module requires Socket.");
		return 'BZFlag module not active';
	}
	#my @teamName = ("Rogue", "Red", "Green", "Blue", "Purple");
	my @teamName = ("X", "R", "G", "B", "P");
	my ($message, $server, $response);
	$port = 5155 unless $port;

	# socket define
	my $sockaddr = 'S n a4 x8';

	# port to port number
	my ($name,$aliases,$proto) = getprotobyname('tcp');
	($name,$aliases,$port)  = getservbyname($port,'tcp') unless $port =~ /^\d+$/;

	# get server address
	my ($type,$len,$serveraddr);
	($name,$aliases,$type,$len,$serveraddr) = gethostbyname($servername);
	$server = pack($sockaddr, AF_INET, $port, $serveraddr);

	# connect
	return 'socket() error' unless socket(S1, AF_INET, SOCK_STREAM, $proto);
	return "could not connect to $servername:$port" unless connect(S1, $server);

	# don't buffer
	select(S1); $| = 1; select(STDOUT);

	# get hello
	my $buffer;
	return 'read error' unless sysread(S1, $buffer, 10) == 10;

	# parse reply
	my ($magic,$major,$minor,$revision);
	($magic,$major,$minor,$revision,$port) = unpack("a4 a1 a2 a1 n", $buffer);

	# quit if version isn't valid
	return 'not a bzflag server' if ($magic ne "BZFS");
	return 'incompatible version' if ($major < 1);
	return 'incompatible version' if ($major == 1 && $minor < 7);
	return 'incompatible version' if ($major == 1 && $minor == 7 && $revision eq "b");

	# quit if rejected
	return 'rejected by server' if ($port == 0);

	# reconnect on new port
	$server = pack($sockaddr, AF_INET, $port, $serveraddr);
	return 'socket() error on reconnect' unless socket(S, AF_INET, SOCK_STREAM, $proto);
	return "could not reconnect to $servername:$port" unless connect(S, $server);
	select(S); $| = 1; select(STDOUT);

	# close first socket
	close(S1);

	# send game request
	print S pack("n2", 0, 0x7167);

	# get reply
	return 'server read error' unless sysread(S, $buffer, 40) == 40;
	my ($infolen,$infocode,$style,$maxPlayers,$maxShots,
		$rogueSize,$redSize,$greenSize,$blueSize,$purpleSize,
		$rogueMax,$redMax,$greenMax,$blueMax,$purpleMax,
		$shakeWins,$shakeTimeout,
		$maxPlayerScore,$maxTeamScore,$maxTime) = unpack("n20", $buffer);
	return 'bad server data' unless $infocode == 0x7167;

	# send players request
	print S pack("n2", 0, 0x7170);

	# get number of teams and players we'll be receiving
	return 'count read error' unless sysread(S, $buffer, 8) == 8;
	my ($countlen,$countcode,$numTeams,$numPlayers) = unpack("n4", $buffer);
	return 'bad count data' unless $countcode == 0x7170;

	# get the teams
	for (1..$numTeams) {
		return 'team read error' unless sysread(S, $buffer, 14) == 14;
		my ($teamlen,$teamcode,$team,$size,$aSize,$won,$lost) = unpack("n7", $buffer);
		return 'bad team data' unless $teamcode == 0x7475;
		if ($size > 0) {
			my $score = $won - $lost;
			$response .= "$teamName[$team]:$score($won-$lost) ";
		}
	}

	# get the players
	for (1..$numPlayers) {
		last unless sysread(S, $buffer, 180) == 180;
		my ($playerlen,$playercode,$pAddr,$pPort,$pNum,$type,$team,$won,$lost,$sign,$email) =
				unpack("n2Nn2 n4A32A128", $buffer);
		return 'bad player data' unless $playercode == 0x6170;
		my $score = $won - $lost;
		$response .= " $sign($teamName[$team]";
		$response .= ":$email" if ($email);
		$response .= ")$score($won-$lost)";
	}
	$response .= "No Players" if ($numPlayers <= 1);

	# close socket
	close(S);

	return $response;
}

sub BZFlag::query {
	my ($servernameport) = @_;
	&::performStrictReply(&querytext($servernameport));
  return;
}

1;
# vim: ts=2 sw=2
