package core

import (
	"fmt"
	"os"
	"os/exec"
)

// CheckDependencies verifies that required system tools are available.
func CheckDependencies() {
	if _, err := exec.LookPath("ffprobe"); err != nil {
		fmt.Fprintln(os.Stderr, "错误：未找到 ffprobe，请先安装 ffmpeg。")
		os.Exit(1)
	}
}
