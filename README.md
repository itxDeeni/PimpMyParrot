# PimpMyParrot

A comprehensive tool installer and system optimizer for **Parrot OS 7**, inspired by [PimpMyKali](https://github.com/Dewalt-arch/pimpmykali).

![Parrot OS](https://img.shields.io/badge/Parrot%20OS-7-green)
![License](https://img.shields.io/badge/License-MIT-blue)
![Bash](https://img.shields.io/badge/Bash-5.0+-orange)
![Version](https://img.shields.io/badge/Version-1.1.0-purple)

## Features

- **System Fixes** - Repository repair, broken package fixes, optimizations
- **Tool Installation** - 50+ pentesting tools organized by category
- **Interactive Menu** - Easy navigation with category selection
- **CLI Mode** - Non-interactive installation with `--all`, `--category`, `--dry-run`
- **Uninstall Support** - Remove tools cleanly
- **Logging** - Detailed logs for troubleshooting
- **Smart Fallbacks** - GitHub/pipx alternatives when apt fails

## Installation

```bash
git clone https://github.com/itxDeeni/PimpMyParrot.git
cd PimpMyParrot
chmod +x pimpmyparrot.sh
./pimpmyparrot.sh
```

## Usage

### Interactive Mode

```bash
./pimpmyparrot.sh
```

### CLI Mode

```bash
# Show help
./pimpmyparrot.sh --help

# Install all tools (non-interactive)
./pimpmyparrot.sh --all

# Preview what would be installed (dry-run)
./pimpmyparrot.sh --dry-run --all

# Install specific categories only
./pimpmyparrot.sh --category recon,scanning,smb

# Install all except certain categories
./pimpmyparrot.sh --skip wifi,postexploit

# Run system fixes only
./pimpmyparrot.sh --fix

# List available categories
./pimpmyparrot.sh --list
```

### CLI Options

| Option | Short | Description |
|--------|-------|-------------|
| `--help` | `-h` | Show help message |
| `--dry-run` | `-n` | Preview mode (no changes made) |
| `--all` | `-a` | Install all tools non-interactively |
| `--category CATS` | `-c` | Install only specified categories (comma-separated) |
| `--skip CATS` | `-s` | Skip specified categories (comma-separated) |
| `--fix` | `-f` | Run system fixes only |
| `--list` | `-l` | List all available categories |

### Interactive Menu

```
1) System Fixes & Maintenance
2) Install Tools (by category)
3) View Installed Tools
4) View Logs
5) Uninstall Tools
0) Exit
```

## Tool Categories

| Category | Tools Included |
|----------|----------------|
| **recon** | whois, subfinder, amass, httpx, theHarvester, FinalRecon, SecLists |
| **scanning** | nmap, nikto, nuclei, wapiti, sslscan, wafw00f, bbot |
| **cms** | wpscan, joomscan, CMSeeK, vulnx |
| **fuzzing** | ffuf, feroxbuster, gobuster, hydra, dirsearch, wfuzz |
| **vulnscan** | sqlmap, XSStrike, dalfox, DSSS |
| **osint** | Profil3r, trufflehog, pywhat |
| **smb** | netexec, smbmap, impacket |
| **wifi** | aircrack-ng, bettercap, WEF |
| **postexploit** | PEASS-ng, LaZagne, linux-smart-enumeration |

## System Fixes

- **Fix Repositories** - Restores official Parrot OS 7 repos
- **Fix Broken Packages** - Repairs dpkg/apt issues
- **Update System** - Full system upgrade
- **Optimize** - Parallel downloads, faster dpkg (optional)

## Requirements
sasssssssasssssssssssssssssssssssaassssssssssssssdaaasssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssafdssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssewqrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrraAYTYA- Parrot OS 7 (works on other Debian-based distros with warnings)
- Bash 5.0+
- sudo privileges
- Internet connection

## Environment Variables

| Variable | Description |
|----------|-------------|
| `GITHUB_TOKEN` | Set to avoid GitHub API rate limits when downloading releases |

## Configuration

Logs and config stored in `~/.pimpmyparrot/`:

```
~/.pimpmyparrot/
├── install_*.log        # Installation logs
└── installed_tools.txt  # Tracked installed tools
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-tool`)
3. Commit changes (`git commit -am 'Add new tool'`)
4. Push to branch (`git push origin feature/new-tool`)
5. Open a Pull Request

### Adding New Tools

Edit the appropriate `install_*_tools()` function in `pimpmyparrot.sh`:

```bash
# For apt packages:
install_apt_package "toolname"

# For Go tools:
install_go_tool "github.com/user/repo@latest" "cmdname"

# For Python tools in /opt:
install_opt_python_tool "https://github.com/user/repo.git" "toolname"

# For pipx:
install_pipx_package "package" "cmdname"
```

## License

MIT License - see [LICENSE](LICENSE)

## Disclaimer

This tool is intended for **authorized security testing and educational purposes only**. Users are responsible for complying with applicable laws. The authors are not responsible for misuse or damage caused by this tool.

## Credits

- Inspired by [PimpMyKali](https://github.com/Dewalt-arch/pimpmykali)
- Built for the [Parrot Security](https://parrotsec.org/) community

## Support

Star this repo if you find it useful!

Issues and PRs welcome.
