#!/usr/bin/env bash
# vi:syntax=sh

APP_NAME="${APP_NAME:-Hexagone Multiplayer}"
PROJECT_PATH="${PROJECT_PATH:-$PWD/hexagon-godot-source}"

######################################## HELP

: <<DOCUMENTATION_help
Shows a short and helpful help text
DOCUMENTATION_help
help() {
	if [ "$1" == "help" ]; then
		_show_docs "${FUNCNAME[0]}"
	fi
	echo ""
	echo "$APP_NAME Helper"
	echo "please use one of the following commands:"
	for i in ${!funcs[@]}; do
		command=${funcs[i]}
		echo "  - ${command//_/:}"
	done
	echo "You can get more info about commands by writing $0 <command> help"
	echo ""
}

DOC_REQUEST=70

_show_docs() {
	doc_name="DOCUMENTATION_${1}"
	command="${1//_/:}"
	do_exit="$3"
	echo
	echo "Usage: $0 ${command}${2}"
	echo
	sed --silent -e "/${doc_name}$/,/^${doc_name}$/p" "$0" | sed -e "/${doc_name}$/d"
	echo
	if [ -z "$3" ]; then
		exit $DOC_REQUEST
	fi
}

_show_available_targets() {
	local origin="${FUNCNAME[1]}"
	local prefix="${1:-$origin}_*"
	for i in ${!funcs[@]}; do
		command=${funcs[i]}
		if [[ $command == $prefix ]]; then
			command=${funcs[i]}
			echo "  - ${command//_/:}"
		fi
	done
}

# Returns the extension with preceeding dot. If there are multiple extensions, only the last is returned
_get_extension() {
	local filename="$1"
	case $filename in
	.*.*) extension=${filename##*.} ;;
	.*) extension="" ;;
	*.*) extension=${filename##*.} ;;
	*) extension="" ;;
	esac
	if [ -z "$extension" ]; then
		echo -e ""
	else
		echo -e ".$extension"
	fi
}

# Returns a suffix with preceeding dot. If there are multiple suffixes, only the last is returned
_get_suffix() {
	local filename="$1"
	case $filename in
	-*-*) suffix=${filename##*-} ;;
	-*) suffix="" ;;
	*-*) suffix=${filename##*-} ;;
	*) suffix="" ;;
	esac
	if [ -z "$suffix" ]; then
		echo -e ""
	else
		ext=$(_get_extension "$suffix")
		suffix=$(basename "${suffix}" "${ext}")
		echo -e "-${suffix}"
	fi
}

_verify_awk() {
	AWK_MODE="mawk"
	if command -v awk &>/dev/null; then
		if awk --version 2>&1 | grep -q "GNU Awk"; then
			AWK_MODE="gawk"
		fi
	else
		echo "awk is a necessary dependency to run this function"
	fi
}

######################################## FIND GODOT

# Attempts to find Godot wherever it may be. If Godot is specified in the
# environment as `GODOT_4_PATH`, then this function does nothing.
_find_godot() {

	if [ -n "$GODOT_4_PATH" ]; then
		return 0
	fi

	if command -v godot &>/dev/null; then
		GODOT_4_PATH="godot"
		return 1
	fi

	local possible_locations=(
		"/usr/bin/godot"
		"/usr/local/bin/godot"
		"$HOME/bin/godot"
		"$HOME/.bin/godot"
		"$HOME/.local/share/hourglass/versions/4.1/godot"
	)

	for location in "${possible_locations[@]}"; do
		if [ -x "$location" ]; then
			GODOT_4_PATH="$location"
			return 0
		fi
	done

	if [ ! -n "$godot_path" ]; then
		if command -v flatpak &>/dev/null; then
			flatpak_name="org.godotengine.Godot"
			if flatpak list | grep -q "$app_name"; then
				GODOT_4_PATH="flatpak run --branch=stable --arch=x86_64 --command=godot --file-forwarding org.godotengine.Godot"
				return 0
			fi
		fi
	fi

	if [ ! -n "$GODOT_4_PATH" ]; then
		echo "could not find godot"
		exit 1
	fi
}

######################################## RUN INSTANCES

# Used to kill multiple instances at a time
_graceful_shutdown() {
	((${#pids[@]})) && kill "${pids[@]}"
}

# used to make sure each terminal uses a different color
_terminal_color_index=0

_run_godot() {

	_find_godot

	LOGS_PATH={LOGS_PATH:"$PWD/logs"}
	mkdir -p $LOGS_PATH

	pids=()
	colors=("31" "32" "33" "34" "35") # List of ANSI color codes

	pos="$1"
	profile="$2"
	is_server="$3"
	log="$LOGS_PATH/${profile}.log"
	server=""
	if [ -n "$is_server" ]; then
		server="--server "
	fi
	truncate -s 0 $log && touch $log
	_terminal_color_index=$(((_terminal_color_index + 1) % ${#colors[@]}))
	color="${colors[_terminal_color_index]}"

	${GODOT_4_PATH} --path "${PROJECT_PATH}" -- --local --window_position=${pos} ${server} --profile=${profile} 2>&1 | while IFS= read -r line; do
		echo -e "\e[${color}m${profile}: ${line}\e[0m"
		echo "${profile}: ${line}" >>"$log"
	done &
	pids+=("$!")
}

: <<DOCUMENTATION_run
Runs multiple instances of the game with a mock W4 class.
Each instance has a different color in the terminal, to distinguish them, and each logs to a different file.
It connects all players to the lobby; press F1 in the server window
You can optionally pass how many instances you want
DOCUMENTATION_run
run() {
	if [ "$1" == "help" ]; then
		_show_docs "${FUNCNAME[0]}" " [number]"
	fi

	_run_godot "0x0" "server"

	sleep 0.1
	instances="${1:-2}"

	for i in $(seq $instances); do
		y=$(((100 + 200 * i) % 1920))
		x=$(((100 + 300 * i) % 1080))
		_run_godot "${x}x${y}" "client_${i}"
	done

	retval=0
	trap _graceful_shutdown EXIT
	for pid in "${pids[@]}"; do
		wait "$pid" || ((retval |= $?))
	done
	exit "$retval"
}

######################################## BUILDING

_build() {

	_find_godot

	name="$1"
	export="$2"
	release="${3:-debug}"

	if [ "$release" != "release" ]; then
		release="debug"
	fi

	NOW=$(date '+%S-%M-%H-%d-%m-%Y')
	OUT_DIR="${OUT_DIR:-${PWD}/out/${name}}"
	ZIP_PATH="${ZIP_PATH:-${OUT_DIR}-${NOW}-${release}.zip}"

	echo "Building $name with export $export in $release mode"

	mkdir -p "${OUT_DIR}"

	path="${OUT_DIR}/${APP_NAME}-${release}.x86_64"

	${GODOT_4_PATH} --headless --path "${PROJECT_PATH}" --export-${release} "${export}" "${path}" && cd ${OUT_DIR} && zip -r ${ZIP_PATH} ./

	echo "Wrote the package in ${ZIP_PATH}"
	rm -rf ${OUT_DIR}
}

: <<DOCUMENTATION_build_server
Builds the server. For a release build, specify 'release' (otherwise, 'debug' is assumed)
DOCUMENTATION_build_server
build_server() {
	if [ "$1" == "help" ]; then
		_show_docs "${FUNCNAME[0]}" " [release]"
	fi
	_build "server" "Linux/X11 Server" $@
}

: <<DOCUMENTATION_build_client
Builds the client. For a release build, specify 'release' (otherwise, 'debug' is assumed)
DOCUMENTATION_build_client
build_client() {
	if [ "$1" == "help" ]; then
		_show_docs "${FUNCNAME[0]}" " [release]"
	fi
	_build "client" "Linux/X11 Client" $@
}

: <<DOCUMENTATION_build_android
Builds the Android client. For a release build, specify 'release' (otherwise, 'debug' is assumed)
DOCUMENTATION_build_android
build_android() {
	if [ "$1" == "help" ]; then
		_show_docs "${FUNCNAME[0]}" " [release]"
	fi
	_build "android" "Android" $@
}

: <<DOCUMENTATION_build
Builds a client or server. For a release build, specify 'release'
For example: 'build:client release'
DOCUMENTATION_build
build() {
	_show_docs "${FUNCNAME[0]}" ":<target> [release]" 1
	echo "available targets are:"
	_show_available_targets
	if [ "$1" == "help" ]; then
		exit $DOC_REQUEST
	fi
	echo ""
	echo "Error: you need to specify a target"
	exit 1
}

######################################## TUTORIAL BUILDING

# Removes all lines with the following pattern:
# ```gdscript
#  # some token/
#  anything
#  # /some token
# ```
# And also uncomments any line with three hashes followed by a space
#
# Usage
# ```bash
#  contents=$(cat your_file.txt)
#  result=$(_strip_comment_boundaries "$contents")
#  echo -e "$result"
# ```
_strip_comment_boundaries() {
	local contents="$1"
	local inCommentBlock=0
	local open_block="^[[:blank:]]*# (.+) */ *$"
	local close_block=""
	local block_name=""
	local indent=""
	local super_commented_line=""
	local super_comment="^([[:blank:]]*)### (.*)$"
	while IFS= read -r line; do
		if ((inCommentBlock)); then
			if [[ "$line" =~ $close_block ]]; then
				inCommentBlock=0
			else
				# Skip all lines between comment blocks
				continue
			fi
		elif [[ "$line" =~ $open_block ]]; then
			block_name="${BASH_REMATCH[1]}"
			close_block="^[[:blank:]]*# / *${block_name} *\$"
			inCommentBlock=1
		elif [[ "$line" =~ $super_comment ]]; then
			local indent="${BASH_REMATCH[1]}"
			local super_commented_line="${BASH_REMATCH[2]}"
			echo "${indent}${super_commented_line}"
		else
			echo "$line"
		fi
	done <<<"$contents"
}

# Strips out an entire section from an ini-like file
_remove_ini_section() {
	_verify_awk
	local contents="$1"
	local section="\\\[$2\\\]"

	echo "$contents" | awk -v section="$section" '{
		if($0 ~ section){output="off"; next}
		if($0 ~ /\[/){output="on"; print; next}
		if(output == "on"){print}
	}'
}

# Changes one value from a given key.
#
# if you use 'gawk', Pattern replacements are available in the form of '\\2' or '\\1'
# You can verify the version by running '_verify_awk', and then querying the
# $AWK_MODE variable, which will be set to "gawk" or "mawk"
_modify_ini_value() {
	_verify_awk
	local contents="$1"
	local section="^\\\[$2"
	local key="\\\^$3="
	local pattern="$4"
	local replacement="$5"
	local gawk=0
	[ "${AWK_MODE}" == "gawk" ] && gawk=1

	awk_str=$(
		cat <<'END_HEREDOC'
		# Clear the flag
		BEGIN {
			processing = 0;
		}

		# Entering the section, set the flag
		section {
			processing = 1;
		}

		# Modify the line, if the flag is set
		key {
		if (processing) {
				gsub(pattern, replacement, $0)
				print
				skip = 1;
			}
		}

		# Clear the section flag (as we're in a new section)
		/^\[$/ {
			processing = 0;
		}

		# Output a line (that we didn't output above)
		/.*/ {
			if (skip){
					skip = 0;
			}else{
				print $0;
			}
		}
END_HEREDOC
	)
	echo "$contents" | awk -v section="$section" -v key="$key" -v pattern="$pattern" -v replacement="$replacement" -v gawk="$gawk" "$awk_str"
}

_change_project_contents_remove_additional_plugins() {
	contents="$1"
	section="editor_plugins"
	key="enabled"
	pattern="(, *)?\"res://addons/w4gd_multiple_instances/plugin.cfg\""
	replacement=""
	contents=$(_modify_ini_value "$contents" "$section" "$key" "$pattern" "$replacement")
	echo -e "$contents"
}

# Replace config/name with the new title
_change_project_contents_change_title() {
	local contents="$1"
	local title="$2"
	echo -e "$contents" | sed -E "s@^config/name=.*@config/name=\"$title\"@"
}

# Remove lines matching W4GD= to remove that autoload
_change_project_contents_remove_w4gd_autoload() {
	local contents="$1"
	echo -e "$contents" | sed -E '/^W4GD=/d'
}

# Remove lines matching ServerReporter= to remove that autoload
_change_project_contents_remove_w4gd_autoload() {
	local contents="$1"
	echo -e "$contents" | sed -E '/^ServerReporter=/d'
}

# Remove everything between [editor_plugins] and the next [
_change_project_contents_remove_editor_plugins() {
	local contents="$1"
	contents=$(_remove_ini_section "${contents}" "editor_plugins")
	echo -e "${contents}"
}

# Remove w4games config; everything between [w4games] and the end of the file
_change_project_contents_remove_w4_settings() {
	local contents="$1"
	contents=$(_remove_ini_section "${contents}" "w4games")
	echo -e "${contents}"
}

# Copies files that are always part of each tutorial step
_copy_common_files() {
	local src="$1"
	local dest="$2"

	if [ -z "${dest}" ]; then
		_show_docs "generate" ":<target> <output-dir>" 1
		echo "Error: destination must be specified"
		exit 1
	fi

	mkdir -p "${dest}"

	local locations=(
		"assets"
		"level"
		"lobby"
		"player"
		"server"
	)

	for location in "${locations[@]}"; do
		cp -r "${src}/${location}" "${dest}/${location}"
	done

}

_copy_and_process_file() {
	local src="$1"
	local dest="$2"
	local path="$3"
	local suffix="$4"

	if [ -z "$src" ]; then
		echo "no source provided"
		exit 1
	fi
	if [ -z "$dest" ]; then
		echo "no destination provided"
		exit 1
	fi
	if [ -z "$path" ]; then
		echo "no path provided"
		exit 1
	fi

	contents=$(cat "${src}/${path}")
	contents=$(_strip_comment_boundaries "$contents")

	dest_dir=$(dirname "${dest}/${path}")

	if mkdir -p "${dest_dir}"; then
		dest_ext=$(_get_extension "${path}")
		original_suffix=$(_get_suffix "${path}")
		dest_basename=$(basename "${path}" "${original_suffix}${dest_ext}")
		dest="${dest_dir}/$dest_basename${suffix}${dest_ext}"
		echo -e "${contents}" >"${dest}"
	else
		echo "could not process $path"
		exit 1
	fi

}

: <<DOCUMENTATION_generate_initial
Builds the initial step of the tutorial.
The source files location can be specified with an environment variable
PROJECT_PATH, while the output can be specified as an argument
DOCUMENTATION_generate_initial
generate_initial() {
	if [ "$1" == "help" ]; then
		_show_docs "${FUNCNAME[0]}" "<output-dir>"
	fi
	local src="${PROJECT_PATH}"
	local dest="$1"
	_copy_common_files ${src} $dest
	local contents=$(cat "${src}/project.godot")
	contents=$(_change_project_contents_change_title "${contents}" "${APP_NAME} Start")
	contents=$(_change_project_contents_remove_w4gd_autoload "${contents}")
	contents=$(_change_project_contents_remove_w4_settings "${contents}")
	contents=$(_change_project_contents_remove_editor_plugins "${contents}")
	echo -e "${contents}" >"${dest}/project.godot"

	_copy_and_process_file "${src}" "${dest}" "boot.gd" ""
	_copy_and_process_file "${src}" "${dest}" "boot.tscn" ""

	_copy_and_process_file "${src}" "${dest}" "data/profile_data.gd" ""
	_copy_and_process_file "${src}" "${dest}" "data/database_manager-tutorial.gd" ""
	_copy_and_process_file "${src}" "${dest}" "autoloads/game_state.gd" "-final"
	_copy_and_process_file "${src}" "${dest}" "autoloads/game_state-tutorial.gd" ""

	# remove type information
	sed -Ei '/^const W4/s/.*//; s/(:|as) W4[A-Z][a-zA-Z]*//g; s/\[W4[A-Z][a-z]*\]//g' "${dest}/autoloads/game_state-final.gd"
}

: <<DOCUMENTATION_generate_final
Builds the final step of the tutorial.
The source files location can be specified with an environment variable
PROJECT_PATH, while the output can be specified as an argument
DOCUMENTATION_generate_final
generate_final() {
	if [ "$1" == "help" ]; then
		_show_docs "${FUNCNAME[0]}" "<output-dir>"
	fi
	local src="${PROJECT_PATH}"
	local dest="$1"
	_copy_common_files "${src}" "${dest}"
	local contents=$(cat "${src}/project.godot")
	contents=$(_change_project_contents_change_title "${contents}" "${APP_NAME} Final")
	contents=$(_change_project_contents_remove_w4gd_autoload "${contents}")
	contents=$(_change_project_contents_remove_w4_settings "${contents}")
	contents=$(_change_project_contents_remove_additional_plugins "${contents}")
	echo -e "${contents}" >"${dest}/project.godot"

	_copy_and_process_file "${src}" "${dest}" "boot.gd" ""
	_copy_and_process_file "${src}" "${dest}" "boot.tscn" ""

	_copy_and_process_file "${src}" "${dest}" "data/profile_data.gd" ""
	_copy_and_process_file "${src}" "${dest}" "data/database_manager.gd" ""
	_copy_and_process_file "${src}" "${dest}" "autoloads/game_state.gd" ""
}

: <<DOCUMENTATION_generate_all
Generates all tutorial steps.
Automatically chooses step names.
Automatically cleans the directory.

Make sure to commit before running this!
DOCUMENTATION_generate_all
generate_all() {
	if [ "$1" == "help" ]; then
		_show_docs "${FUNCNAME[0]}" "<output-dir>"
	fi
	generate_clean
	generate_final "hexagon-series-result"
	generate_initial "hexagon-series-start"
}

: <<DOCUMENTATION_generate_clean
Removes generated steps
DOCUMENTATION_generate_clean
generate_clean() {
	if [ "$1" == "help" ]; then
		_show_docs "${FUNCNAME[0]}"
	fi
	project=$(basename "$PROJECT_PATH")
	for dir in */; do
		dir=${dir::-1}
		if [[ "$dir" =~ ^[0-9]{3}-[a-z]+ ]] && [[ ! "$dir" == "${project}" ]]; then
			rm -rf "${dir}"
		fi
	done
}

: <<DOCUMENTATION_generate
Generates tutorial steps. Currently, there's only an initial and a final step.
The source files location can be specified with an environment variable
PROJECT_PATH, while the output can be specified as an argument
DOCUMENTATION_generate
generate() {
	_show_docs "${FUNCNAME[0]}" ":<target> <output-dir>" 1
	echo "available targets are:"
	_show_available_targets
	if [ "$1" == "help" ]; then
		exit $DOC_REQUEST
	fi
	echo ""
	echo "Error: you need to specify a target"
	exit 1
}

######################################## BOOTSTRAP

_bootstrap() {
	_verify_awk
	funcs=($(declare -F | awk '{print $NF}' | sort | grep -E -v "^_"))
	command=${1//:/_}

	if [[ " ${funcs[*]} " =~ " ${command} " ]]; then
		shift
		$command $@
		exit 0
	else
		if [[ $command ]]; then
			echo ""
			echo "\`${command}\` isn't a recognized command"
			echo ""
		fi
		help
		exit 1
	fi
}

_bootstrap $@
