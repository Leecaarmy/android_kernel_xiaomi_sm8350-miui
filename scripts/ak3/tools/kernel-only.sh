#!/bin/sh
# SPDX-License-Identifier: GPL-2.0
# Dynamic: the only admission check is the supported device family.
is_supported_device() {
    case "$1" in mars|star|M2102K1AC|M2102K1G) return 0;; *) return 1;; esac
}
