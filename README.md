# CPU Monitor

A lightweight, real-time CPU monitor for the terminal. Pure Bash, no dependencies.

![CPU Monitor](cpu_moniter.png)

## What it does

- Shows per-core CPU usage with color-coded bars (green < 50%, yellow < 80%, red above)
- Displays system info: hostname, OS, kernel, uptime, CPU model, memory, load averages
- Detects your distro (Ubuntu, Debian, Arch, Fedora) and shows matching ASCII art
- Supports both Unicode and ASCII rendering
- Adapts to terminal width on resize

## Requirements

- Linux or WSL (reads from `/proc/stat` and `/proc/cpuinfo`)
- Bash 4+

## Install

```bash
git clone https://github.com/<your-username>/cpu-monitor.git
cd cpu-monitor
chmod +x cpu.sh
./cpu.sh
```

## Controls

- `q` — quit
- `r` — cycle refresh rate (1s → 2s → 5s → 0.5s)

## Environment variables

- `CPUMON_ASCII=1` — force ASCII mode, useful for terminals that don't support Unicode
- `CPUMON_UNICODE=1` — force Unicode mode

## How it works

The script reads `/proc/stat` at a set interval, calculates the delta in CPU ticks between samples, and renders colored bars using ANSI escape codes. It runs in the alternate screen buffer so your terminal stays clean after exit.

