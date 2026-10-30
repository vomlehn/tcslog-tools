# The tcslog-tools RPM, built by `make rpm` from the tree `make stage`
# installed under build/stage/tcslog-tools. Nothing is compiled here:
# %install copies that tree, so the RPM and the .deb hold the same
# files, built once. The Makefile passes tcs_version, from Cargo.toml,
# and tcs_stage.

%{!?tcs_version: %{error: tcs_version is not defined: build with make rpm}}
%{!?tcs_stage: %{error: tcs_stage is not defined: build with make rpm}}

# The stage is already what is to be installed, stripped or not as
# `make stage` was told by STRIP. RPM's own post-install steps would
# strip it regardless and split out debugging information, neither of
# which the .deb has, so they are turned off and the two packages hold
# the same bytes.
%global debug_package %{nil}
%global __os_install_post %{nil}
%global _build_id_links none

Name:		tcslog-tools
Version:	%{tcs_version}
Release:	1%{?dist}
Summary:	Tools for inspecting tcslog segment files
License:	MIT OR Apache-2.0
URL:		https://github.com/vomlehn/tcslog-tools
Packager:	David VomLehn <dvomlehn@gmail.com>

%description
tcslog-dump reads a whole tcslog log, a directory of segment files
sharing a prefix and suffix, and prints the records it recovers with
the losses it found. tcslog-dumphdr prints one segment file's header.

Both only read, and both have the tcslog library built in, so this
package needs nothing of tcslog's installed. They install under
/opt/tcs/bin.

%install
cp -a %{tcs_stage}/. %{buildroot}/

# Takes away the links tcslog-tools-links made, in either directory it
# is meant for, while it is still installed, so that removing the
# package leaves none dangling. Only when the package is going ($1 is
# 0), not on an upgrade, and never failing the removal.
%preun
if [ "$1" = 0 ]; then
	for dir in /usr/local/bin /opt/bin; do
		/opt/tcs/sbin/tcslog-tools-links --remove --dir "$dir" \
			> /dev/null 2>&1 || true
	done
fi

%files
%dir /opt/tcs
%dir /opt/tcs/bin
%dir /opt/tcs/sbin
%dir /opt/tcs/share
%dir /opt/tcs/share/doc
/opt/tcs/bin/tcslog-dump
/opt/tcs/bin/tcslog-dumphdr
/opt/tcs/sbin/tcslog-tools-links
%doc /opt/tcs/share/doc/tcslog-tools/
%config(noreplace) /etc/profile.d/tcslog-tools.sh
