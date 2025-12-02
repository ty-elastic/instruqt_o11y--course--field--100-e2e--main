// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddLogging();

var app = builder.Build();

string HealthHandler(ILogger<Program> logger)
{
    return "KERNEL OK";
}

string NotifyHandler(ILogger<Program> logger)
{
    logger.LogInformation("notified");

    return "Notified";
}

app.MapGet("/health", HealthHandler);
app.MapPost("/notify", NotifyHandler);
await app.RunAsync();