# Snapshot file
# Unset all aliases to avoid conflicts with functions
unalias -a 2>/dev/null || true
# Functions
compaudit () {
	emulate -L zsh
	setopt extendedglob
	[[ -n $commands[getent] ]] || getent () {
		if [[ $1 = hosts ]]
		then
			sed 's/#.*//' /etc/$1 | grep -w $2
		elif [[ $2 = <-> ]]
		then
			grep ":$2:[^:]*$" /etc/$1
		else
			grep "^$2:" /etc/$1
		fi
	}
	if (( $# ))
	then
		local _compdir='' 
	elif (( $#fpath == 0 ))
	then
		print 'compaudit: No directories in $fpath, cannot continue' >&2
		return 1
	else
		set -- $fpath
	fi
	(( $+_i_check )) || {
		local _i_q _i_line _i_file _i_fail=verbose 
		local -a _i_files _i_addfiles _i_wdirs _i_wfiles
		local -a -U +h fpath
	}
	fpath=($*) 
	(( $+_compdir )) || {
		local _compdir=${fpath[(r)*/$ZSH_VERSION/*]} 
		[[ -z $_compdir ]] && _compdir=$fpath[1] 
	}
	_i_wdirs=() 
	_i_wfiles=() 
	_i_files=(${^~fpath:/.}/^([^_]*|*~|*.zwc)(N)) 
	if [[ -n $_compdir ]]
	then
		if [[ $#_i_files -lt 20 || $_compdir = */Base || -d $_compdir/Base ]]
		then
			_i_addfiles=() 
			if [[ -d $_compdir/Base/Core ]]
			then
				_i_addfiles=(${_compdir}/*/*(/^M)) 
			elif [[ -d $_compdir/Base ]]
			then
				_i_addfiles=(${_compdir}/*(/^M)) 
			fi
			for _i_line in {1..$#_i_addfiles}
			do
				(( $_i_line )) || break
				_i_file=${_i_addfiles[$_i_line]} 
				[[ -d $_i_file && -z ${fpath[(r)$_i_file]} ]] || _i_addfiles[$_i_line]= 
			done
			fpath=($fpath $_i_addfiles) 
			_i_files=(${^~fpath:/.}/^([^_]*|*~|*.zwc)(N)) 
		fi
	fi
	[[ $_i_fail == use ]] && return 0
	local _i_owners="u0u${EUID}" 
	local -a _i_exes
	_i_exes=(/proc/$$/exe /proc/$$/object/a.out) 
	local _i_exe
	for _i_exe in $_i_exes
	do
		if [[ -e $_i_exe ]]
		then
			if zmodload -F zsh/stat b:zstat 2> /dev/null
			then
				local -A _i_stathash
				if zstat -H _i_stathash $_i_exe && [[ $_i_stathash[uid] -ne 0 ]]
				then
					_i_owners+="u${_i_stathash[uid]}" 
				fi
			fi
			break
		fi
	done
	_i_wdirs=(${^fpath}(N-f:g+w:,-f:o+w:,-^${_i_owners}) ${^fpath:h}(N-f:g+w:,-f:o+w:,-^${_i_owners})) 
	if (( $#_i_wdirs ))
	then
		local GROUP GROUPMEM _i_pw _i_gid
		if ((UID == EUID ))
		then
			getent group $LOGNAME | IFS=: read GROUP _i_pw _i_gid GROUPMEM
		else
			getent group $EGID | IFS=: read GROUP _i_pw _i_gid GROUPMEM
		fi
		if [[ $GROUP == $LOGNAME && ( -z $GROUPMEM || $GROUPMEM == $LOGNAME ) ]]
		then
			_i_wdirs=(${^_i_wdirs}(N-f:g+w:^g:${GROUP}:,-f:o+w:,-^${_i_owners})) 
		fi
	fi
	if [[ -f /etc/debian_version ]]
	then
		local _i_ulwdirs
		_i_ulwdirs=(${(M)_i_wdirs:#/usr/local/*}) 
		_i_wdirs=(${_i_wdirs:#/usr/local/*} ${^_i_ulwdirs}(Nf:g+ws:^g:staff:,f:o+w:,^u0)) 
	fi
	_i_wdirs=($_i_wdirs ${^fpath}.zwc^([^_]*|*~)(N-^${_i_owners})) 
	_i_wfiles=(${^fpath}/^([^_]*|*~)(N-^${_i_owners})) 
	case "${#_i_wdirs}:${#_i_wfiles}" in
		(0:0) _i_q=  ;;
		(0:*) _i_q=files  ;;
		(*:0) _i_q=directories  ;;
		(*:*) _i_q='directories and files'  ;;
	esac
	if [[ -n "$_i_q" ]]
	then
		[[ $_i_fail == verbose ]] && {
			print There are insecure ${_i_q}: >&2
			print -l - $_i_wdirs $_i_wfiles
		}
		return 1
	fi
	return 0
}
compdef () {
	local opt autol type func delete eval new i ret=0 cmd svc 
	local -a match mbegin mend
	emulate -L zsh
	setopt extendedglob
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	while getopts "anpPkKde" opt
	do
		case "$opt" in
			(a) autol=yes  ;;
			(n) new=yes  ;;
			([pPkK]) if [[ -n "$type" ]]
				then
					print -u2 "$0: type already set to $type"
					return 1
				fi
				if [[ "$opt" = p ]]
				then
					type=pattern 
				elif [[ "$opt" = P ]]
				then
					type=postpattern 
				elif [[ "$opt" = K ]]
				then
					type=widgetkey 
				else
					type=key 
				fi ;;
			(d) delete=yes  ;;
			(e) eval=yes  ;;
		esac
	done
	shift OPTIND-1
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	if [[ -z "$delete" ]]
	then
		if [[ -z "$eval" ]] && [[ "$1" = *\=* ]]
		then
			while (( $# ))
			do
				if [[ "$1" = *\=* ]]
				then
					cmd="${1%%\=*}" 
					svc="${1#*\=}" 
					func="$_comps[${_services[(r)$svc]:-$svc}]" 
					[[ -n ${_services[$svc]} ]] && svc=${_services[$svc]} 
					[[ -z "$func" ]] && func="${${_patcomps[(K)$svc][1]}:-${_postpatcomps[(K)$svc][1]}}" 
					if [[ -n "$func" ]]
					then
						_comps[$cmd]="$func" 
						_services[$cmd]="$svc" 
					else
						print -u2 "$0: unknown command or service: $svc"
						ret=1 
					fi
				else
					print -u2 "$0: invalid argument: $1"
					ret=1 
				fi
				shift
			done
			return ret
		fi
		func="$1" 
		[[ -n "$autol" ]] && autoload -rUz "$func"
		shift
		case "$type" in
			(widgetkey) while [[ -n $1 ]]
				do
					if [[ $# -lt 3 ]]
					then
						print -u2 "$0: compdef -K requires <widget> <comp-widget> <key>"
						return 1
					fi
					[[ $1 = _* ]] || 1="_$1" 
					[[ $2 = .* ]] || 2=".$2" 
					[[ $2 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$1" "$2" "$func"
					if [[ -n $new ]]
					then
						bindkey "$3" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] && bindkey "$3" "$1"
					else
						bindkey "$3" "$1"
					fi
					shift 3
				done ;;
			(key) if [[ $# -lt 2 ]]
				then
					print -u2 "$0: missing keys"
					return 1
				fi
				if [[ $1 = .* ]]
				then
					[[ $1 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" "$1" "$func"
				else
					[[ $1 = menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" ".$1" "$func"
				fi
				shift
				for i
				do
					if [[ -n $new ]]
					then
						bindkey "$i" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] || continue
					fi
					bindkey "$i" "$func"
				done ;;
			(*) while (( $# ))
				do
					if [[ "$1" = -N ]]
					then
						type=normal 
					elif [[ "$1" = -p ]]
					then
						type=pattern 
					elif [[ "$1" = -P ]]
					then
						type=postpattern 
					else
						case "$type" in
							(pattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_patcomps[$match[1]]="=$match[2]=$func" 
								else
									_patcomps[$1]="$func" 
								fi ;;
							(postpattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_postpatcomps[$match[1]]="=$match[2]=$func" 
								else
									_postpatcomps[$1]="$func" 
								fi ;;
							(*) if [[ "$1" = *\=* ]]
								then
									cmd="${1%%\=*}" 
									svc=yes 
								else
									cmd="$1" 
									svc= 
								fi
								if [[ -z "$new" || -z "${_comps[$1]}" ]]
								then
									_comps[$cmd]="$func" 
									[[ -n "$svc" ]] && _services[$cmd]="${1#*\=}" 
								fi ;;
						esac
					fi
					shift
				done ;;
		esac
	else
		case "$type" in
			(pattern) unset "_patcomps[$^@]" ;;
			(postpattern) unset "_postpatcomps[$^@]" ;;
			(key) print -u2 "$0: cannot restore key bindings"
				return 1 ;;
			(*) unset "_comps[$^@]" ;;
		esac
	fi
}
compdump () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
compinit () {
	emulate -L zsh
	setopt extendedglob
	typeset _i_dumpfile _i_files _i_line _i_done _i_dir _i_autodump=1 
	typeset _i_tag _i_file _i_addfiles _i_fail=ask _i_check=yes _i_name _i_why 
	while [[ $# -gt 0 && $1 = -[dDiuCw] ]]
	do
		case "$1" in
			(-d) _i_autodump=1 
				shift
				if [[ $# -gt 0 && "$1" != -[dfQC] ]]
				then
					_i_dumpfile="$1" 
					shift
				fi ;;
			(-D) _i_autodump=0 
				shift ;;
			(-i) _i_fail=ign 
				shift ;;
			(-u) _i_fail=use 
				shift ;;
			(-C) _i_check= 
				shift ;;
			(-w) _i_why=1 
				shift ;;
		esac
	done
	typeset -gHA _comps _services _patcomps _postpatcomps
	typeset -gHA _compautos
	typeset -gHA _lastcomp
	if [[ -n $_i_dumpfile ]]
	then
		typeset -g _comp_dumpfile="$_i_dumpfile" 
	else
		typeset -g _comp_dumpfile="${ZDOTDIR:-$HOME}/.zcompdump" 
	fi
	typeset -gHa _comp_options
	_comp_options=(bareglobqual extendedglob glob multibyte multifuncdef nullglob rcexpandparam unset NO_allexport NO_aliases NO_cshnullglob NO_cshjunkiequotes NO_errexit NO_errreturn NO_globassign NO_globsubst NO_histsubstpattern NO_ignorebraces NO_ignoreclosebraces NO_kshglob NO_ksharrays NO_kshtypeset NO_markdirs NO_octalzeroes NO_posixbuiltins NO_posixidentifiers NO_shwordsplit NO_shglob NO_typesettounset NO_warnnestedvar NO_warncreateglobal) 
	typeset -gH _comp_setup='local -A _comp_caller_options;
             _comp_caller_options=(${(kv)options[@]});
             setopt localoptions localtraps localpatterns ${_comp_options[@]};
             local IFS=$'\'\ \\t\\r\\n\\0\'';
             builtin enable -p \| \~ \( \? \* \[ \< \^ \# 2>&-;
             exec </dev/null;
             trap - ZERR;
             local -a reply;
             local REPLY;
             local REPORTTIME;
             unset REPORTTIME' 
	typeset -ga compprefuncs comppostfuncs
	compprefuncs=() 
	comppostfuncs=() 
	: $funcstack
	compdef () {
		local opt autol type func delete eval new i ret=0 cmd svc 
		local -a match mbegin mend
		emulate -L zsh
		setopt extendedglob
		if (( ! $# ))
		then
			print -u2 "$0: I need arguments"
			return 1
		fi
		while getopts "anpPkKde" opt
		do
			case "$opt" in
				(a) autol=yes  ;;
				(n) new=yes  ;;
				([pPkK]) if [[ -n "$type" ]]
					then
						print -u2 "$0: type already set to $type"
						return 1
					fi
					if [[ "$opt" = p ]]
					then
						type=pattern 
					elif [[ "$opt" = P ]]
					then
						type=postpattern 
					elif [[ "$opt" = K ]]
					then
						type=widgetkey 
					else
						type=key 
					fi ;;
				(d) delete=yes  ;;
				(e) eval=yes  ;;
			esac
		done
		shift OPTIND-1
		if (( ! $# ))
		then
			print -u2 "$0: I need arguments"
			return 1
		fi
		if [[ -z "$delete" ]]
		then
			if [[ -z "$eval" ]] && [[ "$1" = *\=* ]]
			then
				while (( $# ))
				do
					if [[ "$1" = *\=* ]]
					then
						cmd="${1%%\=*}" 
						svc="${1#*\=}" 
						func="$_comps[${_services[(r)$svc]:-$svc}]" 
						[[ -n ${_services[$svc]} ]] && svc=${_services[$svc]} 
						[[ -z "$func" ]] && func="${${_patcomps[(K)$svc][1]}:-${_postpatcomps[(K)$svc][1]}}" 
						if [[ -n "$func" ]]
						then
							_comps[$cmd]="$func" 
							_services[$cmd]="$svc" 
						else
							print -u2 "$0: unknown command or service: $svc"
							ret=1 
						fi
					else
						print -u2 "$0: invalid argument: $1"
						ret=1 
					fi
					shift
				done
				return ret
			fi
			func="$1" 
			[[ -n "$autol" ]] && autoload -rUz "$func"
			shift
			case "$type" in
				(widgetkey) while [[ -n $1 ]]
					do
						if [[ $# -lt 3 ]]
						then
							print -u2 "$0: compdef -K requires <widget> <comp-widget> <key>"
							return 1
						fi
						[[ $1 = _* ]] || 1="_$1" 
						[[ $2 = .* ]] || 2=".$2" 
						[[ $2 = .menu-select ]] && zmodload -i zsh/complist
						zle -C "$1" "$2" "$func"
						if [[ -n $new ]]
						then
							bindkey "$3" | IFS=$' \t' read -A opt
							[[ $opt[-1] = undefined-key ]] && bindkey "$3" "$1"
						else
							bindkey "$3" "$1"
						fi
						shift 3
					done ;;
				(key) if [[ $# -lt 2 ]]
					then
						print -u2 "$0: missing keys"
						return 1
					fi
					if [[ $1 = .* ]]
					then
						[[ $1 = .menu-select ]] && zmodload -i zsh/complist
						zle -C "$func" "$1" "$func"
					else
						[[ $1 = menu-select ]] && zmodload -i zsh/complist
						zle -C "$func" ".$1" "$func"
					fi
					shift
					for i
					do
						if [[ -n $new ]]
						then
							bindkey "$i" | IFS=$' \t' read -A opt
							[[ $opt[-1] = undefined-key ]] || continue
						fi
						bindkey "$i" "$func"
					done ;;
				(*) while (( $# ))
					do
						if [[ "$1" = -N ]]
						then
							type=normal 
						elif [[ "$1" = -p ]]
						then
							type=pattern 
						elif [[ "$1" = -P ]]
						then
							type=postpattern 
						else
							case "$type" in
								(pattern) if [[ $1 = (#b)(*)=(*) ]]
									then
										_patcomps[$match[1]]="=$match[2]=$func" 
									else
										_patcomps[$1]="$func" 
									fi ;;
								(postpattern) if [[ $1 = (#b)(*)=(*) ]]
									then
										_postpatcomps[$match[1]]="=$match[2]=$func" 
									else
										_postpatcomps[$1]="$func" 
									fi ;;
								(*) if [[ "$1" = *\=* ]]
									then
										cmd="${1%%\=*}" 
										svc=yes 
									else
										cmd="$1" 
										svc= 
									fi
									if [[ -z "$new" || -z "${_comps[$1]}" ]]
									then
										_comps[$cmd]="$func" 
										[[ -n "$svc" ]] && _services[$cmd]="${1#*\=}" 
									fi ;;
							esac
						fi
						shift
					done ;;
			esac
		else
			case "$type" in
				(pattern) unset "_patcomps[$^@]" ;;
				(postpattern) unset "_postpatcomps[$^@]" ;;
				(key) print -u2 "$0: cannot restore key bindings"
					return 1 ;;
				(*) unset "_comps[$^@]" ;;
			esac
		fi
	}
	typeset _i_wdirs _i_wfiles
	_i_wdirs=() 
	_i_wfiles=() 
	autoload -RUz compaudit
	if [[ -n "$_i_check" ]]
	then
		typeset _i_q
		if ! eval compaudit
		then
			if [[ -n "$_i_q" ]]
			then
				if [[ "$_i_fail" = ask ]]
				then
					if ! read -q "?zsh compinit: insecure $_i_q, run compaudit for list.
Ignore insecure $_i_q and continue [y] or abort compinit [n]? "
					then
						print -u2 "$0: initialization aborted"
						unfunction compinit compdef
						unset _comp_dumpfile _comp_secure compprefuncs comppostfuncs _comps _patcomps _postpatcomps _compautos _lastcomp
						return 1
					fi
				fi
				fpath=(${fpath:|_i_wdirs}) 
				(( $#_i_wfiles )) && _i_files=("${(@)_i_files:#(${(j:|:)_i_wfiles%.zwc})}") 
				(( $#_i_wdirs )) && _i_files=("${(@)_i_files:#(${(j:|:)_i_wdirs%.zwc})/*}") 
			fi
			typeset -g _comp_secure=yes 
		fi
	fi
	autoload -RUz compdump compinstall
	_i_done='' 
	if [[ -f "$_comp_dumpfile" ]]
	then
		if [[ -n "$_i_check" ]]
		then
			IFS=$' \t' read -rA _i_line < "$_comp_dumpfile"
			if [[ _i_autodump -eq 1 && $_i_line[2] -eq $#_i_files && $ZSH_VERSION = $_i_line[4] ]]
			then
				builtin . "$_comp_dumpfile"
				_i_done=yes 
			elif [[ _i_why -eq 1 ]]
			then
				print -nu2 "Loading dump file skipped, regenerating"
				local pre=" because: " 
				if [[ _i_autodump -ne 1 ]]
				then
					print -nu2 $pre"-D flag given"
					pre=", " 
				fi
				if [[ $_i_line[2] -ne $#_i_files ]]
				then
					print -nu2 $pre"number of files in dump $_i_line[2] differ from files found in \$fpath $#_i_files"
					pre=", " 
				fi
				if [[ $ZSH_VERSION != $_i_line[4] ]]
				then
					print -nu2 $pre"zsh version changed from $_i_line[4] to $ZSH_VERSION"
				fi
				print -u2
			fi
		else
			builtin . "$_comp_dumpfile"
			_i_done=yes 
		fi
	elif [[ _i_why -eq 1 ]]
	then
		print -u2 "No existing compdump file found, regenerating"
	fi
	if [[ -z "$_i_done" ]]
	then
		typeset -A _i_test
		for _i_dir in $fpath
		do
			[[ $_i_dir = . ]] && continue
			(( $_i_wdirs[(I)$_i_dir] )) && continue
			for _i_file in $_i_dir/^([^_]*|*~|*.zwc)(N)
			do
				_i_name="${_i_file:t}" 
				(( $+_i_test[$_i_name] + $_i_wfiles[(I)$_i_file] )) && continue
				_i_test[$_i_name]=yes 
				IFS=$' \t' read -rA _i_line < $_i_file
				_i_tag=$_i_line[1] 
				shift _i_line
				case $_i_tag in
					(\#compdef) if [[ $_i_line[1] = -[pPkK](n|) ]]
						then
							compdef ${_i_line[1]}na "${_i_name}" "${(@)_i_line[2,-1]}"
						else
							compdef -na "${_i_name}" "${_i_line[@]}"
						fi ;;
					(\#autoload) autoload -rUz "$_i_line[@]" ${_i_name}
						[[ "$_i_line" != \ # ]] && _compautos[${_i_name}]="$_i_line"  ;;
				esac
			done
		done
		if [[ $_i_autodump = 1 ]]
		then
			compdump
		fi
	fi
	for _i_line in complete-word delete-char-or-list expand-or-complete expand-or-complete-prefix list-choices menu-complete menu-expand-or-complete reverse-menu-complete
	do
		zle -C $_i_line .$_i_line _main_complete
	done
	zle -la menu-select && zle -C menu-select .menu-select _main_complete
	bindkey '^i' | IFS=$' \t' read -A _i_line
	if [[ ${_i_line[2]} = expand-or-complete ]] && zstyle -a ':completion:' completer _i_line && (( ${_i_line[(i)_expand]} <= ${#_i_line} ))
	then
		bindkey '^i' complete-word
	fi
	unfunction compinit compaudit
	autoload -RUz compinit compaudit
	return 0
}
compinstall () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
getent () {
	if [[ $1 = hosts ]]
	then
		sed 's/#.*//' /etc/$1 | grep -w $2
	elif [[ $2 = <-> ]]
	then
		grep ":$2:[^:]*$" /etc/$1
	else
		grep "^$2:" /etc/$1
	fi
}
handle_completion_insecurities () {
	local -aU insecure_dirs
	insecure_dirs=(${(f@):-"$(compaudit 2>/dev/null)"}) 
	[[ -z "${insecure_dirs}" ]] && return
	print "[oh-my-zsh] Insecure completion-dependent directories detected:"
	ls -ld "${(@)insecure_dirs}"
	cat <<EOD

[oh-my-zsh] For safety, we will not load completions from these directories until
[oh-my-zsh] you fix their permissions and ownership and restart zsh.
[oh-my-zsh] See the above list for directories with group or other writability.

[oh-my-zsh] To fix your permissions you can do so by disabling
[oh-my-zsh] the write permission of "group" and "others" and making sure that the
[oh-my-zsh] owner of these directories is either root or your current user.
[oh-my-zsh] The following command may help:
[oh-my-zsh]     compaudit | xargs chmod g-w,o-w

[oh-my-zsh] If the above didn't help or you want to skip the verification of
[oh-my-zsh] insecure directories you can set the variable ZSH_DISABLE_COMPFIX to
[oh-my-zsh] "true" before oh-my-zsh is sourced in your zshrc file.

EOD
}
is_plugin () {
	local base_dir=$1 
	local name=$2 
	builtin test -f $base_dir/plugins/$name/$name.plugin.zsh || builtin test -f $base_dir/plugins/$name/_$name
}
zrecompile () {
	# undefined
	builtin autoload -XU
}
# Shell Options
setopt nohashdirs
setopt login
# Aliases
alias -- run-help=man
alias -- which-command=whence
# Check for rg availability
if ! (unalias rg 2>/dev/null; command -v rg) >/dev/null 2>&1; then
  alias rg='/Users/07404.chingting.chiu/.local/share/claude/versions/2.1.59 --ripgrep'
fi
export PATH='/Users/07404.chingting.chiu/.local/bin:/Users/07404.chingting.chiu/.antigravity/antigravity/bin:/Users/07404.chingting.chiu/Library/Android/Sdk/tools:/Users/07404.chingting.chiu/Library/Android/Sdk/tools/bin:/Users/07404.chingting.chiu/Library/Android/Sdk/platform-tools:/Users/07404.chingting.chiu/homebrew/bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:/Applications/CyberArk EPM.app/Contents/MacOS:/Users/07404.chingting.chiu/flutter/bin:/Users/07404.chingting.chiu/.pub-cache/bin'
