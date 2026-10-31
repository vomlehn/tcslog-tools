# shellcheck shell=sh
# Puts the tcslog-tools package's programs where a login shell finds
# them. The directory is added only if it is not there already, so this
# file and the other TCS packages' can all be sourced, in any order and
# any number of times, without PATH growing.

case ":${PATH}:" in
*:/opt/tcs/bin:*)
	;;
*)
	PATH="${PATH:+${PATH}:}/opt/tcs/bin"
	;;
esac
export PATH
