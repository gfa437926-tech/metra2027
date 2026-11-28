# Build from the repository root:
# docker build -f backend/Metra.Api/Dockerfile -t metra-api:local .
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY backend/Metra.Api/Metra.Api.csproj backend/Metra.Api/
RUN dotnet restore backend/Metra.Api/Metra.Api.csproj

COPY backend/Metra.Api/ backend/Metra.Api/
WORKDIR /src/backend/Metra.Api
RUN dotnet publish Metra.Api.csproj --configuration Release --output /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

COPY --from=build /app/publish .
USER $APP_UID
ENTRYPOINT ["dotnet", "Metra.Api.dll"]
