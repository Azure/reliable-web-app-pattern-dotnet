# Use the official Microsoft .NET SDK image as the base image
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build-env
WORKDIR /app

# Copy the .csproj and restore any dependencies (via dotnet restore)
COPY ./Relecloud.Web.csproj ./
RUN dotnet restore ./Relecloud.Web.csproj

# Copy the rest of the files and build the application
COPY . ./
RUN dotnet publish ./Relecloud.Web.csproj -c Release -o out

# Build the runtime image
FROM mcr.microsoft.com/dotnet/aspnet:6.0
WORKDIR /app
COPY --from=build-env /app/out .

# Set the command to run on startup
ENTRYPOINT ["dotnet", "Relecloud.Web.dll"]
