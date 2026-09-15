# Contributing Guidelines

Thank you for considering contributing to this project! This document outlines the process for contributing.

## Getting Started

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Run tests/linters if applicable
5. Submit a pull request

## Development Setup

### Prerequisites

- Docker Desktop with WSL2 backend
- Windows 10/11 with WSL2 (Ubuntu recommended)
- Git

### Running Locally

```bash
# Clone your fork
git clone https://github.com/your-username/defectdojo-poc.git
cd defectdojo-poc

# Run full setup
bash scripts/setup-all.sh
```

## Code Style

- Shell scripts: Use `shellcheck` for validation
- Python: Follow PEP 8, use `black` for formatting
- TypeScript/Angular: Follow Angular style guide
- Dockerfiles: Follow Docker best practices

## Commit Messages

Follow conventional commits:

```
type(scope): description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Example:
```
feat(scanner): add support for Grype container scanner

- Add Grype to run-scanners.sh
- Update import-all.py with Grype SARIF support

Closes #123
```

## Pull Request Process

1. Ensure your branch is up to date with `main`
2. Run all scanners locally to verify findings
3. Update documentation if needed
4. Submit PR with clear description
5. Address review comments
5. Squash commits before merge

## Reporting Issues

- Use GitHub Issues for bugs and feature requests
- Include steps to reproduce
- Include environment details (OS, Docker version, WSL version)

## Security

See [SECURITY.md](SECURITY.md) for responsible disclosure policy.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.