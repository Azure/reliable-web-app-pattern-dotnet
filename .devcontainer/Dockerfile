ARG VARIANT
FROM mcr.microsoft.com/vscode/devcontainers/dotnet:${VARIANT}

# Install Az module
RUN pwsh -Command "Install-Module -Name Az -Force -AllowClobber -Scope AllUsers"
RUN pwsh -Command "Install-Module -Name SqlServer -Force -AllowClobber -Scope AllUsers"