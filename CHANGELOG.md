# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.6.0] - 2023-08-24

### Added

- Get-ParameterValue. Get parameter values from PSBoundParameters + DefaultValues and optionally, a configuration file.

### Fixed

- Only call Add-MetadataConverter at load if converters are supplied at load time.

## [1.5.1] - 2022-06-06

### Fixed

- Stop re-importing the metadata module at import

## [1.5.0] - 2021-07-03

### Removed

This is the first release without the Metadata module included. This module is now available as a separate module on the PowerShell Gallery.

### Added

Test runs on GitHub Actions now include Linux and Mac OS.

AllowedVariables now flow through the whole module (and into calls to the Metadata module).