FROM mcr.microsoft.com/dotnet/sdk:10.0

WORKDIR /app
COPY *.cs .
COPY appsettings.json .
COPY *.csproj .
RUN --mount=type=cache,target=/root/.nuget/packages dotnet publish -c Release -o out

ENV ASPNETCORE_HTTP_PORTS=5000

# RUN apt update
# RUN apt install unzip
# # Download the bash script
# RUN curl -sSfL https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation/releases/download/v1.13.0/otel-dotnet-auto-install.sh -O

# # Install core files
# RUN sh ./otel-dotnet-auto-install.sh

# # Enable execution for the instrumentation script
# RUN chmod +x $HOME/.otel-dotnet-auto/instrument.sh

# # Setup the instrumentation for the current shell session
# RUN . $HOME/.otel-dotnet-auto/instrument.sh

ENTRYPOINT [ "./out/Notifier", "--urls", "http://*:5000" ]