# Spring Boot Initializer Script (spring-init)
https://img.shields.io/badge/Shell_Script-%2523121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white
https://img.shields.io/badge/Spring_Boot-6DB33F?style=for-the-badge&logo=spring&logoColor=white

## Description 📖
A command-line utility that simplifies Spring Boot project setup by interacting with Spring Initializr's API. This script guides you through project configuration and dependency selection, then generates and sets up your project.

## Features ✨
- Interactive configuration wizard for all project parameters
- Project review system to modify settings before generation
- Smart defaults from Spring Initializr metadata
- Validation for all user inputs
- Single-command download and project setup

## Requirements 📋

- curl (for API requests)
- jq (for JSON processing)
- unzip (for project extraction)
- fzf (for dependency selection, optional but recommended)

## Installation 💻

### Download the script
```bash
curl -O https://raw.githubusercontent.com/leandrofmoraes/spring-init/main/spring-init.sh
```

### Make it executable
```bash
chmod +x spring-init.sh
```

## Usage 🚀
```bash
./spring-init.sh
```
And follow the interactive prompts to configure.


## License 📄
This project is licensed under the MIT License - see the LICENSE file for details.

