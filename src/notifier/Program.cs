using Npgsql;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddLogging();

var app = builder.Build();

NpgsqlDataSource SetupPostgresql() {
    string postgresql_host = Environment.GetEnvironmentVariable("POSTGRESQL_HOST");
    string postgresql_port = Environment.GetEnvironmentVariable("POSTGRESQL_PORT");
    string postgresql_dbname = Environment.GetEnvironmentVariable("POSTGRESQL_DBNAME");
    string postgresql_user = Environment.GetEnvironmentVariable("POSTGRESQL_USER");
    string postgresql_password = Environment.GetEnvironmentVariable("POSTGRESQL_PASSWORD");

    var connString = "Host=" + postgresql_host + ":" + postgresql_port + ";";
    connString += "Username=" + postgresql_user + ";Password=" + postgresql_password + ";";
    connString += "Database=" + postgresql_dbname;

    app.Logger.LogInformation("connString=" + connString);

    var dataSource = NpgsqlDataSource.Create(connString);
    return dataSource;
}
NpgsqlDataSource ds = SetupPostgresql();

string HealthHandler(ILogger<Program> logger)
{
    return "KERNEL OK";
}

void QueryPostgresql(string trade_id, ILogger<Program> logger)
{
    using (var conn = ds.OpenConnection())
    {
        var sqlQuery = "SELECT * FROM trades WHERE trade_id = '" + trade_id + "';";

        // 4. Create a command object
        var cmd = new NpgsqlCommand(sqlQuery, conn);
        {
            // 5. Execute the command and get a data reader
            var reader = cmd.ExecuteReader();
            {
                // 6. Read the data row by row
                while (reader.Read())
                {
                    logger.LogInformation(reader["trade_id"].ToString());
                }
            }
        }
    }
}

string NotifyHandler([FromQuery] string? database, [FromQuery] string? trade_id, ILogger<Program> logger)
{
    if (!string.IsNullOrEmpty(database) && database == "postgresql") {
        QueryPostgresql(trade_id, logger);
        logger.LogInformation("notified+ " + database + trade_id);
    }

    logger.LogInformation("notified");

    return "Notified";
}

app.MapGet("/health", HealthHandler);
app.MapPost("/notify", NotifyHandler);
await app.RunAsync();
