package main

import (
	"context"
	"fmt"
	"os"
	"strconv"

	log "github.com/sirupsen/logrus"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/trace"

	"database/sql"

	_ "github.com/microsoft/go-mssqldb"

	"github.com/XSAM/otelsql"
	semconv "go.opentelemetry.io/otel/semconv/v1.37.0"
)

type TradeService struct {
	db                 *sql.DB
	transactionCounter metric.Int64Counter
}

func NewTradeService() (*TradeService, error) {
	c := TradeService{}

	// [scheme://][user[:password]@][protocol([addr])]/dbname[?param1=value1&paramN=valueN]
	// spring.datasource.url=jdbc:${DB_PROTOCOL}://${POSTGRESQL_HOST}:${DB_PORT}${DB_OPTIONS}

	//connString := fmt.Sprintf("%s://%s:%s@%s:%s/trades?Trusted_Connection=false&Encrypt=false&TrustServerCertificate=true", os.Getenv("MSSQL_PROTOCOL"), os.Getenv("MSSQL_USER"), os.Getenv("MSSQL_PASSWORD"), os.Getenv("MSSQL_HOST"), os.Getenv("MSSQL_PORT"))
	connString := fmt.Sprintf("server=%s;user id=%s;password=%s;port=%s%s", os.Getenv("MSSQL_HOST"), os.Getenv("MSSQL_USER"), os.Getenv("MSSQL_PASSWORD"), os.Getenv("MSSQL_PORT"), os.Getenv("MSSQL_OPTIONS"))
	logger.Warn(connString)

	port, err := strconv.ParseInt(os.Getenv("MSSQL_PORT"), 10, 64)

	db, err := otelsql.Open("mssql", connString, otelsql.WithAttributes(
		semconv.DBSystemNameMicrosoftSQLServer,
		semconv.ServerAddress(os.Getenv("MSSQL_HOST")),
		semconv.ServerPortKey.Int64(port),
		attribute.String("db.system", "mssql"),
		attribute.String("span.destination.service.resource", os.Getenv("MSSQL_HOST")),
		attribute.String("span.subtype", "mssql"),
		attribute.String("service.target.name", os.Getenv("MSSQL_HOST")),
	))
	if err != nil {
		log.Fatal("unable to connect to database: ", err)
		os.Exit(1)
	}
	c.db = db

	// Register DB stats to meter
	err = otelsql.RegisterDBStatsMetrics(db, otelsql.WithAttributes(
		semconv.DBSystemNameMicrosoftSQLServer,
		semconv.ServerAddress(os.Getenv("MSSQL_HOST")),
		semconv.ServerPortKey.Int64(port),
	))
	if err != nil {
		log.Fatal("unable to setup dbstats: ", err)
		os.Exit(1)
	}

	err = c.db.Ping()
	if err != nil {
		log.Fatal("unable to connect to database: ", err)
		os.Exit(1)
	}

	meter := otel.Meter("tradeService")
	transactionCounter, err := meter.Int64Counter(
		"sql_transaction.counter",
		metric.WithDescription("Number of SQL transactions"),
		metric.WithUnit("{transaction}"),
	)
	c.transactionCounter = transactionCounter

	return &c, nil
}

func (c *TradeService) RecordTrade(context context.Context, trade *Trade) (*Trade, error) {
	sqlStatement := `
		INSERT INTO trades (trade_id, customer_id, symbol, action, shares, share_price)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	// insert trade
	res, err := c.db.ExecContext(context, sqlStatement, trade.TradeId, trade.CustomerId, trade.Symbol, trade.Action, trade.Shares, trade.SharePrice)
	if err != nil {
		logger.Warn(err)
		span := trace.SpanFromContext(context)
		span.RecordError(err, trace.WithStackTrace(true))
		return nil, err
	}
	c.transactionCounter.Add(context, 1)

	insertId, _ := res.LastInsertId()
	trace.SpanFromContext(context).SetAttributes(attribute.Int64("sql_insert_id", insertId))

	logger.WithContext(context).Info("trade committed for " + trade.CustomerId)

	return trade, nil
}
