package main

import (
	"context"
	"fmt"
	"net"
	"os"

	log "github.com/sirupsen/logrus"

	"database/sql"

	_ "github.com/lib/pq"
)

type TradeService struct {
	db *sql.DB
}

const tradesSqlTable = `
	CREATE TABLE trades(
		trade_id VARCHAR(100) PRIMARY KEY,
		customer_id VARCHAR(100) NOT NULL,
		timestamp timestamp default current_timestamp,
		symbol VARCHAR(10) NOT NULL,
		shares int NOT NULL,
		share_price float NOT NULL,
		action VARCHAR(10) NOT NULL,
		constraint shares_nonnegative check (shares >= 0),
		constraint share_price_nonnegative check (share_price >= 0)
	)
`

func NewTradeService() (*TradeService, error) {
	c := TradeService{}

	psqlInfo := fmt.Sprintf("host=%s port=%d user=%s "+
		"password=%s dbname=%s sslmode=%s",
		os.Getenv("POSTGRESQL_HOST"), 5432, os.Getenv("POSTGRESQL_USER"), os.Getenv("POSTGRESQL_PASSWORD"), os.Getenv("POSTGRESQL_DBNAME"), os.Getenv("POSTGRESQL_SSLMODE"))
	db, err := sql.Open("postgres", psqlInfo)
	if err != nil {
		log.Fatal("unable to connect to database: ", err)
		os.Exit(1)
	}
	c.db = db

	err = c.db.Ping()
	if err != nil {
		log.Fatal("unable to connect to database: ", err)
		os.Exit(1)
	}

	// try to create initial table
	_, err = c.db.Exec(tradesSqlTable)
	if err != nil {
		// if unable to connect, die and retry
		if _, ok := err.(net.Error); ok {
			log.Fatal("unable to connect to database: ", err)
			os.Exit(1)
		} else {
			log.Warn("unable to create table: ", err)
		}
	}

	return &c, nil
}

func (c *TradeService) RecordTrade(context context.Context, trade *Trade) (*Trade, error) {

	sqlStatement := `
		INSERT INTO trades (trade_id, customer_id, symbol, action, shares, share_price)
		VALUES ($1, $2, $3, $4, $5, $6)
	`

	// insert trade
	_, err := c.db.ExecContext(context, sqlStatement, trade.TradeId, trade.CustomerId, trade.Symbol, trade.Action, trade.Shares, trade.SharePrice)
	if err != nil {
		return nil, err
	}

	logger.WithContext(context).Info("trade committed for " + trade.CustomerId)

	return trade, nil
}
