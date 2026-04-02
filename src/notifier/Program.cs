using Npgsql;
using Microsoft.AspNetCore.Mvc;

string ConnectionString() {
    string postgresql_host = Environment.GetEnvironmentVariable("POSTGRESQL_HOST");
    string postgresql_port = Environment.GetEnvironmentVariable("POSTGRESQL_PORT");
    string postgresql_dbname = Environment.GetEnvironmentVariable("POSTGRESQL_DBNAME");
    string postgresql_user = Environment.GetEnvironmentVariable("POSTGRESQL_USER");
    string postgresql_password = Environment.GetEnvironmentVariable("POSTGRESQL_PASSWORD");

    var connString = "Host=" + postgresql_host + ":" + postgresql_port + ";";
    connString += "Username=" + postgresql_user + ";Password=" + postgresql_password + ";";
    connString += "Database=" + postgresql_dbname + ";";
    connString += "Maximum Pool Size=25;Timeout=1;Pooling=True;";

    app.Logger.LogInformation("connString=" + connString);

    return connString;
}

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddLogging();
builder.Services.AddNpgsqlDataSource(ConnectionString());

var app = builder.Build();

string HealthHandler(ILogger<Program> logger)
{
    return "KERNEL OK";
}

void QueryPostgresql(string trade_id, NpgsqlDataSource ds, ILogger<Program> logger)
{
    var sqlQuery = "SELECT * FROM trades WHERE trade_id = '" + trade_id + "';";

    using (var cmd = ds.CreateCommand(sqlQuery))
    {
        using (var reader = cmd.ExecuteReader())
        {
            while (reader.Read())
            {
                logger.LogInformation("found " + reader["trade_id"].ToString());
            }
        }
    }
}

string NotifyHandler([FromQuery] string? database, [FromQuery] string? trade_id, NpgsqlDataSource ds, ILogger<Program> logger)
{
    if (!string.IsNullOrEmpty(database) && database == "postgresql") {
        try {
            QueryPostgresql(trade_id, ds, logger);
        }
        catch (Exception e) {
            logger.LogWarning("no conn avail");
        }
        //logger.LogInformation("notified+ " + database + trade_id);
    }

    logger.LogInformation("notified");

    return "Notified";
}

app.MapGet("/health", HealthHandler);
app.MapPost("/notify", NotifyHandler);
await app.RunAsync();
