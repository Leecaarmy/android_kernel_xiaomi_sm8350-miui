#!/bin/sh
# SPDX-License-Identifier: GPL-2.0

set -eu

if [ "$#" -ne 2 ]; then
	echo "用法: $0 <.config 路径> <版本号>" >&2
	echo "示例: $0 out/.config v1.0.1" >&2
	exit 2
fi

config_file=$1
release_version=$2
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_tree=$(CDPATH= cd -- "$script_dir/.." && pwd)

if [ ! -f "$config_file" ]; then
	echo "配置文件不存在: $config_file" >&2
	exit 2
fi

case "$release_version" in
	*[!A-Za-z0-9._-]*|'')
		echo "版本号只能包含字母、数字、点、下划线和连字符" >&2
		exit 2
		;;
esac

commit_id=$(git -C "$source_tree" rev-parse HEAD | cut -c1-7)
local_version="-Dynamic-g${commit_id}-${release_version}"

bash "$source_tree/scripts/config" --file "$config_file" \
	--set-str LOCALVERSION "$local_version" \
	--disable LOCALVERSION_AUTO

echo "CONFIG_LOCALVERSION=$local_version"
echo "预期内核名称: <内核版本>${local_version}"
