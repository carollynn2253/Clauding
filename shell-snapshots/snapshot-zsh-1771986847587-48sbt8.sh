# Snapshot file
# Unset all aliases to avoid conflicts with functions
unalias -a 2>/dev/null || true
# Functions
.autocomplete.__init__.precmd () {
	[[ -v functions[.zinit-shade-off] ]] && .zinit-shade-off "${___mode:-load}"
	[[ -v functions[.zinit-tmp-subst-off] ]] && .zinit-tmp-subst-off "${___mode:-load}"
	() {
		emulate -L zsh
		setopt $_autocomplete__func_opts[@]
		add-zsh-hook -d precmd .autocomplete.__init__.precmd
		unfunction .autocomplete.__init__.precmd
		if builtin zstyle -L zle-hook types > /dev/null
		then
			local -P hook= 
			for hook in zle-{isearch-{exit,update},line-{pre-redraw,init,finish},history-line-set,keymap-select}
			do
				[[ -v widgets[$hook] && $widgets[$hook] == user:_zsh_highlight_widget_orig-s*-r<->-$hook ]] && builtin zle -N $hook azhw:$hook
			done
		fi
	}
	local -P mod= 
	for mod in compinit config widget key-binding recent-dirs async
	do
		mod=.autocomplete.$mod.precmd 
		if [[ -v functions[$mod] ]]
		then
			$mod
			unfunction $mod
		fi
	done
	true
}
.autocomplete.async.clear () {
	builtin zle -Rc
	unset _autocomplete__isearch
	.autocomplete.async.stop
	.autocomplete.async.reset-context
	return 0
}
.autocomplete.async.compadd () {
	local -A _opts_=() 
	local -a _Dopt_=() _dopt_=() 
	zparseopts -A _opts_ -E -- D:=_Dopt_ E: J: O: V: x: X: d:
	if [[ -v _opts_[-x] && $# == 2 ]]
	then
		.autocomplete.compadd "$@"
		return
	elif [[ $funcstack[(I)_describe] -gt 0 && -z $_Dopt_ ]]
	then
		_autocomplete__reserved_lines=0 
	fi
	local -P _displ_array_= _matches_array_= 
	local -Pi _ret_=1 _new_nmatches_=-1 _new_list_lines_=-1 
	local -Pi _avail_list_lines_=$((
      max( _autocomplete__max_lines - 1 - ${${_opts_[(i)-[Xx]]}:+1} - compstate[list_lines], 0 )
  )) 
	if [[ -n $_Dopt_ ]]
	then
		.autocomplete.compadd "$@"
		_ret_=$? 
		(( funcstack[(I)_describe] )) || return _ret_
		_displ_array_=$_opts_[-D] 
		(( ${${(PA)_displ_array_}[(I)*:*]} )) || return _ret_
		_matches_array_=$_opts_[-O] 
		(( _avail_list_lines_ -= _autocomplete__reserved_lines ))
		_new_nmatches_=${(PA)#_displ_array_} 
		_new_list_lines_=${#${(@u)${(PA)_displ_array_}[@]#*:}} 
		(( _autocomplete__reserved_lines += _new_list_lines_ ))
	else
		_autocomplete__reserved_lines=0 
		local -Pa _out_=() 
		_out_=("${(0)"$(
        .autocomplete.compadd "$@"
        print -rNC1 -- "$compstate[list_lines]" "$compstate[nmatches]"
    )"}") 
		_new_list_lines_=$(( max( 0, $_out_[1] - $compstate[list_lines] ) )) 
		_new_nmatches_=$((   max( 0, $_out_[2] - $compstate[nmatches]   ) )) 
	fi
	if (( _new_list_lines_ <= _avail_list_lines_ ))
	then
		if [[ -z $_Dopt_ ]]
		then
			.autocomplete.compadd "$@"
			_ret_=$? 
		fi
		return _ret_
	fi
	if [[ -z $_Dopt_ ]]
	then
		local -a _matches_=() 
		.autocomplete.compadd -O _matches_ "$@"
		_matches_array_=_matches_ 
		_new_nmatches_=$#_matches_[@] 
	fi
	local -a _groupname_=() 
	zparseopts -A _opts_ -D -E - k U d:=_dopt_ l=_dopt_ J:=_groupname_ V:=_groupname_
	set -- "$_groupname_[@]" "$@"
	[[ -z $_Dopt_ ]] && _displ_array_=$_dopt_[-1] 
	local -Pi _nmatches_per_line_=$(( 1.0 * _new_nmatches_ / _new_list_lines_ )) 
	if [[ _nmatches_per_line_ -lt 1 && -z $_Dopt_ ]]
	then
		if [[ -z $_displ_array_ ]]
		then
			local -a displ=(${(PA)_matches_array_}) 
			_dopt_=(-d displ) 
			_displ_array_=displ 
		fi
		_dopt_=(-l "$_dopt_[@]") 
		set -A $_displ_array_ ${(@r:COLUMNS-1:)${(PA)_displ_array_}[@]//$'\n'/\n}
		_nmatches_per_line_=1 
	fi
	local -Pi _fit_=$(( max( _avail_list_lines_, 0 ) * _nmatches_per_line_ )) 
	local -Pi _trim_=$(( max( 0, _new_nmatches_ - _fit_ ) )) 
	if (( _trim_ ))
	then
		[[ -n $_matches_array_ ]] && shift -p $(( min( _trim_, ${(PA)#_matches_array_} ) )) $_matches_array_
		[[ -n $_displ_array_ ]] && shift -p $(( min( _trim_, ${(PA)#_displ_array_} ) )) $_displ_array_
		typeset -gH _autocomplete__partial_list=$curtag 
		comptags () {
			return 1
		}
	fi
	if [[ -z $_Dopt_ ]]
	then
		_autocomplete.compadd_opts_len "$@"
		.autocomplete.compadd $_dopt_ "$@[1,?]" -a -- $_matches_array_
		_ret_=$? 
	fi
	return _ret_
} 2>>| $_autocomplete__log
.autocomplete.async.complete () {
	.autocomplete.zle-flags $LASTWIDGET
	(( KEYS_QUEUED_COUNT || PENDING )) && return
	region_highlight=() 
	[[ -v functions[_zsh_highlight] ]] && _zsh_highlight
	typeset -gH _autocomplete__highlight=($region_highlight[@]) 
	[[ -v functions[_zsh_autosuggest_highlight_apply] ]] && _zsh_autosuggest_highlight_apply
	[[ $LASTWIDGET == .autocomplete.async.complete.fd-widget ]] && return
	.autocomplete.async.stop
	if (( REGION_ACTIVE )) || [[ -v _autocomplete__isearch && $LASTWIDGET == *(incremental|isearch)* ]]
	then
		builtin zle -Rc
		return 0
	fi
	[[ $LASTWIDGET == (_complete_help|list-expand|(|.)(describe-key-briefly|what-cursor-position|where-is)) ]] && return
	[[ $_lastcomp[insert] == *unambiguous ]] && builtin zle .auto-suffix-retain
	.autocomplete.async.start
	return 0
}
.autocomplete.async.complete.fd-widget () {
	setopt promptsubst
	local +h PS4=$_autocomplete__ps4 
	.autocomplete.async.complete.fd-widget.inner "$@"
}
.autocomplete.async.complete.fd-widget.inner () {
	local -i fd=$1 
	{
		builtin zle -F $fd
		unset _autocomplete__async_complete_fd
		.autocomplete.zle-flags || return 0
		local -a reply=() 
		IFS=$'\0' read -rAu $fd
		shift -p reply
	} always {
		exec {fd}<&-
	}
	unset _autocomplete__mesg _autocomplete__comp_mesg
	setopt $_autocomplete__comp_opts[@]
	[[ -n $curcontext ]] && setopt $_autocomplete__ctxt_opts[@]
	if ! builtin zle ._list_choices -w "$reply[@]" 2>>| $_autocomplete__log
	then
		region_highlight=("$_autocomplete__highlight[@]") 
		[[ -v functions[_zsh_autosuggest_highlight_apply] ]] && _zsh_autosuggest_highlight_apply
		builtin zle -R
	else
		.autocomplete.async.stop
	fi
	return 0
} 2>>| $_autocomplete__log
.autocomplete.async.history-incremental-search () {
	if [[ $curcontext == $WIDGET* ]]
	then
		unset curcontext
	else
		typeset -gH curcontext=${WIDGET}::: 
	fi
	[[ -o sharehistory ]] && fc -RI
	.autocomplete.async.start
}
.autocomplete.async.isearch-exit () {
	.autocomplete.zle-flags $LASTWIDGET
	unset _autocomplete__isearch
}
.autocomplete.async.isearch-update () {
	typeset -gHi _autocomplete__isearch=1 
}
.autocomplete.async.list-choices.completion-widget () {
	unset _autocomplete__mesg _autocomplete__comp_mesg _autocomplete__words _autocomplete__current
	if [[ $1 != <->.<-> || $2 != <-> ]]
	then
		compstate[list]= 
		return
	fi
	.autocomplete.async.sufficient-input || return 2
	local -PF _seconds_=$1 
	local -Pi _list_lines_=$2 
	local -P _mesg_=$3 
	shift 3
	local +h -a comppostfuncs=(.autocomplete.async.list-choices.post "$comppostfuncs[@]") 
	if [[ -n $compstate[old_list] ]] && .autocomplete.async.same-state
	then
		compstate[old_list]=keep 
	elif [[ $_list_lines_ == 1 && -n $1 ]]
	then
		builtin compadd "$@"
	elif [[ $_list_lines_ == 1 && -n $_mesg_ ]]
	then
		builtin compadd -x "$_mesg_"
	else
		typeset -gHF _autocomplete__async_avg_duration=$((
        .1 * _seconds_ + .9 * _autocomplete__async_avg_duration
    )) 
		if [[ -n $curcontext ]]
		then
			_main_complete
		else
			local curcontext=list-choices::: 
			.autocomplete.async.list-choices.main-complete
		fi
	fi
	typeset -gH _autocomplete__mesg=$_mesg_ 
	typeset -gHa _autocomplete__comp_mesg=("$@") 
	typeset -gHa _autocomplete__words=("$words[@]") 
	typeset -gHi _autocomplete__current=$CURRENT 
	return 2
} 2>>| $_autocomplete__log
.autocomplete.async.list-choices.main-complete () {
	{
		local -i min_lines= 
		builtin zstyle -s ":autocomplete:${curcontext}:" list-lines min_lines || min_lines=16 
		min_lines=$(( min( LINES - ( 1 + BUFFERLINES ), min_lines ) )) 
		local -Pi lines_below_buffer=$(( LINES - ( _autocomplete__buffer_start_line + BUFFERLINES ) )) 
		local -i _autocomplete__max_lines=$(( max( min_lines, lines_below_buffer ) )) 
		local -i _autocomplete__reserved_lines=0 
		() {
			emulate -L zsh
			setopt $_autocomplete__func_opts[@]
			functions[compadd]=$functions[.autocomplete.async.compadd] 
		} "$@"
		_main_complete "$@"
	} always {
		unfunction compadd comptags 2> /dev/null
	}
}
.autocomplete.async.list-choices.post () {
	[[ -v _autocomplete__partial_list ]] && builtin compadd -J -last- -x '%F{0}%K{14}(MORE)%f%k'
	compstate[insert]= 
	unset MENUSELECT MENUMODE
}
.autocomplete.async.precmd () {
	local -PF delay= 
	builtin zstyle -s :autocomplete: min-delay delay
	(( delay += 0.1 ))
	typeset -gHF _autocomplete__async_avg_duration=$delay 
	builtin zle -N .autocomplete.async.pty.zle-widget
	builtin zle -C .autocomplete.async.pty.completion-widget list-choices .autocomplete.async.pty.completion-widget
	builtin zle -N .autocomplete.async.complete.fd-widget
	builtin zle -C ._list_choices list-choices .autocomplete.async.list-choices.completion-widget
	if [[ -v functions[_zsh_highlight_call_widget] ]]
	then
		_zsh_highlight_call_widget () {
			.autocomplete.zle-flags $WIDGET
			builtin zle "$@"
		}
	fi
	if [[ -v functions[_zsh_autosuggest_highlight_apply] ]]
	then
		local -P action= 
		for action in clear modify fetch accept partial_accept execute enable disable toggle
		do
			eval "_zsh_autosuggest_widget_$action() {
        .autocomplete.zle-flags \$WIDGET
        _zsh_autosuggest_$action \"\$@\"
      }"
		done
		_zsh_autosuggest_widget_suggest () {
			.autocomplete.zle-flags
			_zsh_autosuggest_suggest "$@"
		}
	fi
	.autocomplete.patch _message
	add-zle-hook-widget line-init .autocomplete.async.read-cursor-position
	add-zle-hook-widget line-init .autocomplete.async.reset-context
	add-zle-hook-widget line-init .autocomplete.async.complete
	add-zle-hook-widget line-pre-redraw .autocomplete.async.complete
	add-zle-hook-widget line-finish .autocomplete.async.clear
	add-zle-hook-widget isearch-update .autocomplete.async.isearch-update
	add-zle-hook-widget isearch-exit .autocomplete.async.isearch-exit
	add-zsh-hook zshexit .autocomplete.async.stop
}
.autocomplete.async.pty () {
	typeset -gH _autocomplete__lbuffer="$LBUFFER" _autocomplete__rbuffer="$RBUFFER" 
	builtin bindkey $'\t' .autocomplete.async.pty.zle-widget
	local __tmp__= 
	builtin vared __tmp__
} 2>>| $_autocomplete__log_pty
.autocomplete.async.pty.completion-widget () {
	.autocomplete.async.pty.completion-widget.inner "$@"
}
.autocomplete.async.pty.completion-widget.inner () {
	if ! .autocomplete.async.sufficient-input
	then
		typeset -gHi _autocomplete__list_lines=0 
		return
	fi
	if .autocomplete.async.same-state
	then
		typeset -gHi _autocomplete__list_lines=$_lastcomp[list_lines] 
		return
	fi
	unset _autocomplete__mesg _autocomplete__comp_mesg
	{
		local curcontext=${curcontext:-list-choices:::} 
		unset 'compstate[vared]'
		_message () {
			compadd () {
				typeset -gHa _autocomplete__comp_mesg=("$@") 
				builtin compadd "$@"
			}
			zformat () {
				builtin zformat "$@"
				typeset -gHa _autocomplete__comp_mesg=("$gopt[@]" -x "$format") 
			}
			.autocomplete._message "$@"
			unfunction zformat
			functions[compadd]="$functions[.autocomplete.compadd]" 
		}
		local +h -a comppostfuncs=(.autocomplete.async.pty.message) 
		_main_complete
	} always {
		typeset -gHi _autocomplete__list_lines=$compstate[list_lines] 
	}
} 2>>| $_autocomplete__log_pty
.autocomplete.async.pty.message () {
	typeset -gH _autocomplete__mesg=$mesg 
	return 0
}
.autocomplete.async.pty.no-op () {
	:
}
.autocomplete.async.pty.zle-widget () {
	.autocomplete.async.pty.zle-widget.inner "$@"
}
.autocomplete.async.pty.zle-widget.inner () {
	{
		print -n -- '\C-B'
		LBUFFER=$_autocomplete__lbuffer 
		RBUFFER=$_autocomplete__rbuffer 
		setopt $_autocomplete__comp_opts[@]
		[[ -n $curcontext ]] && setopt $_autocomplete__ctxt_opts[@]
		builtin zle .autocomplete.async.pty.completion-widget -w 2> /dev/null
	} always {
		print -rNC1 -- "$_autocomplete__list_lines" "$_autocomplete__mesg" "$_autocomplete__comp_mesg[@]" $'\C-C'
		builtin kill $sysparams[pid]
	}
} 2>>| $_autocomplete__log_pty
.autocomplete.async.read-cursor-position () {
	emulate -L zsh
	(( KEYS_QUEUED_COUNT || PENDING )) && return
	if [[ -v MC_SID || ! ( -v terminfo[u6] && -v terminfo[u7] ) ]]
	then
		local -i max_lines= 
		builtin zstyle -s ":autocomplete:${curcontext}:" list-lines max_lines || max_lines=16 
		typeset -gHi _autocomplete__buffer_start_line=$(( min( max( LINES - max_lines, 1 ), LINES ) )) 
		return 0
	fi
	local -Pa CPR=("${(s:%d:)$( echoti u6 )}") 
	local -Pi i=${${${(M)CPR[1]%'%i'}:+1}:-0} 
	CPR[1]=${CPR[1]%'%i'} 
	local REPLY= 
	local -P Y= 
	echoti u7
	read -rsk $#CPR[1]
	while [[ $REPLY != $CPR[2] ]]
	do
		read -rsk
		Y+=$REPLY 
	done
	Y="${Y%$CPR[2]}" 
	Y=${(M)Y%%<->} 
	while [[ $REPLY != $CPR[3] ]]
	do
		read -rsk
	done
	typeset -gHi _autocomplete__buffer_start_line=$(( min( max( Y - i, 1 ), LINES ) )) 
}
.autocomplete.async.reset-context () {
	local context
	builtin zstyle -s :autocomplete: default-context context
	typeset -gH curcontext=$context 
	return 0
}
.autocomplete.async.same-state () {
	[[ $_autocomplete__words == $words && $_autocomplete__current == $CURRENT ]]
}
.autocomplete.async.start () {
	local fd= 
	sysopen -r -o cloexec -u fd <(
    typeset -F SECONDS=0
    setopt promptsubst
    PS4=$_autocomplete__ps4
    .autocomplete.async.start.inner
  )
	builtin zle -Fw "$fd" .autocomplete.async.complete.fd-widget
	typeset -gH _autocomplete__async_complete_fd=$fd 
	command true
}
.autocomplete.async.start.inner () {
	{
		local -F min_delay= 
		builtin zstyle -s :autocomplete: min-delay min_delay || min_delay=0.05 
		zselect -t "$(( [#10] 100 * max( 0, min_delay - SECONDS ) ))"
		local -P hooks=(chpwd periodic precmd preexec zshaddhistory zshexit) 
		builtin unset ${^hooks}_functions &> /dev/null
		$hooks[@] () {
			:
		}
		local -P hook= 
		for hook in zle-{isearch-{exit,update},line-{pre-redraw,init,finish},history-line-set,keymap-select}
		do
			builtin zle -N $hook .autocomplete.async.pty.no-op
		done
		{
			local REPLY= 
			zpty AUTOCOMPLETE .autocomplete.async.pty
			local -Pi fd=$REPLY 
			zpty -w AUTOCOMPLETE $'\t'
			local header= 
			zpty -r AUTOCOMPLETE header $'*\C-B'
			local -a reply=() 
			local text= 
			zselect -rt "$((
          [#10] 100 * max( 0, 100 * _autocomplete__async_avg_duration - SECONDS )
      ))" "$fd" && zpty -r AUTOCOMPLETE text $'*\C-C'
		} always {
			zpty -d AUTOCOMPLETE
		}
	} always {
		print -rNC1 -- "$SECONDS" "${text%$'\0\C-C'}"
	}
} 2>>| $_autocomplete__log_async
.autocomplete.async.stop () {
	local fd=$_autocomplete__async_complete_fd 
	unset _autocomplete__async_complete_fd
	unset _autocomplete__mesg _autocomplete__comp_mesg _autocomplete__words _autocomplete__current
	if [[ $fd == <-> ]]
	then
		builtin zle -F $fd 2> /dev/null
		exec {fd}<&-
	fi
}
.autocomplete.async.sufficient-input () {
	[[ -n $curcontext ]] && return
	local min_input= 
	builtin zstyle -s :autocomplete:list-choices min-input min_input || min_input=0 
	local ignored= 
	builtin zstyle -s :autocomplete:list-choices ignored-input ignored
	if (( ${#words[@]} == 1 && ${#words[CURRENT]} < min_input )) || [[ -n $words[CURRENT] && $words[CURRENT] == $~ignored ]]
	then
		compstate[list]= 
		false
	else
		true
	fi
}
.autocomplete.compinit.precmd () {
	emulate -L zsh
	setopt $_autocomplete__func_opts[@]
	[[ -v CDPATH && -z $CDPATH ]] && unset CDPATH cdpath
	local -Pa omzdump=() 
	[[ -v ZSH_COMPDUMP && -r $ZSH_COMPDUMP ]] && omzdump=(${(f)"$( < $ZSH_COMPDUMP )"}) 
	typeset -gU FPATH fpath=(~zsh-autocomplete/functions/completion $fpath[@]) 
	typeset -gH _comp_dumpfile=${_comp_dumpfile:-${ZSH_COMPDUMP:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compdump}} 
	if [[ -v _comps && $_comps[-command-] != _autocomplete.command ]]
	then
		zf_rm -f $_comp_dumpfile
	else
		local -Pa comps=(~zsh-autocomplete/functions/completion/_autocomplete.*~*.zwc(N-.)) 
		if ! (( $#comps ))
		then
			print -u2 -- 'zsh-autocomplete: Failed to find completion functions. Aborting.'
			return 66
		fi
		local -P f= 
		for f in $comps[@]
		do
			if ! [[ -v functions[$f:t] && $f -ot $_comp_dumpfile ]]
			then
				zf_rm -f $_comp_dumpfile
				break
			fi
		done
	fi
	if ! [[ -v _comp_setup && -r $_comp_dumpfile ]]
	then
		unfunction compdef compinit 2> /dev/null
		bindkey () {
			:
		}
		{
			builtin autoload +X -Uz compinit
			compinit -d $_comp_dumpfile
		} always {
			unfunction bindkey
		}
		(( ${#omzdump[@]} > 0 )) && tee -a "$ZSH_COMPDUMP" &> /dev/null <<EOF
$omzdump[-2]
$omzdump[-1]
EOF
	fi
	compinit () {
		:
	}
	local -P args= 
	for args in "$_autocomplete__compdef[@]"
	do
		eval "compdef $args"
	done
	unset _autocomplete__compdef
	(
		local -a reply=() 
		local cache_dir= 
		if builtin zstyle -s ':completion:*' cache-path cache_dir
		then
			local -P src= bin= 
			for src in $cache_dir/*~**.zwc~**/.*(N-.)
			do
				bin=$src.zwc 
				if [[ ! -e $bin || $bin -ot $src ]]
				then
					zcompile -Uz $src
				fi
			done
		fi
	) &|
	.autocomplete.patch _main_complete
	_main_complete () {
		local -i _autocomplete__reserved_lines=0 
		local -Pi ret=1 
		unset _autocomplete__partial_list _autocomplete__unambiguous
		compstate[insert]=menu 
		compstate[last_prompt]=yes 
		compstate[list]='list force packed rows' 
		unset 'compstate[vared]'
		[[ -v functions[compadd] ]] || functions[compadd]=$functions[.autocomplete.compadd] 
		local +h -a comppostfuncs=(_autocomplete._main_complete.post "$comppostfuncs[@]") 
		.autocomplete._main_complete "$@"
	}
	.autocomplete.compadd () {
		if [[ $_completer == expand* ]]
		then
			[[ $@[-1] == space && $#space[@] -eq 1 ]] && space=(${(q+)${(Q)space}}) 
			builtin compadd -fW "${${${words[CURRENT]:#[~/]*}:+$PWD/}:-/}" "$@"
		else
			builtin compadd "$@"
		fi
	}
	_autocomplete._main_complete.post () {
		[[ $WIDGET != _complete_help ]] && unfunction compadd 2> /dev/null
		_autocomplete.unambiguous
		compstate[list_max]=0 
		MENUSCROLL=0 
	}
	.autocomplete.patch _expand
	_expand () {
		if _autocomplete.is_glob
		then
			compstate[pattern_insert]= 
			compstate[pattern_match]=\* 
			.autocomplete._expand "$@"
			return
		fi
		.autocomplete._expand "$@"
	}
	.autocomplete.patch _complete
	_complete () {
		local -i nmatches=$compstate[nmatches] 
		.autocomplete._complete "$@" || _autocomplete.ancestor_dirs "$@" || _autocomplete.recent_paths "$@"
		(( compstate[nmatches] > nmatches ))
	}
	.autocomplete.patch _approximate
	_approximate () {
		[[ -z $words[CURRENT] || -v compstate[quote] ]] && return 1
		[[ -o banghist && $words[CURRENT] == [$histchars]* ]] && return 1
		_autocomplete.is_glob && return 1
		local -Pi ret=1 
		{
			[[ -v functions[compadd] ]] && functions[.autocomplete.__tmp__]=$functions[compadd] 
			compadd () {
				local -P ppre="$argv[(I)-p]" 
				[[ ${argv[(I)-[a-zA-Z]#U[a-zA-Z]#]} -eq 0 && "${#:-$PREFIX$SUFFIX}" -le _comp_correct ]] && return
				if [[ "$PREFIX" = \~* && ( ppre -eq 0 || "$argv[ppre+1]" != \~* ) ]]
				then
					PREFIX="~(#a${_comp_correct})${PREFIX[2,-1]}" 
				else
					PREFIX="(#a${_comp_correct})$PREFIX" 
				fi
				builtin compadd "$@"
			}
			.autocomplete._approximate "$@"
			ret=$? 
			_lastdescr=(${_lastdescr[@]:#corrections}) 
		} always {
			[[ -v functions[compadd] ]] && unfunction compadd
			if [[ -v functions[.autocomplete.__tmp__] ]]
			then
				functions[compadd]=$functions[.autocomplete.__tmp__] 
				unfunction .autocomplete.__tmp__
			fi
		}
		return ret
	}
	.autocomplete.patch _wanted
	_wanted () {
		if [[ $funcstack == *_parameters* ]] && builtin zstyle -T ":completion:${curcontext}:parameters" verbose
		then
			local -a params=($@[(re)-,-1]) 
			shift -p $#params
			shift params
			_description "$@[1,3]"
			builtin compadd "$expl[@]" "$@[5,-1]" -D params -a params
			local -a displays=() 
			local sep= 
			builtin zstyle -s ":completion:${curcontext}:parameters" list-separator sep || sep=-- 
			local -Pi MBEGIN= MEND= 
			local -P MATCH= 
			zformat -a displays " $sep " "${(@)params[@]:/(#m)*/${MATCH}:${${(kv)${(P)MATCH}}[1,COLUMNS]}}"
			displays=("${(@)displays[@]//(#m)[^[:print:]]##/${(q+)MATCH}}") 
			displays=("${(@)displays[@]:/(#m)*/$MATCH[1,COLUMNS]}") 
			.autocomplete._wanted "$@" -d displays -a params
		else
			.autocomplete._wanted "$@"
		fi
	}
}
.autocomplete.complete-word.completion-widget () {
	# undefined
	builtin autoload -XUz /Users/07404.chingting.chiu/.oh-my-zsh/custom/plugins/zsh-autocomplete/functions/widget
}
.autocomplete.complete-word.post () {
	# undefined
	builtin autoload -XUz /Users/07404.chingting.chiu/.oh-my-zsh/custom/plugins/zsh-autocomplete/functions/widget
}
.autocomplete.config.precmd () {
	typeset -gH _comp_setup="$_comp_setup"';
      [[ $_comp_caller_options[globdots] == yes ]] && setopt globdots' 
	builtin zstyle -d ':completion:*:default' list-prompt
	unset LISTPROMPT
}
.autocomplete.down-line-or-select.zle-widget () {
	# undefined
	builtin autoload -XUz /Users/07404.chingting.chiu/.oh-my-zsh/custom/plugins/zsh-autocomplete/functions/widget
}
.autocomplete.history-search.completion-widget () {
	# undefined
	builtin autoload -XUz /Users/07404.chingting.chiu/.oh-my-zsh/custom/plugins/zsh-autocomplete/functions/widget
}
.autocomplete.history-search.zle-widget () {
	# undefined
	builtin autoload -XUz /Users/07404.chingting.chiu/.oh-my-zsh/custom/plugins/zsh-autocomplete/functions/widget
}
.autocomplete.key-binding.precmd () {
	emulate -L zsh
	setopt $_autocomplete__func_opts[@]
	local -a ignored=() 
	builtin zstyle -g ignored ':autocomplete:shift-tab:*' insert-unambiguous || builtin zstyle ':autocomplete:shift-tab:*' insert-unambiguous yes
	local tab_style= 
	if ! builtin zstyle -s :autocomplete:tab: widget-style tab_style
	then
		tab_style='complete-word' 
		builtin zstyle ':autocomplete:tab:*' widget-style $tab_style
	fi
	if builtin zstyle -t :autocomplete:tab: fzf-completion && [[ -v functions[fzf-completion] ]]
	then
		typeset -gH fzf_default_completion=$tab_style 
		functions[.autocomplete.fzf-completion]=$functions[fzf-completion] 
		fzf-completion () {
			zle () {
				builtin zle "$@" ${${(M)funcstack[2]:#.autocomplete.fzf-completion}:+-w}
			}
			{
				.autocomplete.fzf-completion "$@"
			} always {
				[[ -v functions[zle] ]] && unfunction zle
			}
		}
	else
		builtin bindkey -M emacs '\t' $tab_style
		builtin bindkey -M viins '\t' $tab_style
	fi
	local backtab_style= 
	if ! builtin zstyle -s :autocomplete:shift-tab: widget-style backtab_style
	then
		backtab_style=${tab_style:/menu-complete/reverse-menu-complete} 
		builtin zstyle ':autocomplete:shift-tab:*' widget-style $backtab_style
	fi
	builtin bindkey -M emacs $terminfo[kcbt] $backtab_style
	builtin bindkey -M viins $terminfo[kcbt] $backtab_style
	if [[ $tab_style == *menu-* ]]
	then
		builtin bindkey -M menuselect '\t' menu-complete
	else
		builtin bindkey -M menuselect '\t' accept-line
	fi
	if [[ $backtab_style == *menu-* ]]
	then
		builtin bindkey -M menuselect $terminfo[kcbt] reverse-menu-complete
	else
		builtin bindkey -M menuselect -s $terminfo[kcbt] "\t^_$terminfo[kcbt]"
	fi
}
.autocomplete.list-expand.completion-widget () {
	# undefined
	builtin autoload -XUz /Users/07404.chingting.chiu/.oh-my-zsh/custom/plugins/zsh-autocomplete/functions/widget
}
.autocomplete.patch () {
	# undefined
	builtin autoload -XUz /Users/07404.chingting.chiu/.oh-my-zsh/custom/plugins/zsh-autocomplete/functions
}
.autocomplete.recent-dirs.precmd () {
	if [[ -v precmd_functions && $precmd_functions[(I)_zshz_precmd] != 0 ]] && builtin zstyle -T ':autocomplete:' recent-dirs 'zsh-z'
	then
		_autocomplete.recent_directories () {
			reply=(${(f)"$( zshz --complete -l $1 2> /dev/null )"}) 
		}
	elif [[ -v chpwd_functions && $chpwd_functions[(I)__zoxide_hook] != 0 ]] && builtin zstyle -T ':autocomplete:' recent-dirs 'zoxide'
	then
		_autocomplete.recent_directories () {
			reply=(${(f)"$( zoxide query --list $1 2> /dev/null )"}) 
		}
	elif [[ -v chpwd_functions && $chpwd_functions[(I)_zlua_precmd] != 0 ]] && builtin zstyle -T ':autocomplete:' recent-dirs 'z.lua'
	then
		_autocomplete.recent_directories () {
			reply=(${${(f)"$( _zlua --complete $1 2> /dev/null )"}##<->[[:space:]]##}) 
		}
	elif [[ -v precmd_functions && $precmd_functions[(I)_z_precmd] != 0 ]] && builtin zstyle -T ':autocomplete:' recent-dirs 'z.sh'
	then
		_autocomplete.recent_directories () {
			reply=(${${(fOa)"$( _z -l $1 2>&1 )"}##(common:|<->)[[:space:]]##}) 
		}
	elif [[ -v chpwd_functions && $chpwd_functions[(I)autojump_chpwd] != 0 ]] && builtin zstyle -T ':autocomplete:' recent-dirs 'autojump'
	then
		_autocomplete.recent_directories () {
			reply=(${${(f)"$( autojump --complete $1 2> /dev/null )"}##${1}__<->__}) 
		}
	elif [[ -v preexec_functions && $preexec_functions[(I)_fasd_preexec] != 0 ]] && builtin zstyle -T ':autocomplete:' recent-dirs 'fasd'
	then
		_autocomplete.recent_directories () {
			reply=(${(f)"$( fasd -dlR $1 2> /dev/null )"}) 
		}
	elif builtin autoload -RUz chpwd_recent_filehandler && builtin zstyle -T ':autocomplete:' recent-dirs 'cdr'
	then
		setopt autopushd pushdignoredups
		if ! builtin zstyle -s :chpwd: recent-dirs-file _
		then
			local -P old=${ZDOTDIR:-$HOME}/.chpwd-recent-dirs 
			local -P new=${XDG_DATA_HOME:-$HOME/.local/share}/zsh/chpwd-recent-dirs 
			builtin zstyle ':chpwd:*' recent-dirs-file $new
			[[ -e $old && ! -e $new ]] && zf_mv "$old" "$new"
		fi
		builtin zstyle -s :chpwd: recent-dirs-max _ || builtin zstyle ':chpwd:*' recent-dirs-max 0
		if ! (( $#dirstack[@] ))
		then
			local -aU reply=() 
			chpwd_recent_filehandler
			dirstack=(${^reply[@]:#$PWD}(N-/)) 
		fi
		_autocomplete.recent_directories.save () {
			chpwd_recent_filehandler $PWD $dirstack[@]
		}
		add-zsh-hook chpwd _autocomplete.recent_directories.save
		_autocomplete.recent_directories () {
			reply=(${^dirstack[@]:#$PWD(|/[^/]#)}(N)) 
			local -P ancestor=$PWD:h 
			while [[ $ancestor != / ]]
			do
				reply=(${reply[@]:#$ancestor}) 
				ancestor=$ancestor:h 
			done
			local exact=$reply[(r)*/$PREFIX$SUFFIX] 
			[[ -n $exact ]] && reply=($exact ${reply[@]:#$exact}) 
			(( $#reply[@] ))
		}
	fi
	if [[ -v preexec_functions && $preexec_functions[(I)_fasd_preexec] != 0 ]] && builtin zstyle -T ':autocomplete:' recent-files 'fasd'
	then
		_autocomplete.recent_files () {
			reply=($( fasd -flR $1 2> /dev/null )) 
		}
	fi
}
.autocomplete.up-line-or-search.zle-widget () {
	# undefined
	builtin autoload -XUz /Users/07404.chingting.chiu/.oh-my-zsh/custom/plugins/zsh-autocomplete/functions/widget
}
.autocomplete.widget.c () {
	builtin zle -C "$1" "$2" .autocomplete.$3.completion-widget
}
.autocomplete.widget.precmd () {
	emulate -L zsh
	setopt $_autocomplete__func_opts[@]
	local -P tab_style= 
	for tab_style in complete-word menu-complete menu-select
	do
		.autocomplete.widget.c "$tab_style" "$tab_style" complete-word
	done
	.autocomplete.widget.c reverse-menu-complete reverse-menu-complete complete-word
	unfunction .autocomplete.widget.c .autocomplete.widget.z
}
.autocomplete.widget.z () {
	builtin zle -N "$1" .autocomplete.$2.zle-widget
}
.autocomplete.zle-flags () {
	# undefined
	builtin autoload -XUz /Users/07404.chingting.chiu/.oh-my-zsh/custom/plugins/zsh-autocomplete/functions
}
VCS_INFO_formats () {
	setopt localoptions noksharrays NO_shwordsplit
	local msg tmp
	local -i i
	local -A hook_com
	hook_com=(action "$1" action_orig "$1" branch "$2" branch_orig "$2" base "$3" base_orig "$3" staged "$4" staged_orig "$4" unstaged "$5" unstaged_orig "$5" revision "$6" revision_orig "$6" misc "$7" misc_orig "$7" vcs "${vcs}" vcs_orig "${vcs}") 
	hook_com[base-name]="${${hook_com[base]}:t}" 
	hook_com[base-name_orig]="${hook_com[base-name]}" 
	hook_com[subdir]="$(VCS_INFO_reposub ${hook_com[base]})" 
	hook_com[subdir_orig]="${hook_com[subdir]}" 
	: vcs_info-patch-9b9840f2-91e5-4471-af84-9e9a0dc68c1b
	for tmp in base base-name branch misc revision subdir
	do
		hook_com[$tmp]="${hook_com[$tmp]//\%/%%}" 
	done
	VCS_INFO_hook 'post-backend'
	if [[ -n ${hook_com[action]} ]]
	then
		zstyle -a ":vcs_info:${vcs}:${usercontext}:${rrn}" actionformats msgs
		(( ${#msgs} < 1 )) && msgs[1]=' (%s)-[%b|%a]%u%c-' 
	else
		zstyle -a ":vcs_info:${vcs}:${usercontext}:${rrn}" formats msgs
		(( ${#msgs} < 1 )) && msgs[1]=' (%s)-[%b]%u%c-' 
	fi
	if [[ -n ${hook_com[staged]} ]]
	then
		zstyle -s ":vcs_info:${vcs}:${usercontext}:${rrn}" stagedstr tmp
		[[ -z ${tmp} ]] && hook_com[staged]='S'  || hook_com[staged]=${tmp} 
	fi
	if [[ -n ${hook_com[unstaged]} ]]
	then
		zstyle -s ":vcs_info:${vcs}:${usercontext}:${rrn}" unstagedstr tmp
		[[ -z ${tmp} ]] && hook_com[unstaged]='U'  || hook_com[unstaged]=${tmp} 
	fi
	if [[ ${quiltmode} != 'standalone' ]] && VCS_INFO_hook "pre-addon-quilt"
	then
		local REPLY
		VCS_INFO_quilt addon
		hook_com[quilt]="${REPLY}" 
		unset REPLY
	elif [[ ${quiltmode} == 'standalone' ]]
	then
		hook_com[quilt]=${hook_com[misc]} 
	fi
	(( ${#msgs} > maxexports )) && msgs[$(( maxexports + 1 )),-1]=() 
	for i in {1..${#msgs}}
	do
		if VCS_INFO_hook "set-message" $(( $i - 1 )) "${msgs[$i]}"
		then
			zformat -f msg ${msgs[$i]} a:${hook_com[action]} b:${hook_com[branch]} c:${hook_com[staged]} i:${hook_com[revision]} m:${hook_com[misc]} r:${hook_com[base-name]} s:${hook_com[vcs]} u:${hook_com[unstaged]} Q:${hook_com[quilt]} R:${hook_com[base]} S:${hook_com[subdir]}
			msgs[$i]=${msg} 
		else
			msgs[$i]=${hook_com[message]} 
		fi
	done
	hook_com=() 
	backend_misc=() 
	return 0
}
__arguments () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
__git_prompt_git () {
	GIT_OPTIONAL_LOCKS=0 command git "$@"
}
add-zle-hook-widget () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
add-zsh-hook () {
	emulate -L zsh
	local -a hooktypes
	hooktypes=(chpwd precmd preexec periodic zshaddhistory zshexit zsh_directory_name) 
	local usage="Usage: add-zsh-hook hook function\nValid hooks are:\n  $hooktypes" 
	local opt
	local -a autoopts
	integer del list help
	while getopts "dDhLUzk" opt
	do
		case $opt in
			(d) del=1  ;;
			(D) del=2  ;;
			(h) help=1  ;;
			(L) list=1  ;;
			([Uzk]) autoopts+=(-$opt)  ;;
			(*) return 1 ;;
		esac
	done
	shift $(( OPTIND - 1 ))
	if (( list ))
	then
		typeset -mp "(${1:-${(@j:|:)hooktypes}})_functions"
		return $?
	elif (( help || $# != 2 || ${hooktypes[(I)$1]} == 0 ))
	then
		print -u$(( 2 - help )) $usage
		return $(( 1 - help ))
	fi
	local hook="${1}_functions" 
	local fn="$2" 
	if (( del ))
	then
		if (( ${(P)+hook} ))
		then
			if (( del == 2 ))
			then
				set -A $hook ${(P)hook:#${~fn}}
			else
				set -A $hook ${(P)hook:#$fn}
			fi
			if (( ! ${(P)#hook} ))
			then
				unset $hook
			fi
		fi
	else
		if (( ${(P)+hook} ))
		then
			if (( ${${(P)hook}[(I)$fn]} == 0 ))
			then
				typeset -ga $hook
				set -A $hook ${(P)hook} $fn
			fi
		else
			typeset -ga $hook
			set -A $hook $fn
		fi
		autoload $autoopts -- $fn
	fi
}
alias_value () {
	(( $+aliases[$1] )) && echo $aliases[$1]
}
azure_prompt_info () {
	return 1
}
bashcompinit () {
	# undefined
	builtin autoload -XUz
}
bracketed-paste-magic () {
	# undefined
	builtin autoload -XUz
}
build_prompt () {
	RETVAL=$? 
	prompt_status
	prompt_virtualenv
	prompt_aws
	prompt_terraform
	prompt_context
	prompt_dir
	prompt_git
	prompt_bzr
	prompt_hg
	prompt_end
}
bzr_prompt_info () {
	local bzr_branch
	bzr_branch=$(bzr nick 2>/dev/null)  || return
	if [[ -n "$bzr_branch" ]]
	then
		local bzr_dirty="" 
		if [[ -n $(bzr status 2>/dev/null) ]]
		then
			bzr_dirty=" %{$fg[red]%}*%{$reset_color%}" 
		fi
		printf "%s%s%s%s" "$ZSH_THEME_SCM_PROMPT_PREFIX" "bzr::${bzr_branch##*:}" "$bzr_dirty" "$ZSH_THEME_GIT_PROMPT_SUFFIX"
	fi
}
chruby_prompt_info () {
	return 1
}
clipcopy () {
	unfunction clipcopy clippaste
	detect-clipboard || true
	"$0" "$@"
}
clippaste () {
	unfunction clipcopy clippaste
	detect-clipboard || true
	"$0" "$@"
}
colors () {
	emulate -L zsh
	typeset -Ag color colour
	color=(00 none 01 bold 02 faint 22 normal 03 italic 23 no-italic 04 underline 24 no-underline 05 blink 25 no-blink 07 reverse 27 no-reverse 08 conceal 28 no-conceal 30 black 40 bg-black 31 red 41 bg-red 32 green 42 bg-green 33 yellow 43 bg-yellow 34 blue 44 bg-blue 35 magenta 45 bg-magenta 36 cyan 46 bg-cyan 37 white 47 bg-white 39 default 49 bg-default) 
	local k
	for k in ${(k)color}
	do
		color[${color[$k]}]=$k 
	done
	for k in ${color[(I)3?]}
	do
		color[fg-${color[$k]}]=$k 
	done
	for k in grey gray
	do
		color[$k]=${color[black]} 
		color[fg-$k]=${color[$k]} 
		color[bg-$k]=${color[bg-black]} 
	done
	colour=(${(kv)color}) 
	local lc=$'\e[' rc=m 
	typeset -Hg reset_color bold_color
	reset_color="$lc${color[none]}$rc" 
	bold_color="$lc${color[bold]}$rc" 
	typeset -AHg fg fg_bold fg_no_bold
	for k in ${(k)color[(I)fg-*]}
	do
		fg[${k#fg-}]="$lc${color[$k]}$rc" 
		fg_bold[${k#fg-}]="$lc${color[bold]};${color[$k]}$rc" 
		fg_no_bold[${k#fg-}]="$lc${color[normal]};${color[$k]}$rc" 
	done
	typeset -AHg bg bg_bold bg_no_bold
	for k in ${(k)color[(I)bg-*]}
	do
		bg[${k#bg-}]="$lc${color[$k]}$rc" 
		bg_bold[${k#bg-}]="$lc${color[bold]};${color[$k]}$rc" 
		bg_no_bold[${k#bg-}]="$lc${color[normal]};${color[$k]}$rc" 
	done
}
compaudit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
compdef () {
	typeset -gHa _autocomplete__compdef=($_autocomplete__compdef[@] "${(j: :)${(@q+)@}}") 
}
compdump () {
	# undefined
	builtin autoload -XUz
}
compgen () {
	local opts prefix suffix job OPTARG OPTIND ret=1 
	local -a name res results jids
	local -A shortopts
	emulate -L sh
	setopt kshglob noshglob braceexpand nokshautoload
	shortopts=(a alias b builtin c command d directory e export f file g group j job k keyword u user v variable) 
	while getopts "o:A:G:C:F:P:S:W:X:abcdefgjkuv" name
	do
		case $name in
			([abcdefgjkuv]) OPTARG="${shortopts[$name]}"  ;&
			(A) case $OPTARG in
					(alias) results+=("${(k)aliases[@]}")  ;;
					(arrayvar) results+=("${(k@)parameters[(R)array*]}")  ;;
					(binding) results+=("${(k)widgets[@]}")  ;;
					(builtin) results+=("${(k)builtins[@]}" "${(k)dis_builtins[@]}")  ;;
					(command) results+=("${(k)commands[@]}" "${(k)aliases[@]}" "${(k)builtins[@]}" "${(k)functions[@]}" "${(k)reswords[@]}")  ;;
					(directory) setopt bareglobqual
						results+=(${IPREFIX}${PREFIX}*${SUFFIX}${ISUFFIX}(N-/)) 
						setopt nobareglobqual ;;
					(disabled) results+=("${(k)dis_builtins[@]}")  ;;
					(enabled) results+=("${(k)builtins[@]}")  ;;
					(export) results+=("${(k)parameters[(R)*export*]}")  ;;
					(file) setopt bareglobqual
						results+=(${IPREFIX}${PREFIX}*${SUFFIX}${ISUFFIX}(N)) 
						setopt nobareglobqual ;;
					(function) results+=("${(k)functions[@]}")  ;;
					(group) emulate zsh
						_groups -U -O res
						emulate sh
						setopt kshglob noshglob braceexpand
						results+=("${res[@]}")  ;;
					(hostname) emulate zsh
						_hosts -U -O res
						emulate sh
						setopt kshglob noshglob braceexpand
						results+=("${res[@]}")  ;;
					(job) results+=("${savejobtexts[@]%% *}")  ;;
					(keyword) results+=("${(k)reswords[@]}")  ;;
					(running) jids=("${(@k)savejobstates[(R)running*]}") 
						for job in "${jids[@]}"
						do
							results+=(${savejobtexts[$job]%% *}) 
						done ;;
					(stopped) jids=("${(@k)savejobstates[(R)suspended*]}") 
						for job in "${jids[@]}"
						do
							results+=(${savejobtexts[$job]%% *}) 
						done ;;
					(setopt | shopt) results+=("${(k)options[@]}")  ;;
					(signal) results+=("SIG${^signals[@]}")  ;;
					(user) results+=("${(k)userdirs[@]}")  ;;
					(variable) results+=("${(k)parameters[@]}")  ;;
					(helptopic)  ;;
				esac ;;
			(F) COMPREPLY=() 
				local -a args
				args=("${words[0]}" "${@[-1]}" "${words[CURRENT-2]}") 
				() {
					typeset -h words
					$OPTARG "${args[@]}"
				}
				results+=("${COMPREPLY[@]}")  ;;
			(G) setopt nullglob
				results+=(${~OPTARG}) 
				unsetopt nullglob ;;
			(W) results+=(${(Q)~=OPTARG})  ;;
			(C) results+=($(eval $OPTARG))  ;;
			(P) prefix="$OPTARG"  ;;
			(S) suffix="$OPTARG"  ;;
			(X) if [[ ${OPTARG[0]} = '!' ]]
				then
					results=("${(M)results[@]:#${OPTARG#?}}") 
				else
					results=("${results[@]:#$OPTARG}") 
				fi ;;
		esac
	done
	print -l -r -- "$prefix${^results[@]}$suffix"
}
compinit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
compinstall () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
complete () {
	emulate -L zsh
	local args void cmd print remove
	args=("$@") 
	zparseopts -D -a void o: A: G: W: C: F: P: S: X: a b c d e f g j k u v p=print r=remove
	if [[ -n $print ]]
	then
		printf 'complete %2$s %1$s\n' "${(@kv)_comps[(R)_bash*]#* }"
	elif [[ -n $remove ]]
	then
		for cmd
		do
			unset "_comps[$cmd]"
		done
	else
		compdef _bash_complete\ ${(j. .)${(q)args[1,-1-$#]}} "$@"
	fi
}
conda_prompt_info () {
	return 1
}
d () {
	if [[ -n $1 ]]
	then
		dirs "$@"
	else
		dirs -v | head -n 10
	fi
}
default () {
	(( $+parameters[$1] )) && return 0
	typeset -g "$1"="$2" && return 3
}
detect-clipboard () {
	emulate -L zsh
	if [[ "${OSTYPE}" == darwin* ]] && (( ${+commands[pbcopy]} )) && (( ${+commands[pbpaste]} ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | pbcopy
		}
		clippaste () {
			pbpaste
		}
	elif [[ "${OSTYPE}" == (cygwin|msys)* ]]
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" > /dev/clipboard
		}
		clippaste () {
			cat /dev/clipboard
		}
	elif (( $+commands[clip.exe] )) && (( $+commands[powershell.exe] ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | clip.exe
		}
		clippaste () {
			powershell.exe -noprofile -command Get-Clipboard
		}
	elif [ -n "${WAYLAND_DISPLAY:-}" ] && (( ${+commands[wl-copy]} )) && (( ${+commands[wl-paste]} ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | wl-copy &> /dev/null &|
		}
		clippaste () {
			wl-paste --no-newline
		}
	elif [ -n "${DISPLAY:-}" ] && (( ${+commands[xsel]} ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | xsel --clipboard --input
		}
		clippaste () {
			xsel --clipboard --output
		}
	elif [ -n "${DISPLAY:-}" ] && (( ${+commands[xclip]} ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | xclip -selection clipboard -in &> /dev/null &|
		}
		clippaste () {
			xclip -out -selection clipboard
		}
	elif (( ${+commands[lemonade]} ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | lemonade copy
		}
		clippaste () {
			lemonade paste
		}
	elif (( ${+commands[doitclient]} ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | doitclient wclip
		}
		clippaste () {
			doitclient wclip -r
		}
	elif (( ${+commands[win32yank]} ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | win32yank -i
		}
		clippaste () {
			win32yank -o
		}
	elif [[ $OSTYPE == linux-android* ]] && (( $+commands[termux-clipboard-set] ))
	then
		clipcopy () {
			cat "${1:-/dev/stdin}" | termux-clipboard-set
		}
		clippaste () {
			termux-clipboard-get
		}
	elif [ -n "${TMUX:-}" ] && (( ${+commands[tmux]} ))
	then
		clipcopy () {
			tmux load-buffer -w "${1:--}"
		}
		clippaste () {
			tmux save-buffer -
		}
	else
		_retry_clipboard_detection_or_fail () {
			local clipcmd="${1}" 
			shift
			if detect-clipboard
			then
				"${clipcmd}" "$@"
			else
				print "${clipcmd}: Platform $OSTYPE not supported or xclip/xsel not installed" >&2
				return 1
			fi
		}
		clipcopy () {
			_retry_clipboard_detection_or_fail clipcopy "$@"
		}
		clippaste () {
			_retry_clipboard_detection_or_fail clippaste "$@"
		}
		return 1
	fi
}
diff () {
	command diff --color "$@"
}
down-line-or-beginning-search () {
	# undefined
	builtin autoload -XU
}
edit-command-line () {
	# undefined
	builtin autoload -XU
}
env_default () {
	[[ ${parameters[$1]} = *-export* ]] && return 0
	export "$1=$2" && return 3
}
gbda () {
	git branch --no-color --merged | command grep -vE "^([+*]|\s*($(git_main_branch)|$(git_develop_branch))\s*$)" | command xargs git branch --delete 2> /dev/null
}
gbds () {
	local default_branch=$(git_main_branch) 
	(( ! $? )) || default_branch=$(git_develop_branch) 
	git for-each-ref refs/heads/ "--format=%(refname:short)" | while read branch
	do
		local merge_base=$(git merge-base $default_branch $branch) 
		if [[ $(git cherry $default_branch $(git commit-tree $(git rev-parse $branch\^{tree}) -p $merge_base -m _)) = -* ]]
		then
			git branch -D $branch
		fi
	done
}
gccd () {
	setopt localoptions extendedglob
	local repo="${${@[(r)(ssh://*|git://*|ftp(s)#://*|http(s)#://*|*@*)(.git/#)#]}:-$_}" 
	command git clone --recurse-submodules "$@" || return
	[[ -d "$_" ]] && cd "$_" || cd "${${repo:t}%.git/#}"
}
gdnolock () {
	git diff "$@" ":(exclude)package-lock.json" ":(exclude)*.lock"
}
gdv () {
	git diff -w "$@" | view -
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
ggf () {
	local b
	[[ $# != 1 ]] && b="$(git_current_branch)" 
	git push --force origin "${b:-$1}"
}
ggfl () {
	local b
	[[ $# != 1 ]] && b="$(git_current_branch)" 
	git push --force-with-lease origin "${b:-$1}"
}
ggl () {
	if [[ $# != 0 ]] && [[ $# != 1 ]]
	then
		git pull origin "${*}"
	else
		local b
		[[ $# == 0 ]] && b="$(git_current_branch)" 
		git pull origin "${b:-$1}"
	fi
}
ggp () {
	if [[ $# != 0 ]] && [[ $# != 1 ]]
	then
		git push origin "${*}"
	else
		local b
		[[ $# == 0 ]] && b="$(git_current_branch)" 
		git push origin "${b:-$1}"
	fi
}
ggpnp () {
	if [[ $# == 0 ]]
	then
		ggl && ggp
	else
		ggl "${*}" && ggp "${*}"
	fi
}
ggu () {
	local b
	[[ $# != 1 ]] && b="$(git_current_branch)" 
	git pull --rebase origin "${b:-$1}"
}
git_commits_ahead () {
	if __git_prompt_git rev-parse --git-dir &> /dev/null
	then
		local commits="$(__git_prompt_git rev-list --count @{upstream}..HEAD 2>/dev/null)" 
		if [[ -n "$commits" && "$commits" != 0 ]]
		then
			echo "$ZSH_THEME_GIT_COMMITS_AHEAD_PREFIX$commits$ZSH_THEME_GIT_COMMITS_AHEAD_SUFFIX"
		fi
	fi
}
git_commits_behind () {
	if __git_prompt_git rev-parse --git-dir &> /dev/null
	then
		local commits="$(__git_prompt_git rev-list --count HEAD..@{upstream} 2>/dev/null)" 
		if [[ -n "$commits" && "$commits" != 0 ]]
		then
			echo "$ZSH_THEME_GIT_COMMITS_BEHIND_PREFIX$commits$ZSH_THEME_GIT_COMMITS_BEHIND_SUFFIX"
		fi
	fi
}
git_current_branch () {
	local ref
	ref=$(__git_prompt_git symbolic-ref --quiet HEAD 2> /dev/null) 
	local ret=$? 
	if [[ $ret != 0 ]]
	then
		[[ $ret == 128 ]] && return
		ref=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null)  || return
	fi
	echo ${ref#refs/heads/}
}
git_current_user_email () {
	__git_prompt_git config user.email 2> /dev/null
}
git_current_user_name () {
	__git_prompt_git config user.name 2> /dev/null
}
git_develop_branch () {
	command git rev-parse --git-dir &> /dev/null || return
	local branch
	for branch in dev devel develop development
	do
		if command git show-ref -q --verify refs/heads/$branch
		then
			echo $branch
			return 0
		fi
	done
	echo develop
	return 1
}
git_main_branch () {
	command git rev-parse --git-dir &> /dev/null || return
	local remote ref
	for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,mainline,default,stable,master}
	do
		if command git show-ref -q --verify $ref
		then
			echo ${ref:t}
			return 0
		fi
	done
	for remote in origin upstream
	do
		ref=$(command git rev-parse --abbrev-ref $remote/HEAD 2>/dev/null) 
		if [[ $ref == $remote/* ]]
		then
			echo ${ref#"$remote/"}
			return 0
		fi
	done
	echo master
	return 1
}
git_previous_branch () {
	local ref
	ref=$(__git_prompt_git rev-parse --quiet --symbolic-full-name @{-1} 2> /dev/null) 
	local ret=$? 
	if [[ $ret != 0 ]] || [[ -z $ref ]]
	then
		return
	fi
	echo ${ref#refs/heads/}
}
git_prompt_ahead () {
	if [[ -n "$(__git_prompt_git rev-list origin/$(git_current_branch)..HEAD 2> /dev/null)" ]]
	then
		echo "$ZSH_THEME_GIT_PROMPT_AHEAD"
	fi
}
git_prompt_behind () {
	if [[ -n "$(__git_prompt_git rev-list HEAD..origin/$(git_current_branch) 2> /dev/null)" ]]
	then
		echo "$ZSH_THEME_GIT_PROMPT_BEHIND"
	fi
}
git_prompt_info () {
	if [[ -n "${_OMZ_ASYNC_OUTPUT[_omz_git_prompt_info]}" ]]
	then
		echo -n "${_OMZ_ASYNC_OUTPUT[_omz_git_prompt_info]}"
	fi
}
git_prompt_long_sha () {
	local SHA
	SHA=$(__git_prompt_git rev-parse HEAD 2> /dev/null)  && echo "$ZSH_THEME_GIT_PROMPT_SHA_BEFORE$SHA$ZSH_THEME_GIT_PROMPT_SHA_AFTER"
}
git_prompt_remote () {
	if [[ -n "$(__git_prompt_git show-ref origin/$(git_current_branch) 2> /dev/null)" ]]
	then
		echo "$ZSH_THEME_GIT_PROMPT_REMOTE_EXISTS"
	else
		echo "$ZSH_THEME_GIT_PROMPT_REMOTE_MISSING"
	fi
}
git_prompt_short_sha () {
	local SHA
	SHA=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null)  && echo "$ZSH_THEME_GIT_PROMPT_SHA_BEFORE$SHA$ZSH_THEME_GIT_PROMPT_SHA_AFTER"
}
git_prompt_status () {
	if [[ -n "${_OMZ_ASYNC_OUTPUT[_omz_git_prompt_status]}" ]]
	then
		echo -n "${_OMZ_ASYNC_OUTPUT[_omz_git_prompt_status]}"
	fi
}
git_remote_status () {
	local remote ahead behind git_remote_status git_remote_status_detailed
	remote=${$(__git_prompt_git rev-parse --verify ${hook_com[branch]}@{upstream} --symbolic-full-name 2>/dev/null)/refs\/remotes\/} 
	if [[ -n ${remote} ]]
	then
		ahead=$(__git_prompt_git rev-list ${hook_com[branch]}@{upstream}..HEAD 2>/dev/null | wc -l) 
		behind=$(__git_prompt_git rev-list HEAD..${hook_com[branch]}@{upstream} 2>/dev/null | wc -l) 
		if [[ $ahead -eq 0 ]] && [[ $behind -eq 0 ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_EQUAL_REMOTE" 
		elif [[ $ahead -gt 0 ]] && [[ $behind -eq 0 ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE" 
			git_remote_status_detailed="$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE_COLOR$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE$((ahead))%{$reset_color%}" 
		elif [[ $behind -gt 0 ]] && [[ $ahead -eq 0 ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE" 
			git_remote_status_detailed="$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE_COLOR$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE$((behind))%{$reset_color%}" 
		elif [[ $ahead -gt 0 ]] && [[ $behind -gt 0 ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_DIVERGED_REMOTE" 
			git_remote_status_detailed="$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE_COLOR$ZSH_THEME_GIT_PROMPT_AHEAD_REMOTE$((ahead))%{$reset_color%}$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE_COLOR$ZSH_THEME_GIT_PROMPT_BEHIND_REMOTE$((behind))%{$reset_color%}" 
		fi
		if [[ -n $ZSH_THEME_GIT_PROMPT_REMOTE_STATUS_DETAILED ]]
		then
			git_remote_status="$ZSH_THEME_GIT_PROMPT_REMOTE_STATUS_PREFIX${remote:gs/%/%%}$git_remote_status_detailed$ZSH_THEME_GIT_PROMPT_REMOTE_STATUS_SUFFIX" 
		fi
		echo $git_remote_status
	fi
}
git_repo_name () {
	local repo_path
	if repo_path="$(__git_prompt_git rev-parse --show-toplevel 2>/dev/null)"  && [[ -n "$repo_path" ]]
	then
		echo ${repo_path:t}
	fi
}
git_toplevel () {
	local repo_root=$(git rev-parse --show-toplevel) 
	if [[ $repo_root = '' ]]
	then
		repo_root=$(git rev-parse --git-dir) 
		if [[ $repo_root = '.' ]]
		then
			repo_root=$PWD 
		fi
	fi
	echo -n $repo_root
}
grename () {
	if [[ -z "$1" || -z "$2" ]]
	then
		echo "Usage: $0 old_branch new_branch"
		return 1
	fi
	git branch -m "$1" "$2"
	if git push origin :"$1"
	then
		git push --set-upstream origin "$2"
	fi
}
gunwipall () {
	local _commit=$(git log --grep='--wip--' --invert-grep --max-count=1 --format=format:%H) 
	if [[ "$_commit" != "$(git rev-parse HEAD)" ]]
	then
		git reset $_commit || return 1
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
hg_prompt_info () {
	return 1
}
is-at-least () {
	emulate -L zsh
	local IFS=".-" min_cnt=0 ver_cnt=0 part min_ver version order 
	min_ver=(${=1}) 
	version=(${=2:-$ZSH_VERSION} 0) 
	while (( $min_cnt <= ${#min_ver} ))
	do
		while [[ "$part" != <-> ]]
		do
			(( ++ver_cnt > ${#version} )) && return 0
			if [[ ${version[ver_cnt]} = *[0-9][^0-9]* ]]
			then
				order=(${version[ver_cnt]} ${min_ver[ver_cnt]}) 
				if [[ ${version[ver_cnt]} = <->* ]]
				then
					[[ $order != ${${(On)order}} ]] && return 1
				else
					[[ $order != ${${(O)order}} ]] && return 1
				fi
				[[ $order[1] != $order[2] ]] && return 0
			fi
			part=${version[ver_cnt]##*[^0-9]} 
		done
		while true
		do
			(( ++min_cnt > ${#min_ver} )) && return 0
			[[ ${min_ver[min_cnt]} = <-> ]] && break
		done
		(( part > min_ver[min_cnt] )) && return 0
		(( part < min_ver[min_cnt] )) && return 1
		part='' 
	done
}
is_plugin () {
	local base_dir=$1 
	local name=$2 
	builtin test -f $base_dir/plugins/$name/$name.plugin.zsh || builtin test -f $base_dir/plugins/$name/_$name
}
is_theme () {
	local base_dir=$1 
	local name=$2 
	builtin test -f $base_dir/$name.zsh-theme
}
jenv_prompt_info () {
	return 1
}
mkcd () {
	mkdir -p $@ && cd ${@:$#}
}
nvm_prompt_info () {
	which nvm &> /dev/null || return
	local nvm_prompt=${$(nvm current)#v} 
	echo "${ZSH_THEME_NVM_PROMPT_PREFIX}${nvm_prompt:gs/%/%%}${ZSH_THEME_NVM_PROMPT_SUFFIX}"
}
omz () {
	setopt localoptions noksharrays
	[[ $# -gt 0 ]] || {
		_omz::help
		return 1
	}
	local command="$1" 
	shift
	(( ${+functions[_omz::$command]} )) || {
		_omz::help
		return 1
	}
	_omz::$command "$@"
}
omz_diagnostic_dump () {
	emulate -L zsh
	builtin echo "Generating diagnostic dump; please be patient..."
	local thisfcn=omz_diagnostic_dump 
	local -A opts
	local opt_verbose opt_noverbose opt_outfile
	local timestamp=$(date +%Y%m%d-%H%M%S) 
	local outfile=omz_diagdump_$timestamp.txt 
	builtin zparseopts -A opts -D -- "v+=opt_verbose" "V+=opt_noverbose"
	local verbose n_verbose=${#opt_verbose} n_noverbose=${#opt_noverbose} 
	(( verbose = 1 + n_verbose - n_noverbose ))
	if [[ ${#*} > 0 ]]
	then
		opt_outfile=$1 
	fi
	if [[ ${#*} > 1 ]]
	then
		builtin echo "$thisfcn: error: too many arguments" >&2
		return 1
	fi
	if [[ -n "$opt_outfile" ]]
	then
		outfile="$opt_outfile" 
	fi
	_omz_diag_dump_one_big_text &> "$outfile"
	if [[ $? != 0 ]]
	then
		builtin echo "$thisfcn: error while creating diagnostic dump; see $outfile for details"
	fi
	builtin echo
	builtin echo Diagnostic dump file created at: "$outfile"
	builtin echo
	builtin echo To share this with OMZ developers, post it as a gist on GitHub
	builtin echo at "https://gist.github.com" and share the link to the gist.
	builtin echo
	builtin echo "WARNING: This dump file contains all your zsh and omz configuration files,"
	builtin echo "so don't share it publicly if there's sensitive information in them."
	builtin echo
}
omz_history () {
	local clear list stamp REPLY
	zparseopts -E -D c=clear l=list f=stamp E=stamp i=stamp t:=stamp
	if [[ -n "$clear" ]]
	then
		print -nu2 "This action will irreversibly delete your command history. Are you sure? [y/N] "
		builtin read -E
		[[ "$REPLY" = [yY] ]] || return 0
		print -nu2 >| "$HISTFILE"
		fc -p "$HISTFILE"
		print -u2 History file deleted.
	elif [[ $# -eq 0 ]]
	then
		builtin fc "${stamp[@]}" -l 1
	else
		builtin fc "${stamp[@]}" -l "$@"
	fi
}
omz_termsupport_cwd () {
	setopt localoptions unset
	local URL_HOST URL_PATH
	URL_HOST="$(omz_urlencode -P $HOST)"  || return 1
	URL_PATH="$(omz_urlencode -P $PWD)"  || return 1
	[[ -z "$KONSOLE_PROFILE_NAME" && -z "$KONSOLE_DBUS_SESSION" ]] || URL_HOST="" 
	printf "\e]7;file://%s%s\e\\" "${URL_HOST}" "${URL_PATH}"
}
omz_termsupport_precmd () {
	[[ "${DISABLE_AUTO_TITLE:-}" != true ]] || return 0
	title "$ZSH_THEME_TERM_TAB_TITLE_IDLE" "$ZSH_THEME_TERM_TITLE_IDLE"
}
omz_termsupport_preexec () {
	[[ "${DISABLE_AUTO_TITLE:-}" != true ]] || return 0
	emulate -L zsh
	setopt extended_glob
	local -a cmdargs
	cmdargs=("${(z)2}") 
	if [[ "${cmdargs[1]}" = fg ]]
	then
		local job_id jobspec="${cmdargs[2]#%}" 
		case "$jobspec" in
			(<->) job_id=${jobspec}  ;;
			("" | % | +) job_id=${(k)jobstates[(r)*:+:*]}  ;;
			(-) job_id=${(k)jobstates[(r)*:-:*]}  ;;
			([?]*) job_id=${(k)jobtexts[(r)*${(Q)jobspec}*]}  ;;
			(*) job_id=${(k)jobtexts[(r)${(Q)jobspec}*]}  ;;
		esac
		if [[ -n "${jobtexts[$job_id]}" ]]
		then
			1="${jobtexts[$job_id]}" 
			2="${jobtexts[$job_id]}" 
		fi
	fi
	local CMD="${1[(wr)^(*=*|sudo|ssh|mosh|rake|-*)]:gs/%/%%}" 
	local LINE="${2:gs/%/%%}" 
	title "$CMD" "%100>...>${LINE}%<<"
}
omz_urldecode () {
	emulate -L zsh
	local encoded_url=$1 
	local caller_encoding=$langinfo[CODESET] 
	local LC_ALL=C 
	export LC_ALL
	local tmp=${encoded_url:gs/+/ /} 
	tmp=${tmp:gs/\\/\\\\/} 
	tmp=${tmp:gs/%/\\x/} 
	local decoded="$(printf -- "$tmp")" 
	local -a safe_encodings
	safe_encodings=(UTF-8 utf8 US-ASCII) 
	if [[ -z ${safe_encodings[(r)$caller_encoding]} ]]
	then
		decoded=$(echo -E "$decoded" | iconv -f UTF-8 -t $caller_encoding) 
		if [[ $? != 0 ]]
		then
			echo "Error converting string from UTF-8 to $caller_encoding" >&2
			return 1
		fi
	fi
	echo -E "$decoded"
}
omz_urlencode () {
	emulate -L zsh
	setopt norematchpcre
	local -a opts
	zparseopts -D -E -a opts r m P
	local in_str="$@" 
	local url_str="" 
	local spaces_as_plus
	if [[ -z $opts[(r)-P] ]]
	then
		spaces_as_plus=1 
	fi
	local str="$in_str" 
	local encoding=$langinfo[CODESET] 
	local safe_encodings
	safe_encodings=(UTF-8 utf8 US-ASCII) 
	if [[ -z ${safe_encodings[(r)$encoding]} ]]
	then
		str=$(echo -E "$str" | iconv -f $encoding -t UTF-8) 
		if [[ $? != 0 ]]
		then
			echo "Error converting string from $encoding to UTF-8" >&2
			return 1
		fi
	fi
	local i byte ord LC_ALL=C 
	export LC_ALL
	local reserved=';/?:@&=+$,' 
	local mark='_.!~*''()-' 
	local dont_escape="[A-Za-z0-9" 
	if [[ -z $opts[(r)-r] ]]
	then
		dont_escape+=$reserved 
	fi
	if [[ -z $opts[(r)-m] ]]
	then
		dont_escape+=$mark 
	fi
	dont_escape+="]" 
	local url_str="" 
	for ((i = 1; i <= ${#str}; ++i )) do
		byte="$str[i]" 
		if [[ "$byte" =~ "$dont_escape" ]]
		then
			url_str+="$byte" 
		else
			if [[ "$byte" == " " && -n $spaces_as_plus ]]
			then
				url_str+="+" 
			elif [[ "$PREFIX" = *com.termux* ]]
			then
				url_str+="$byte" 
			else
				ord=$(( [##16] #byte )) 
				url_str+="%$ord" 
			fi
		fi
	done
	echo -E "$url_str"
}
open_command () {
	local open_cmd
	case "$OSTYPE" in
		(darwin*) open_cmd='open'  ;;
		(cygwin*) open_cmd='cygstart'  ;;
		(linux*) [[ "$(uname -r)" != *icrosoft* ]] && open_cmd='nohup xdg-open'  || {
				open_cmd='cmd.exe /c start ""' 
				[[ -e "$1" ]] && {
					1="$(wslpath -w "${1:a}")"  || return 1
				}
				[[ "$1" = (http|https)://* ]] && {
					1="$(echo "$1" | sed -E 's/([&|()<>^])/^\1/g')"  || return 1
				}
			} ;;
		(msys*) open_cmd='start ""'  ;;
		(*) echo "Platform $OSTYPE not supported"
			return 1 ;;
	esac
	if [[ -n "$BROWSER" && "$1" = (http|https)://* ]]
	then
		"$BROWSER" "$@"
		return
	fi
	${=open_cmd} "$@" &> /dev/null
}
parse_git_dirty () {
	local STATUS
	local -a FLAGS
	FLAGS=('--porcelain') 
	if [[ "$(__git_prompt_git config --get oh-my-zsh.hide-dirty)" != "1" ]]
	then
		if [[ "${DISABLE_UNTRACKED_FILES_DIRTY:-}" == "true" ]]
		then
			FLAGS+='--untracked-files=no' 
		fi
		case "${GIT_STATUS_IGNORE_SUBMODULES:-}" in
			(git)  ;;
			(*) FLAGS+="--ignore-submodules=${GIT_STATUS_IGNORE_SUBMODULES:-dirty}"  ;;
		esac
		STATUS=$(__git_prompt_git status ${FLAGS} 2> /dev/null | tail -n 1) 
	fi
	if [[ -n $STATUS ]]
	then
		echo "$ZSH_THEME_GIT_PROMPT_DIRTY"
	else
		echo "$ZSH_THEME_GIT_PROMPT_CLEAN"
	fi
}
prompt_aws () {
	[[ -z "$AWS_PROFILE" || "$SHOW_AWS_PROMPT" = false ]] && return
	case "$AWS_PROFILE" in
		(*-prod | *production*) prompt_segment "$AGNOSTER_AWS_PROD_BG" "$AGNOSTER_AWS_PROD_FG" "AWS: ${AWS_PROFILE:gs/%/%%}" ;;
		(*) prompt_segment "$AGNOSTER_AWS_BG" "$AGNOSTER_AWS_FG" "AWS: ${AWS_PROFILE:gs/%/%%}" ;;
	esac
}
prompt_bzr () {
	(( $+commands[bzr] )) || return
	local dir="$PWD" 
	while [[ ! -d "$dir/.bzr" ]]
	do
		[[ "$dir" = "/" ]] && return
		dir="${dir:h}" 
	done
	local bzr_status status_mod status_all revision
	if bzr_status=$(command bzr status 2>&1) 
	then
		status_mod=$(echo -n "$bzr_status" | head -n1 | grep "modified" | wc -m) 
		status_all=$(echo -n "$bzr_status" | head -n1 | wc -m) 
		revision=${$(command bzr log -r-1 --log-format line | cut -d: -f1):gs/%/%%} 
		if [[ $status_mod -gt 0 ]]
		then
			prompt_segment "$AGNOSTER_BZR_DIRTY_BG" "$AGNOSTER_BZR_DIRTY_FG" "bzr@$revision ✚"
		else
			if [[ $status_all -gt 0 ]]
			then
				prompt_segment "$AGNOSTER_BZR_DIRTY_BG" "$AGNOSTER_BZR_DIRTY_FG" "bzr@$revision"
			else
				prompt_segment "$AGNOSTER_BZR_CLEAN_BG" "$AGNOSTER_BZR_CLEAN_FG" "bzr@$revision"
			fi
		fi
	fi
}
prompt_context () {
	if [[ "$USERNAME" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]
	then
		prompt_segment "$AGNOSTER_CONTEXT_BG" "$AGNOSTER_CONTEXT_FG" "%(!.%{%F{$AGNOSTER_STATUS_ROOT_FG}%}.)%n@%m"
	fi
}
prompt_dir () {
	if [[ $AGNOSTER_GIT_INLINE == 'true' ]] && $(git rev-parse --is-inside-work-tree >/dev/null 2>&1)
	then
		prompt_segment "$AGNOSTER_DIR_BG" "$AGNOSTER_DIR_FG" "$(git_toplevel | sed "s:^$HOME:~:")"
	else
		prompt_segment "$AGNOSTER_DIR_BG" "$AGNOSTER_DIR_FG" '%~'
	fi
}
prompt_end () {
	if [[ -n $CURRENT_BG ]]
	then
		echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
	else
		echo -n "%{%k%}"
	fi
	echo -n "%{%f%}"
	CURRENT_BG='' 
}
prompt_git () {
	(( $+commands[git] )) || return
	if [[ "$(command git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]]
	then
		return
	fi
	local PL_BRANCH_CHAR
	() {
		local LC_ALL="" LC_CTYPE="en_US.UTF-8" 
		PL_BRANCH_CHAR=$'\ue0a0' 
	}
	local ref dirty mode repo_path
	if [[ "$(command git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]]
	then
		repo_path=$(command git rev-parse --git-dir 2>/dev/null) 
		dirty=$(parse_git_dirty) 
		ref=$(command git symbolic-ref HEAD 2> /dev/null)  || ref="◈ $(command git describe --exact-match --tags HEAD 2> /dev/null)"  || ref="➦ $(command git rev-parse --short HEAD 2> /dev/null)" 
		if [[ -n $dirty ]]
		then
			prompt_segment "$AGNOSTER_GIT_DIRTY_BG" "$AGNOSTER_GIT_DIRTY_FG"
		else
			prompt_segment "$AGNOSTER_GIT_CLEAN_BG" "$AGNOSTER_GIT_CLEAN_FG"
		fi
		if [[ $AGNOSTER_GIT_BRANCH_STATUS == 'true' ]]
		then
			local ahead behind
			ahead=$(command git log --oneline @{upstream}.. 2>/dev/null) 
			behind=$(command git log --oneline ..@{upstream} 2>/dev/null) 
			if [[ -n "$ahead" ]] && [[ -n "$behind" ]]
			then
				PL_BRANCH_CHAR=$'\u21c5' 
			elif [[ -n "$ahead" ]]
			then
				PL_BRANCH_CHAR=$'\u21b1' 
			elif [[ -n "$behind" ]]
			then
				PL_BRANCH_CHAR=$'\u21b0' 
			fi
		fi
		if [[ -e "${repo_path}/BISECT_LOG" ]]
		then
			mode=" <B>" 
		elif [[ -e "${repo_path}/MERGE_HEAD" ]]
		then
			mode=" >M<" 
		elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]
		then
			mode=" >R>" 
		fi
		setopt promptsubst
		autoload -Uz vcs_info
		zstyle ':vcs_info:*' enable git
		zstyle ':vcs_info:*' get-revision true
		zstyle ':vcs_info:*' check-for-changes true
		zstyle ':vcs_info:*' stagedstr '✚'
		zstyle ':vcs_info:*' unstagedstr '±'
		zstyle ':vcs_info:*' formats ' %u%c'
		zstyle ':vcs_info:*' actionformats ' %u%c'
		vcs_info
		echo -n "${${ref:gs/%/%%}/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"
		[[ $AGNOSTER_GIT_INLINE == 'true' ]] && prompt_git_relative
	fi
}
prompt_git_relative () {
	local repo_root=$(git_toplevel) 
	local path_in_repo=$(pwd | sed "s/^$(echo "$repo_root" | sed 's:/:\\/:g;s/\$/\\$/g')//;s:^/::;s:/$::;") 
	if [[ $path_in_repo != '' ]]
	then
		prompt_segment "$AGNOSTER_DIR_BG" "$AGNOSTER_DIR_FG" "$path_in_repo"
	fi
}
prompt_hg () {
	(( $+commands[hg] )) || return
	local rev st branch
	if $(command hg id >/dev/null 2>&1)
	then
		if $(command hg prompt >/dev/null 2>&1)
		then
			if [[ $(command hg prompt "{status|unknown}") = "?" ]]
			then
				prompt_segment "$AGNOSTER_HG_NEWFILE_BG" "$AGNOSTER_HG_NEWFILE_FG"
				st='±' 
			elif [[ -n $(command hg prompt "{status|modified}") ]]
			then
				prompt_segment "$AGNOSTER_HG_CHANGED_BG" "$AGNOSTER_HG_CHANGED_FG"
				st='±' 
			else
				prompt_segment "$AGNOSTER_HG_CLEAN_BG" "$AGNOSTER_HG_CLEAN_FG"
			fi
			echo -n ${$(command hg prompt "☿ {rev}@{branch}"):gs/%/%%} $st
		else
			st="" 
			rev=$(command hg id -n 2>/dev/null | sed 's/[^-0-9]//g') 
			branch=$(command hg id -b 2>/dev/null) 
			if command hg st | command grep -q "^\?"
			then
				prompt_segment "$AGNOSTER_HG_NEWFILE_BG" "$AGNOSTER_HG_NEWFILE_FG"
				st='±' 
			elif command hg st | command grep -q "^[MA]"
			then
				prompt_segment "$AGNOSTER_HG_CHANGED_BG" "$AGNOSTER_HG_CHANGED_FG"
				st='±' 
			else
				prompt_segment "$AGNOSTER_HG_CLEAN_BG" "$AGNOSTER_HG_CLEAN_FG"
			fi
			echo -n "☿ ${rev:gs/%/%%}@${branch:gs/%/%%}" $st
		fi
	fi
}
prompt_segment () {
	local bg fg
	[[ -n $1 ]] && bg="%K{$1}"  || bg="%k" 
	[[ -n $2 ]] && fg="%F{$2}"  || fg="%f" 
	if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]
	then
		echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
	else
		echo -n "%{$bg%}%{$fg%} "
	fi
	CURRENT_BG=$1 
	[[ -n $3 ]] && echo -n $3
}
prompt_status () {
	local -a symbols
	if [[ $AGNOSTER_STATUS_RETVAL_NUMERIC == 'true' ]]
	then
		[[ $RETVAL -ne 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_RETVAL_FG}%}$RETVAL" 
	else
		[[ $RETVAL -ne 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_RETVAL_FG}%}✘" 
	fi
	[[ $UID -eq 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_ROOT_FG}%}⚡" 
	[[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_JOB_FG}%}⚙" 
	[[ -n "$symbols" ]] && prompt_segment "$AGNOSTER_STATUS_BG" "$AGNOSTER_STATUS_FG" "$symbols"
}
prompt_terraform () {
	local terraform_info=$(tf_prompt_info) 
	[[ -z "$terraform_info" ]] && return
	prompt_segment magenta yellow "TF: $terraform_info"
}
prompt_virtualenv () {
	if [ -n "$CONDA_DEFAULT_ENV" ]
	then
		prompt_segment magenta $CURRENT_FG "🐍 $CONDA_DEFAULT_ENV"
	fi
	if [[ -n "$VIRTUAL_ENV" && -n "$VIRTUAL_ENV_DISABLE_PROMPT" ]]
	then
		prompt_segment "$AGNOSTER_VENV_BG" "$AGNOSTER_VENV_FG" "(${VIRTUAL_ENV:t:gs/%/%%})"
	fi
}
pyenv_prompt_info () {
	return 1
}
rbenv_prompt_info () {
	return 1
}
regexp-replace () {
	argv=("$1" "$2" "$3") 
	4=0 
	[[ -o re_match_pcre ]] && 4=1 
	emulate -L zsh
	local MATCH MBEGIN MEND
	local -a match mbegin mend
	if (( $4 ))
	then
		zmodload zsh/pcre || return 2
		pcre_compile -- "$2" && pcre_study || return 2
		4=0 6= 
		local ZPCRE_OP
		while pcre_match -b -n $4 -- "${(P)1}"
		do
			5=${(e)3} 
			argv+=(${(s: :)ZPCRE_OP} "$5") 
			4=$((argv[-2] + (argv[-3] == argv[-2]))) 
		done
		(($# > 6)) || return
		set +o multibyte
		5= 6=1 
		for 2 3 4 in "$@[7,-1]"
		do
			5+=${(P)1[$6,$2]}$4 
			6=$(($3 + 1)) 
		done
		5+=${(P)1[$6,-1]} 
	else
		4=${(P)1} 
		while [[ -n $4 ]]
		do
			if [[ $4 =~ $2 ]]
			then
				5+=${4[1,MBEGIN-1]}${(e)3} 
				if ((MEND < MBEGIN))
				then
					((MEND++))
					5+=${4[1]} 
				fi
				4=${4[MEND+1,-1]} 
				6=1 
			else
				break
			fi
		done
		[[ -n $6 ]] || return
		5+=$4 
	fi
	eval $1=\$5
}
ruby_prompt_info () {
	echo "$(rvm_prompt_info || rbenv_prompt_info || chruby_prompt_info)"
}
rvm_prompt_info () {
	[ -f $HOME/.rvm/bin/rvm-prompt ] || return 1
	local rvm_prompt
	rvm_prompt=$($HOME/.rvm/bin/rvm-prompt ${=ZSH_THEME_RVM_PROMPT_OPTIONS} 2>/dev/null) 
	[[ -z "${rvm_prompt}" ]] && return 1
	echo "${ZSH_THEME_RUBY_PROMPT_PREFIX}${rvm_prompt:gs/%/%%}${ZSH_THEME_RUBY_PROMPT_SUFFIX}"
}
spectrum_bls () {
	setopt localoptions nopromptsubst
	local ZSH_SPECTRUM_TEXT=${ZSH_SPECTRUM_TEXT:-Arma virumque cano Troiae qui primus ab oris} 
	for code in {000..255}
	do
		print -P -- "$code: ${BG[$code]}${ZSH_SPECTRUM_TEXT}%{$reset_color%}"
	done
}
spectrum_ls () {
	setopt localoptions nopromptsubst
	local ZSH_SPECTRUM_TEXT=${ZSH_SPECTRUM_TEXT:-Arma virumque cano Troiae qui primus ab oris} 
	for code in {000..255}
	do
		print -P -- "$code: ${FG[$code]}${ZSH_SPECTRUM_TEXT}%{$reset_color%}"
	done
}
svn_prompt_info () {
	return 1
}
take () {
	if [[ $1 =~ ^(https?|ftp).*\.(tar\.(gz|bz2|xz)|tgz)$ ]]
	then
		takeurl "$1"
	elif [[ $1 =~ ^(https?|ftp).*\.(zip)$ ]]
	then
		takezip "$1"
	elif [[ $1 =~ ^([A-Za-z0-9]\+@|https?|git|ssh|ftps?|rsync).*\.git/?$ ]]
	then
		takegit "$1"
	else
		takedir "$@"
	fi
}
takedir () {
	mkdir -p $@ && cd ${@:$#}
}
takegit () {
	git clone "$1"
	cd "$(basename ${1%%.git})"
}
takeurl () {
	local data thedir
	data="$(mktemp)" 
	curl -L "$1" > "$data"
	tar xf "$data"
	thedir="$(tar tf "$data" | head -n 1)" 
	rm "$data"
	cd "$thedir"
}
takezip () {
	local data thedir
	data="$(mktemp)" 
	curl -L "$1" > "$data"
	unzip "$data" -d "./"
	thedir="$(unzip -l "$data" | awk 'NR==4 {print $4}' | sed 's/\/.*//')" 
	rm "$data"
	cd "$thedir"
}
tf_prompt_info () {
	return 1
}
title () {
	setopt localoptions nopromptsubst
	[[ -n "${INSIDE_EMACS:-}" && "$INSIDE_EMACS" != vterm ]] && return
	: ${2=$1}
	case "$TERM" in
		(cygwin | xterm* | putty* | rxvt* | konsole* | ansi | mlterm* | alacritty* | st* | foot* | contour* | wezterm*) print -Pn "\e]2;${2:q}\a"
			print -Pn "\e]1;${1:q}\a" ;;
		(screen* | tmux*) print -Pn "\ek${1:q}\e\\" ;;
		(*) if [[ "$TERM_PROGRAM" == "iTerm.app" ]]
			then
				print -Pn "\e]2;${2:q}\a"
				print -Pn "\e]1;${1:q}\a"
			else
				if (( ${+terminfo[fsl]} && ${+terminfo[tsl]} ))
				then
					print -Pn "${terminfo[tsl]}$1${terminfo[fsl]}"
				fi
			fi ;;
	esac
}
try_alias_value () {
	alias_value "$1" || echo "$1"
}
uninstall_oh_my_zsh () {
	command env ZSH="$ZSH" sh "$ZSH/tools/uninstall.sh"
}
up-line-or-beginning-search () {
	# undefined
	builtin autoload -XU
}
upgrade_oh_my_zsh () {
	echo "${fg[yellow]}Note: \`$0\` is deprecated. Use \`omz update\` instead.$reset_color" >&2
	omz update
}
url-quote-magic () {
	# undefined
	builtin autoload -XUz
}
vi_mode_prompt_info () {
	return 1
}
virtualenv_prompt_info () {
	return 1
}
work_in_progress () {
	command git -c log.showSignature=false log -n 1 2> /dev/null | grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox,.venv,venv} -q -- "--wip--" && echo "WIP!!"
}
zle-line-finish () {
	echoti rmkx
}
zle-line-init () {
	echoti smkx
}
zmathfunc () {
	zsh_math_func_min () {
		emulate -L zsh
		local result=$1 
		shift
		local arg
		for arg
		do
			(( arg < result ))
			case $? in
				(0) (( result = arg )) ;;
				(1)  ;;
				(*) return $? ;;
			esac
		done
		(( result ))
		true
	}
	functions -M min 1 -1 zsh_math_func_min
	zsh_math_func_max () {
		emulate -L zsh
		local result=$1 
		shift
		local arg
		for arg
		do
			(( arg > result ))
			case $? in
				(0) (( result = arg )) ;;
				(1)  ;;
				(*) return $? ;;
			esac
		done
		(( result ))
		true
	}
	functions -M max 1 -1 zsh_math_func_max
	zsh_math_func_sum () {
		emulate -L zsh
		local sum
		local arg
		for arg
		do
			(( sum += arg ))
		done
		(( sum ))
		true
	}
	functions -M sum 0 -1 zsh_math_func_sum
}
zrecompile () {
	setopt localoptions extendedglob noshwordsplit noksharrays
	local opt check quiet zwc files re file pre ret map tmp mesg pats
	tmp=() 
	while getopts ":tqp" opt
	do
		case $opt in
			(t) check=yes  ;;
			(q) quiet=yes  ;;
			(p) pats=yes  ;;
			(*) if [[ -n $pats ]]
				then
					tmp=($tmp $OPTARG) 
				else
					print -u2 zrecompile: bad option: -$OPTARG
					return 1
				fi ;;
		esac
	done
	shift OPTIND-${#tmp}-1
	if [[ -n $check ]]
	then
		ret=1 
	else
		ret=0 
	fi
	if [[ -n $pats ]]
	then
		local end num
		while (( $# ))
		do
			end=$argv[(i)--] 
			if [[ end -le $# ]]
			then
				files=($argv[1,end-1]) 
				shift end
			else
				files=($argv) 
				argv=() 
			fi
			tmp=() 
			map=() 
			OPTIND=1 
			while getopts :MR opt $files
			do
				case $opt in
					([MR]) map=(-$opt)  ;;
					(*) tmp=($tmp $files[OPTIND])  ;;
				esac
			done
			shift OPTIND-1 files
			(( $#files )) || continue
			files=($files[1] ${files[2,-1]:#*(.zwc|~)}) 
			(( $#files )) || continue
			zwc=${files[1]%.zwc}.zwc 
			shift 1 files
			(( $#files )) || files=(${zwc%.zwc}) 
			if [[ -f $zwc ]]
			then
				num=$(zcompile -t $zwc | wc -l) 
				if [[ num-1 -ne $#files ]]
				then
					re=yes 
				else
					re= 
					for file in $files
					do
						if [[ $file -nt $zwc ]]
						then
							re=yes 
							break
						fi
					done
				fi
			else
				re=yes 
			fi
			if [[ -n $re ]]
			then
				if [[ -n $check ]]
				then
					[[ -z $quiet ]] && print $zwc needs re-compilation
					ret=0 
				else
					[[ -z $quiet ]] && print -n "re-compiling ${zwc}: "
					if [[ -z "$quiet" ]] && {
							[[ ! -f $zwc ]] || mv -f $zwc ${zwc}.old
						} && zcompile $map $tmp $zwc $files
					then
						print succeeded
					elif ! {
							{
								[[ ! -f $zwc ]] || mv -f $zwc ${zwc}.old
							} && zcompile $map $tmp $zwc $files 2> /dev/null
						}
					then
						[[ -z $quiet ]] && print "re-compiling ${zwc}: failed"
						ret=1 
					fi
				fi
			fi
		done
		return ret
	fi
	if (( $# ))
	then
		argv=(${^argv}/*.zwc(ND) ${^argv}.zwc(ND) ${(M)argv:#*.zwc}) 
	else
		argv=(${^fpath}/*.zwc(ND) ${^fpath}.zwc(ND) ${(M)fpath:#*.zwc}) 
	fi
	argv=(${^argv%.zwc}.zwc) 
	for zwc
	do
		files=(${(f)"$(zcompile -t $zwc)"}) 
		if [[ $files[1] = *\(mapped\)* ]]
		then
			map=-M 
			mesg='succeeded (old saved)' 
		else
			map=-R 
			mesg=succeeded 
		fi
		if [[ $zwc = */* ]]
		then
			pre=${zwc%/*}/ 
		else
			pre= 
		fi
		if [[ $files[1] != *$ZSH_VERSION ]]
		then
			re=yes 
		else
			re= 
		fi
		files=(${pre}${^files[2,-1]:#/*} ${(M)files[2,-1]:#/*}) 
		[[ -z $re ]] && for file in $files
		do
			if [[ $file -nt $zwc ]]
			then
				re=yes 
				break
			fi
		done
		if [[ -n $re ]]
		then
			if [[ -n $check ]]
			then
				[[ -z $quiet ]] && print $zwc needs re-compilation
				ret=0 
			else
				[[ -z $quiet ]] && print -n "re-compiling ${zwc}: "
				tmp=(${^files}(N)) 
				if [[ $#tmp -ne $#files ]]
				then
					[[ -z $quiet ]] && print 'failed (missing files)'
					ret=1 
				else
					if [[ -z "$quiet" ]] && mv -f $zwc ${zwc}.old && zcompile $map $zwc $files
					then
						print $mesg
					elif ! {
							mv -f $zwc ${zwc}.old && zcompile $map $zwc $files 2> /dev/null
						}
					then
						[[ -z $quiet ]] && print "re-compiling ${zwc}: failed"
						ret=1 
					fi
				fi
			fi
		fi
	done
	return ret
}
zsh_math_func_max () {
	emulate -L zsh
	local result=$1 
	shift
	local arg
	for arg
	do
		(( arg > result ))
		case $? in
			(0) (( result = arg )) ;;
			(1)  ;;
			(*) return $? ;;
		esac
	done
	(( result ))
	true
}
zsh_math_func_min () {
	emulate -L zsh
	local result=$1 
	shift
	local arg
	for arg
	do
		(( arg < result ))
		case $? in
			(0) (( result = arg )) ;;
			(1)  ;;
			(*) return $? ;;
		esac
	done
	(( result ))
	true
}
zsh_math_func_sum () {
	emulate -L zsh
	local sum
	local arg
	for arg
	do
		(( sum += arg ))
	done
	(( sum ))
	true
}
zsh_stats () {
	fc -l 1 | awk '{ CMD[$2]++; count++; } END { for (a in CMD) print CMD[a] " " CMD[a]*100/count "% " a }' | grep -v "./" | sort -nr | head -n 20 | column -c3 -s " " -t | nl
}
# Shell Options
setopt alwaystoend
setopt autocd
setopt autopushd
setopt completeinword
setopt extendedhistory
setopt noflowcontrol
setopt nohashdirs
setopt histexpiredupsfirst
setopt histignoredups
setopt histignorespace
setopt histverify
setopt interactivecomments
setopt nolistbeep
setopt login
setopt longlistjobs
setopt promptsubst
setopt pushdignoredups
setopt pushdminus
setopt sharehistory
# Aliases
alias -- -='cd -'
alias -- ...=../..
alias -- ....=../../..
alias -- .....=../../../..
alias -- ......=../../../../..
alias -- 1='cd -1'
alias -- 2='cd -2'
alias -- 3='cd -3'
alias -- 4='cd -4'
alias -- 5='cd -5'
alias -- 6='cd -6'
alias -- 7='cd -7'
alias -- 8='cd -8'
alias -- 9='cd -9'
alias -- _='sudo '
alias -- current_branch=$'\n    print -Pu2 "%F{yellow}[oh-my-zsh] \'%F{red}current_branch%F{yellow}\' is deprecated, using \'%F{green}git_current_branch%F{yellow}\' instead.%f"\n    git_current_branch'
alias -- egrep='grep -E'
alias -- fgrep='grep -F'
alias -- g=git
alias -- ga='git add'
alias -- gaa='git add --all'
alias -- gam='git am'
alias -- gama='git am --abort'
alias -- gamc='git am --continue'
alias -- gams='git am --skip'
alias -- gamscp='git am --show-current-patch'
alias -- gap='git apply'
alias -- gapa='git add --patch'
alias -- gapt='git apply --3way'
alias -- gau='git add --update'
alias -- gav='git add --verbose'
alias -- gb='git branch'
alias -- gbD='git branch --delete --force'
alias -- gba='git branch --all'
alias -- gbd='git branch --delete'
alias -- gbg='LANG=C git branch -vv | grep ": gone\]"'
alias -- gbgD='LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '\''{print $1}'\'' | xargs git branch -D'
alias -- gbgd='LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '\''{print $1}'\'' | xargs git branch -d'
alias -- gbl='git blame -w'
alias -- gbm='git branch --move'
alias -- gbnm='git branch --no-merged'
alias -- gbr='git branch --remote'
alias -- gbs='git bisect'
alias -- gbsb='git bisect bad'
alias -- gbsg='git bisect good'
alias -- gbsn='git bisect new'
alias -- gbso='git bisect old'
alias -- gbsr='git bisect reset'
alias -- gbss='git bisect start'
alias -- gc='git commit --verbose'
alias -- gc!='git commit --verbose --amend'
alias -- gcB='git checkout -B'
alias -- gca='git commit --verbose --all'
alias -- gca!='git commit --verbose --all --amend'
alias -- gcam='git commit --all --message'
alias -- gcan!='git commit --verbose --all --no-edit --amend'
alias -- gcann!='git commit --verbose --all --date=now --no-edit --amend'
alias -- gcans!='git commit --verbose --all --signoff --no-edit --amend'
alias -- gcas='git commit --all --signoff'
alias -- gcasm='git commit --all --signoff --message'
alias -- gcb='git checkout -b'
alias -- gcd='git checkout $(git_develop_branch)'
alias -- gcf='git config --list'
alias -- gcfu='git commit --fixup'
alias -- gcl='git clone --recurse-submodules'
alias -- gclean='git clean --interactive -d'
alias -- gclf='git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules'
alias -- gcm='git checkout $(git_main_branch)'
alias -- gcmsg='git commit --message'
alias -- gcn='git commit --verbose --no-edit'
alias -- gcn!='git commit --verbose --no-edit --amend'
alias -- gco='git checkout'
alias -- gcor='git checkout --recurse-submodules'
alias -- gcount='git shortlog --summary --numbered'
alias -- gcp='git cherry-pick'
alias -- gcpa='git cherry-pick --abort'
alias -- gcpc='git cherry-pick --continue'
alias -- gcs='git commit --gpg-sign'
alias -- gcsm='git commit --signoff --message'
alias -- gcss='git commit --gpg-sign --signoff'
alias -- gcssm='git commit --gpg-sign --signoff --message'
alias -- gd='git diff'
alias -- gdca='git diff --cached'
alias -- gdct='git describe --tags $(git rev-list --tags --max-count=1)'
alias -- gdcw='git diff --cached --word-diff'
alias -- gds='git diff --staged'
alias -- gdt='git diff-tree --no-commit-id --name-only -r'
alias -- gdup='git diff @{upstream}'
alias -- gdw='git diff --word-diff'
alias -- gf='git fetch'
alias -- gfa='git fetch --all --tags --prune --jobs=10'
alias -- gfg='git ls-files | grep'
alias -- gfo='git fetch origin'
alias -- gg='git gui citool'
alias -- gga='git gui citool --amend'
alias -- ggpull='git pull origin "$(git_current_branch)"'
alias -- ggpur=ggu
alias -- ggpush='git push origin "$(git_current_branch)"'
alias -- ggsup='git branch --set-upstream-to=origin/$(git_current_branch)'
alias -- ghh='git help'
alias -- gignore='git update-index --assume-unchanged'
alias -- gignored='git ls-files -v | grep "^[[:lower:]]"'
alias -- git-svn-dcommit-push='git svn dcommit && git push github $(git_main_branch):svntrunk'
alias -- gk='\gitk --all --branches &!'
alias -- gke='\gitk --all $(git log --walk-reflogs --pretty=%h) &!'
alias -- gl='git pull'
alias -- glg='git log --stat'
alias -- glgg='git log --graph'
alias -- glgga='git log --graph --decorate --all'
alias -- glgm='git log --graph --max-count=10'
alias -- glgp='git log --stat --patch'
alias -- glo='git log --oneline --decorate'
alias -- glod='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset"'
alias -- glods='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short'
alias -- glog='git log --oneline --decorate --graph'
alias -- gloga='git log --oneline --decorate --graph --all'
alias -- glol='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"'
alias -- glola='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all'
alias -- glols='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat'
alias -- glp=_git_log_prettily
alias -- gluc='git pull upstream $(git_current_branch)'
alias -- glum='git pull upstream $(git_main_branch)'
alias -- gm='git merge'
alias -- gma='git merge --abort'
alias -- gmc='git merge --continue'
alias -- gmff='git merge --ff-only'
alias -- gmom='git merge origin/$(git_main_branch)'
alias -- gms='git merge --squash'
alias -- gmtl='git mergetool --no-prompt'
alias -- gmtlvim='git mergetool --no-prompt --tool=vimdiff'
alias -- gmum='git merge upstream/$(git_main_branch)'
alias -- gp='git push'
alias -- gpd='git push --dry-run'
alias -- gpf='git push --force-with-lease --force-if-includes'
alias -- gpf!='git push --force'
alias -- gpoat='git push origin --all && git push origin --tags'
alias -- gpod='git push origin --delete'
alias -- gpr='git pull --rebase'
alias -- gpra='git pull --rebase --autostash'
alias -- gprav='git pull --rebase --autostash -v'
alias -- gpristine='git reset --hard && git clean --force -dfx'
alias -- gprom='git pull --rebase origin $(git_main_branch)'
alias -- gpromi='git pull --rebase=interactive origin $(git_main_branch)'
alias -- gprum='git pull --rebase upstream $(git_main_branch)'
alias -- gprumi='git pull --rebase=interactive upstream $(git_main_branch)'
alias -- gprv='git pull --rebase -v'
alias -- gpsup='git push --set-upstream origin $(git_current_branch)'
alias -- gpsupf='git push --set-upstream origin $(git_current_branch) --force-with-lease --force-if-includes'
alias -- gpu='git push upstream'
alias -- gpv='git push --verbose'
alias -- gr='git remote'
alias -- gra='git remote add'
alias -- grb='git rebase'
alias -- grba='git rebase --abort'
alias -- grbc='git rebase --continue'
alias -- grbd='git rebase $(git_develop_branch)'
alias -- grbi='git rebase --interactive'
alias -- grbm='git rebase $(git_main_branch)'
alias -- grbo='git rebase --onto'
alias -- grbom='git rebase origin/$(git_main_branch)'
alias -- grbs='git rebase --skip'
alias -- grbum='git rebase upstream/$(git_main_branch)'
alias -- grep='grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox,.venv,venv}'
alias -- grev='git revert'
alias -- greva='git revert --abort'
alias -- grevc='git revert --continue'
alias -- grf='git reflog'
alias -- grh='git reset'
alias -- grhh='git reset --hard'
alias -- grhk='git reset --keep'
alias -- grhs='git reset --soft'
alias -- grm='git rm'
alias -- grmc='git rm --cached'
alias -- grmv='git remote rename'
alias -- groh='git reset origin/$(git_current_branch) --hard'
alias -- grrm='git remote remove'
alias -- grs='git restore'
alias -- grset='git remote set-url'
alias -- grss='git restore --source'
alias -- grst='git restore --staged'
alias -- grt='cd "$(git rev-parse --show-toplevel || echo .)"'
alias -- gru='git reset --'
alias -- grup='git remote update'
alias -- grv='git remote --verbose'
alias -- gsb='git status --short --branch'
alias -- gsd='git svn dcommit'
alias -- gsh='git show'
alias -- gsi='git submodule init'
alias -- gsps='git show --pretty=short --show-signature'
alias -- gsr='git svn rebase'
alias -- gss='git status --short'
alias -- gst='git status'
alias -- gsta='git stash push'
alias -- gstaa='git stash apply'
alias -- gstall='git stash --all'
alias -- gstc='git stash clear'
alias -- gstd='git stash drop'
alias -- gstl='git stash list'
alias -- gstp='git stash pop'
alias -- gsts='git stash show --patch'
alias -- gstu='gsta --include-untracked'
alias -- gsu='git submodule update'
alias -- gsw='git switch'
alias -- gswc='git switch --create'
alias -- gswd='git switch $(git_develop_branch)'
alias -- gswm='git switch $(git_main_branch)'
alias -- gta='git tag --annotate'
alias -- gtl='gtl(){ git tag --sort=-v:refname -n --list "${1}*" }; noglob gtl'
alias -- gts='git tag --sign'
alias -- gtv='git tag | sort -V'
alias -- gunignore='git update-index --no-assume-unchanged'
alias -- gunwip='git rev-list --max-count=1 --format="%s" HEAD | grep -q "\--wip--" && git reset HEAD~1'
alias -- gwch='git log --patch --abbrev-commit --pretty=medium --raw'
alias -- gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"'
alias -- gwipe='git reset --hard && git clean --force -df'
alias -- gwt='git worktree'
alias -- gwta='git worktree add'
alias -- gwtls='git worktree list'
alias -- gwtmv='git worktree move'
alias -- gwtrm='git worktree remove'
alias -- history=omz_history
alias -- l='ls -lah'
alias -- la='ls -lAh'
alias -- ll='ls -lh'
alias -- ls='ls -G'
alias -- lsa='ls -lah'
alias -- md='mkdir -p'
alias -- rd=rmdir
alias -- run-help=man
alias -- which-command=whence
# Check for rg availability
if ! (unalias rg 2>/dev/null; command -v rg) >/dev/null 2>&1; then
  alias rg='/Users/07404.chingting.chiu/.local/share/claude/versions/2.1.53 --ripgrep'
fi
export PATH='/Users/07404.chingting.chiu/.local/bin:/Users/07404.chingting.chiu/.antigravity/antigravity/bin:/Users/07404.chingting.chiu/Library/Android/Sdk/tools:/Users/07404.chingting.chiu/Library/Android/Sdk/tools/bin:/Users/07404.chingting.chiu/Library/Android/Sdk/platform-tools:/Users/07404.chingting.chiu/homebrew/bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:/Applications/CyberArk EPM.app/Contents/MacOS:/Users/07404.chingting.chiu/flutter/bin:/Users/07404.chingting.chiu/.pub-cache/bin'
