# Version Updater

A fast Fortran utility for automatically updating version numbers across multiple file types in your project.

## Overview

Version Updater recursively scans your project directory and updates version strings in configuration files and source code. This tool is particularly useful for maintaining consistent version information across a project with multiple components.

## Features

- Updates version numbers in multiple file types:
  - `tauri.conf.json`
  - `Cargo.toml`
  - `Cargo.lock` (balatro-mod-manager package)
  - `package.json`
  - Svelte files containing version elements
- Intelligent version handling (removes `v` prefix for certain files)
- Preserves file formatting and structure
- Excludes common directories like `.git`, `node_modules`, etc.
- Fast performance with optional OpenMP multithreading

## Requirements

- Fortran compiler (gfortran recommended)
- Fortran Package Manager (fpm)
- OpenMP support (optional, for improved performance)

## Building

## Build with fpm

`fpm build --flag "-fopenmp" --profile release`

Note: If your compiler doesn't support OpenMP, you can build without it:
`fpm build --profile release`

## Usage

### Basic Usage

Update version numbers in a given project directory:

`fpm run -- v2.0.3 /path/to/project`
